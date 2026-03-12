param($Input)

$ErrorActionPreference = 'Stop'

$alert = $Input.Alert
$analysis = $Input.Analysis
$results = $Input.Results
$target = $Input.Target

$severityEmoji = switch -Regex ($alert.severity) {
    'Sev0|Sev1' { '🔴' }
    'Sev2' { '🟡' }
    default { '🟢' }
}

$timestamp = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss')
$vmName = if ($target.VMName) { $target.VMName } else { 'unknown' }
$blobName = "$timestamp-$vmName-report.json"

$storageAccount = $env:REPORTS_STORAGE_ACCOUNT
$containerName = if ($env:REPORTS_CONTAINER) { $env:REPORTS_CONTAINER } else { 'reports' }

if (-not $storageAccount) {
    throw 'REPORTS_STORAGE_ACCOUNT app setting is required to store reports.'
}

$report = @{
    TimestampUtc = (Get-Date).ToUniversalTime().ToString('o')
    Alert        = $alert
    Target       = $target
    Diagnostics  = $results
    Analysis     = $analysis
}

$reportJson = $report | ConvertTo-Json -Depth 8

try {
    $context = New-AzStorageContext -StorageAccountName $storageAccount -UseConnectedAccount -ErrorAction Stop
    Set-AzStorageBlobContent -Context $context -Container $containerName -Blob $blobName -StringContent $reportJson -ContentType 'application/json' -Force | Out-Null
} catch {
    throw "Failed to write report to storage. $($_.Exception.Message)"
}

$reportUrl = "https://$storageAccount.blob.core.windows.net/$containerName/$blobName"

function Get-TeamsWebhookUrl {
    if ($env:TEAMS_WEBHOOK_URL) {
        return $env:TEAMS_WEBHOOK_URL
    }

    if ($env:KEYVAULT_NAME) {
        $secretName = if ($env:TEAMS_WEBHOOK_SECRET_NAME) { $env:TEAMS_WEBHOOK_SECRET_NAME } else { 'teams-webhook-url' }
        try {
            $secret = Get-AzKeyVaultSecret -VaultName $env:KEYVAULT_NAME -Name $secretName -ErrorAction Stop
            return [System.Net.NetworkCredential]::new('', $secret.SecretValue).Password
        } catch {
            throw "Failed to retrieve Teams webhook from Key Vault. $($_.Exception.Message)"
        }
    }

    throw 'Teams webhook URL not configured. Set TEAMS_WEBHOOK_URL or Key Vault settings.'
}

$analysisText = if ($analysis -is [string]) {
    $analysis
} elseif ($analysis.Analysis) {
    $analysis.Analysis
} else {
    $analysis | ConvertTo-Json -Depth 5
}

$rootCauseSummary = if ($analysisText) {
    $analysisText.Substring(0, [Math]::Min(700, $analysisText.Length))
} else {
    'No analysis available.'
}

$card = @{
    type    = 'AdaptiveCard'
    version = '1.4'
    body    = @(
        @{
            type   = 'TextBlock'
            size   = 'Large'
            weight = 'Bolder'
            text   = "$severityEmoji $($alert.alertRuleName)"
            wrap   = $true
        },
        @{
            type  = 'FactSet'
            facts = @(
                @{ title = 'Server'; value = $vmName },
                @{ title = 'Severity'; value = $alert.severity },
                @{ title = 'Metric'; value = $alert.metricName },
                @{ title = 'Value'; value = "$($alert.metricValue)" },
                @{ title = 'Time'; value = $alert.timestamp }
            )
        },
        @{
            type   = 'TextBlock'
            text   = 'Root Cause Summary'
            weight = 'Bolder'
            wrap   = $true
        },
        @{
            type = 'TextBlock'
            text = $rootCauseSummary
            wrap = $true
        }
    )
    actions = @(
        @{
            type  = 'Action.OpenUrl'
            title = 'View Full Report'
            url   = $reportUrl
        },
        @{
            type  = 'Action.OpenUrl'
            title = 'View in Azure Portal'
            url   = "https://portal.azure.com/#resource$($alert.targetResourceId)"
        }
    )
}

$teamsPayload = @{
    type        = 'message'
    attachments = @(
        @{
            contentType = 'application/vnd.microsoft.card.adaptive'
            content     = $card
        }
    )
}

try {
    $webhookUrl = Get-TeamsWebhookUrl
    Invoke-RestMethod -Method Post -Uri $webhookUrl -Body ($teamsPayload | ConvertTo-Json -Depth 8) -ContentType 'application/json' -ErrorAction Stop | Out-Null
    $teamsStatus = 'Sent'
} catch {
    $teamsStatus = "Failed: $($_.Exception.Message)"
}

@{
    ReportUrl   = $reportUrl
    StorageBlob = $blobName
    TeamsStatus = $teamsStatus
}
