param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $true)]
    [string]$ProjectName,

    [string]$DeploymentName = 'main'
)

$ErrorActionPreference = 'Stop'

function Get-FoundryEndpoint {
    $endpoint = az deployment group show `
        --resource-group $ResourceGroup `
        --name $DeploymentName `
        --query 'properties.outputs.foundryEndpoint.value' `
        -o tsv 2>$null

    if (-not $endpoint) {
        $endpoint = az resource show `
            --resource-group $ResourceGroup `
            --name $ProjectName `
            --resource-type 'Microsoft.MachineLearningServices/workspaces' `
            --query 'properties.discoveryUrl' `
            -o tsv 2>$null
    }

    if (-not $endpoint) {
        throw 'Unable to resolve Foundry endpoint from deployment outputs or project resource.'
    }

    return $endpoint.TrimEnd('/')
}

$foundryEndpoint = Get-FoundryEndpoint
$token = az account get-access-token --resource https://management.azure.com --query accessToken -o tsv

if (-not $token) {
    throw 'Failed to acquire Azure CLI access token.'
}

$systemPrompt = @"
You are ServerWhisperer, an expert Windows Server diagnostician working inside
an automated alert-to-diagnosis pipeline.

You receive structured diagnostic data collected from a Windows Server in response
to an Azure Monitor alert. Your job:

1. IDENTIFY the ROOT CAUSE — not just symptoms. Correlate across diagnostic areas.
2. ASSESS severity: Critical (🔴), Warning (🟡), or Healthy (🟢)
3. CHECK for patterns — use your knowledge base of past investigations to see if
   this server or alert type has a recurring issue.
4. USE YOUR TOOLS when you need more context:
   - query_resource_graph: Get VM metadata, tags, size, location
   - check_vm_power_state: Verify the VM is running and check for recent restarts
   - query_activity_log: Look for recent control-plane events (deallocations,
     maintenance, NSG changes, Spot evictions)
5. PROVIDE specific, actionable remediation steps.
6. FLAG anything suspicious that warrants human investigation.

Output format:
- Status: [🟢 Healthy | 🟡 Warning | 🔴 Critical]
- Root Cause: [1-2 sentence summary]
- Evidence: [Key data points that support the diagnosis]
- Historical Context: [Any similar past incidents from knowledge base]
- Remediation: [Numbered action steps]
- Escalation: [Who to involve if needed]

Be specific. Use data from the diagnostics. Don't speculate without evidence.
"@

$body = @{
    name         = 'serverwhisperer-diagnostician'
    model        = 'gpt-4o-mini'
    instructions = $systemPrompt
    tools        = @(
        @{
            type     = 'function'
            function = @{
                name        = 'query_resource_graph'
                description = 'Query Azure Resource Graph for VM metadata, tags, size, location, and related resources'
                parameters  = @{
                    type       = 'object'
                    properties = @{
                        resource_id = @{
                            type        = 'string'
                            description = 'Azure resource ID of the VM'
                        }
                    }
                    required   = @('resource_id')
                }
            }
        },
        @{
            type     = 'function'
            function = @{
                name        = 'check_vm_power_state'
                description = 'Check VM power state and recent restart history'
                parameters  = @{
                    type       = 'object'
                    properties = @{
                        resource_group = @{ type = 'string' }
                        vm_name        = @{ type = 'string' }
                    }
                    required   = @('resource_group', 'vm_name')
                }
            }
        },
        @{
            type     = 'function'
            function = @{
                name        = 'query_activity_log'
                description = 'Query Azure Activity Log for recent VM operations (deallocations, restarts, maintenance events, Spot evictions, NSG changes)'
                parameters  = @{
                    type       = 'object'
                    properties = @{
                        resource_id = @{ type = 'string' }
                        hours_back  = @{ type = 'integer'; default = 24 }
                    }
                    required   = @('resource_id')
                }
            }
        }
    )
}

$headers = @{
    Authorization  = "Bearer $token"
    'Content-Type' = 'application/json'
}

try {
    $response = Invoke-RestMethod -Method Post -Uri "$foundryEndpoint/agents/v1.0/assistants" -Headers $headers -Body ($body | ConvertTo-Json -Depth 10) -ErrorAction Stop
} catch {
    throw "Foundry agent creation failed. $($_.Exception.Message)"
}

Write-Host "Foundry agent created: $($response.id)"
Write-Host "Set FOUNDRY_AGENT_ID to $($response.id)"
