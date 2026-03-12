param($InputData)

$ErrorActionPreference = 'Stop'
Ensure-AzConnected

$foundryEndpoint = $env:FoundryEndpoint
$agentId = $env:FoundryAgentId

if (-not $foundryEndpoint) {
    throw 'FoundryEndpoint app setting is required.'
}

if (-not $agentId) {
    throw 'FoundryAgentId app setting is required.'
}

# Remove trailing slash from endpoint if present
$foundryEndpoint = $foundryEndpoint.TrimEnd('/')

if ($InputData.Target.SubscriptionId) {
    try {
        Set-AzContext -SubscriptionId $InputData.Target.SubscriptionId -ErrorAction Stop | Out-Null
    } catch {
        throw "Failed to set Az context to subscription $($InputData.Target.SubscriptionId). $($_.Exception.Message)"
    }
}

$apiVersion = "2024-05-01-preview"

function Get-CogServicesToken {
    try {
        return (Get-AzAccessToken -ResourceUrl 'https://cognitiveservices.azure.com' -ErrorAction Stop).Token
    } catch {
        throw "Failed to acquire Cognitive Services token. $($_.Exception.Message)"
    }
}

function Invoke-AssistantRequest {
    param(
        [string]$Method,
        [string]$Path,
        [object]$Body
    )

    $token = Get-CogServicesToken
    $separator = if ($Path -match '\?') { '&' } else { '?' }
    $uri = "${foundryEndpoint}/openai${Path}${separator}api-version=${apiVersion}"
    $headers = @{
        Authorization  = "Bearer $token"
        'Content-Type' = 'application/json'
    }

    $payload = $null
    if ($null -ne $Body) {
        $payload = $Body | ConvertTo-Json -Depth 10
    }

    try {
        return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers -Body $payload -ErrorAction Stop
    } catch {
        throw "Assistant API call failed: $Method $uri. $($_.Exception.Message)"
    }
}

$thread = Invoke-AssistantRequest -Method 'POST' -Path "/threads" -Body @{}
$threadId = $thread.id

$diagnosticJson = $InputData.Diagnostics.Output | ConvertTo-Json -Depth 6 -Compress
$alert = $InputData.Alert
$serverName = $InputData.ServerName

$messageContent = @"
## Alert Triggered
- Server: $serverName
- Rule: $($alert.alertRuleName)
- Severity: $($alert.severity)
- Metric: $($alert.metricName)
- Value: $($alert.metricValue)
- Time: $($alert.timestamp)
- Resource ID: $($alert.targetResourceId)

## Diagnostic Results
$diagnosticJson

Analyze these results. Determine root cause and provide remediation steps.
Use your tools if you need additional Azure context (Resource Graph, Activity Log, VM power state).
"@

Invoke-AssistantRequest -Method 'POST' -Path "/threads/$threadId/messages" -Body @{
    role    = 'user'
    content = $messageContent
} | Out-Null

$run = Invoke-AssistantRequest -Method 'POST' -Path "/threads/$threadId/runs" -Body @{
    assistant_id = $agentId
}
$runId = $run.id

$attempt = 0
$maxAttempts = 30
$runStatus = $null

while ($attempt -lt $maxAttempts) {
    Start-Sleep -Seconds 2
    $attempt++
    $runStatus = Invoke-AssistantRequest -Method 'GET' -Path "/threads/$threadId/runs/$runId" -Body $null

    if ($runStatus.status -eq 'requires_action') {
        $toolCalls = $runStatus.required_action.submit_tool_outputs.tool_calls
        $toolOutputs = foreach ($call in $toolCalls) {
            $result = switch ($call.function.name) {
                'query_resource_graph' {
                    $args = $call.function.arguments | ConvertFrom-Json
                    $query = "Resources | where id =~ '$($args.resource_id)' | project name, type, location, tags, properties.hardwareProfile.vmSize, properties.storageProfile.osDisk.diskSizeGB"
                    Search-AzGraph -Query $query | ConvertTo-Json -Depth 5
                }
                'check_vm_power_state' {
                    $args = $call.function.arguments | ConvertFrom-Json
                    $vm = Get-AzVM -ResourceGroupName $args.resource_group -Name $args.vm_name -Status
                    ($vm.Statuses | Select-Object Code, DisplayStatus, Time) | ConvertTo-Json -Depth 3
                }
                'query_activity_log' {
                    $args = $call.function.arguments | ConvertFrom-Json
                    $hoursBack = if ($args.hours_back) { $args.hours_back } else { 24 }
                    $startTime = (Get-Date).AddHours(-$hoursBack)
                    $logs = Get-AzActivityLog -ResourceId $args.resource_id -StartTime $startTime -MaxRecord 20
                    ($logs | Select-Object EventTimestamp, OperationName, Status, Caller, @{Name = 'Level'; Expression = { $_.Level.ToString() } }) | ConvertTo-Json -Depth 3
                }
                default {
                    @{ error = "Unsupported tool $($call.function.name)" } | ConvertTo-Json -Depth 3
                }
            }

            @{
                tool_call_id = $call.id
                output       = $result
            }
        }

        Invoke-AssistantRequest -Method 'POST' -Path "/threads/$threadId/runs/$runId/submit_tool_outputs" -Body @{
            tool_outputs = $toolOutputs
        } | Out-Null
        continue
    }

    if ($runStatus.status -in @('completed', 'failed', 'cancelled', 'expired')) {
        break
    }
}

if (-not $runStatus -or $runStatus.status -ne 'completed') {
    return @{
        Status     = $runStatus.status
        Error      = $runStatus.last_error
        ThreadId   = $threadId
        RunId      = $runId
        AgentId    = $agentId
        Timestamp  = (Get-Date).ToUniversalTime().ToString('o')
    }
}

$messages = Invoke-AssistantRequest -Method 'GET' -Path "/threads/$threadId/messages?order=desc&limit=1" -Body $null
$agentResponse = $messages.data[0].content[0].text.value

@{
    Status     = 'completed'
    Analysis   = $agentResponse
    ThreadId   = $threadId
    RunId      = $runId
    AgentId    = $agentId
    Timestamp  = (Get-Date).ToUniversalTime().ToString('o')
}
