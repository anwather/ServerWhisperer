<#
.SYNOPSIS
    Post-deployment smoke test for ServerWhisperer Alert-to-Diagnosis Pipeline.

.DESCRIPTION
    Validates that all Azure resources are correctly deployed and configured before running the demo.
    Checks resource existence, configuration, connectivity, and readiness.

.PARAMETER ResourceGroup
    Required. The resource group name containing the deployed resources.

.PARAMETER ResourcePrefix
    Optional. The prefix used during deployment. Default: 'sw'

.PARAMETER TestTeams
    Optional. If specified, sends a test adaptive card to the Teams webhook.

.EXAMPLE
    .\Validate-Deployment.ps1 -ResourceGroup sw-demo-rg

.EXAMPLE
    .\Validate-Deployment.ps1 -ResourceGroup sw-demo-rg -ResourcePrefix demo -TestTeams -Verbose

.NOTES
    Author: Skinner (Tester/QA)
    Version: 1.0
    Created: 2026-03-12
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ResourceGroup,
    
    [Parameter()]
    [string]$ResourcePrefix = 'sw',
    
    [Parameter()]
    [switch]$TestTeams
)

$ErrorActionPreference = 'Stop'

# Results tracking
$checks = @()
$passedCount = 0
$failedCount = 0

function Add-CheckResult {
    param(
        [string]$Name,
        [bool]$Passed,
        [string]$Message,
        [string]$Recommendation = ''
    )
    
    $script:checks += [PSCustomObject]@{
        Name           = $Name
        Passed         = $Passed
        Message        = $Message
        Recommendation = $Recommendation
    }
    
    if ($Passed) {
        $script:passedCount++
        Write-Host "[[PASS]] $Name`: $Message" -ForegroundColor Green
    } else {
        $script:failedCount++
        Write-Host "[[FAIL]] $Name`: $Message" -ForegroundColor Red
        if ($Recommendation) {
            Write-Host "     → $Recommendation" -ForegroundColor Yellow
        }
    }
}

function Test-CheckSkipped {
    param([string]$Name, [string]$Reason)
    Write-Host "[[SKIP]] $Name`: $Reason" -ForegroundColor Cyan
}

# Print header
Write-Host ""
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "[CHECK] DEPLOYMENT VALIDATION" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Resource Group: $ResourceGroup"
Write-Host "Prefix: $ResourcePrefix"
Write-Host ""

# Expected resource names
$vmName = "$ResourcePrefix-demo-vm"
$funcAppName = "$ResourcePrefix-demo-func"
$kvName = "$ResourcePrefix-kv-$(Get-Random -Minimum 1000 -Maximum 9999)"
$storageAccountPrefix = $ResourcePrefix.Replace('-','') + 'st'
$searchServiceName = "$ResourcePrefix-search"
$actionGroupName = "ServerWhisperer-AG"

try {
    # =========================================================================
    # 1. Resource Group exists
    # =========================================================================
    Write-Verbose "Checking resource group..."
    try {
        $rg = Get-AzResourceGroup -Name $ResourceGroup -ErrorAction Stop
        $resources = Get-AzResource -ResourceGroupName $ResourceGroup
        Add-CheckResult -Name "Resource Group" -Passed $true -Message "$ResourceGroup ($($resources.Count) resources)"
    } catch {
        Add-CheckResult -Name "Resource Group" -Passed $false -Message "Not found" `
            -Recommendation "Run: az deployment group create -f infra/main.bicep -g $ResourceGroup"
        throw "Resource group not found. Cannot continue validation."
    }

    # =========================================================================
    # 2. VM is running
    # =========================================================================
    Write-Verbose "Checking VM status..."
    $vm = Get-AzVM -ResourceGroupName $ResourceGroup -Name $vmName -Status -ErrorAction SilentlyContinue
    if ($vm) {
        $powerState = ($vm.Statuses | Where-Object { $_.Code -like 'PowerState/*' }).DisplayStatus
        if ($powerState -eq 'VM running') {
            Add-CheckResult -Name "VM" -Passed $true -Message "$vmName (Running)"
        } else {
            Add-CheckResult -Name "VM" -Passed $false -Message "$vmName ($powerState)" `
                -Recommendation "Start the VM: Start-AzVM -ResourceGroupName $ResourceGroup -Name $vmName"
        }
    } else {
        Add-CheckResult -Name "VM" -Passed $false -Message "VM not found" `
            -Recommendation "Check deployment or VM name"
    }

    # =========================================================================
    # 3. VM has system-assigned managed identity
    # =========================================================================
    Write-Verbose "Checking VM managed identity..."
    $vmDetail = Get-AzVM -ResourceGroupName $ResourceGroup -Name $vmName -ErrorAction SilentlyContinue
    if ($vmDetail -and $vmDetail.Identity -and $vmDetail.Identity.Type -match 'SystemAssigned') {
        Add-CheckResult -Name "VM Managed Identity" -Passed $true -Message "Enabled"
    } else {
        Add-CheckResult -Name "VM Managed Identity" -Passed $false -Message "Not enabled" `
            -Recommendation "Enable in Bicep: identity: { type: 'SystemAssigned' }"
    }

    # =========================================================================
    # 4. Function App is running
    # =========================================================================
    Write-Verbose "Checking Function App..."
    $funcApps = Get-AzWebApp -ResourceGroupName $ResourceGroup | Where-Object { $_.Kind -like '*functionapp*' }
    if ($funcApps.Count -gt 0) {
        $funcApp = $funcApps[0]
        $state = $funcApp.State
        if ($state -eq 'Running') {
            Add-CheckResult -Name "Function App" -Passed $true -Message "$($funcApp.Name) (Running)"
        } else {
            Add-CheckResult -Name "Function App" -Passed $false -Message "$($funcApp.Name) ($state)" `
                -Recommendation "Start the Function App in Azure Portal or via Start-AzWebApp"
        }
    } else {
        Add-CheckResult -Name "Function App" -Passed $false -Message "Not found" `
            -Recommendation "Check deployment or function app name pattern"
    }

    # =========================================================================
    # 5. Function App has correct app settings
    # =========================================================================
    Write-Verbose "Checking Function App settings..."
    if ($funcApp) {
        $appSettings = Get-AzWebApp -ResourceGroupName $ResourceGroup -Name $funcApp.Name | 
            Select-Object -ExpandProperty SiteConfig | 
            Select-Object -ExpandProperty AppSettings
        
        $foundryEndpoint = $appSettings | Where-Object { $_.Name -eq 'FOUNDRY_ENDPOINT' }
        $foundryAgentId = $appSettings | Where-Object { $_.Name -eq 'FOUNDRY_AGENT_ID' }
        
        $endpointValid = $foundryEndpoint -and $foundryEndpoint.Value -and $foundryEndpoint.Value -notmatch 'PLACEHOLDER|your-|example'
        $agentIdValid = $foundryAgentId -and $foundryAgentId.Value -and $foundryAgentId.Value -notmatch 'PLACEHOLDER|your-|example'
        
        if ($endpointValid -and $agentIdValid) {
            Add-CheckResult -Name "Function App Settings" -Passed $true -Message "FOUNDRY_ENDPOINT set, FOUNDRY_AGENT_ID set"
        } elseif (-not $endpointValid) {
            Add-CheckResult -Name "Function App Settings" -Passed $false -Message "FOUNDRY_ENDPOINT is '$($foundryEndpoint.Value)'" `
                -Recommendation "Update app setting with actual Foundry project endpoint"
        } elseif (-not $agentIdValid) {
            Add-CheckResult -Name "Function App Settings" -Passed $false -Message "FOUNDRY_AGENT_ID is '$($foundryAgentId.Value)'" `
                -Recommendation "Run: infra/scripts/create-foundry-agent.ps1 -ResourceGroup $ResourceGroup"
        }
    }

    # =========================================================================
    # 6. Alert rules are active
    # =========================================================================
    Write-Verbose "Checking alert rules..."
    $alertRules = Get-AzMetricAlertRuleV2 -ResourceGroupName $ResourceGroup -ErrorAction SilentlyContinue
    if ($alertRules.Count -ge 3) {
        $enabled = ($alertRules | Where-Object { $_.Enabled -eq $true }).Count
        if ($enabled -eq $alertRules.Count) {
            Add-CheckResult -Name "Alert Rules" -Passed $true -Message "$enabled/$($alertRules.Count) active"
        } else {
            Add-CheckResult -Name "Alert Rules" -Passed $false -Message "$enabled/$($alertRules.Count) enabled (some disabled)" `
                -Recommendation "Enable all alert rules in Azure Portal → Alerts"
        }
    } else {
        Add-CheckResult -Name "Alert Rules" -Passed $false -Message "$($alertRules.Count) found (expected 3)" `
            -Recommendation "Check monitoring.bicep deployment"
    }

    # =========================================================================
    # 7. Action Group exists and has webhook
    # =========================================================================
    Write-Verbose "Checking Action Group..."
    $actionGroups = Get-AzActionGroup -ResourceGroupName $ResourceGroup -ErrorAction SilentlyContinue
    if ($actionGroups.Count -gt 0) {
        $ag = $actionGroups[0]
        $webhookCount = 0
        if ($ag.EventHubReceiver) { $webhookCount += $ag.EventHubReceiver.Count }
        if ($ag.WebhookReceiver) { $webhookCount += $ag.WebhookReceiver.Count }
        
        Add-CheckResult -Name "Action Group" -Passed $true -Message "$($ag.Name) ($webhookCount receiver(s))"
    } else {
        Add-CheckResult -Name "Action Group" -Passed $false -Message "Not found" `
            -Recommendation "Check monitoring.bicep or event-grid.bicep deployment"
    }

    # =========================================================================
    # 8. Key Vault is accessible by Function App
    # =========================================================================
    Write-Verbose "Checking Key Vault..."
    $kvs = Get-AzKeyVault -ResourceGroupName $ResourceGroup -ErrorAction SilentlyContinue
    if ($kvs.Count -gt 0) {
        $kv = $kvs[0]
        
        # Check if Function App MI has access policy
        if ($funcApp -and $funcApp.Identity -and $funcApp.Identity.PrincipalId) {
            $accessPolicies = Get-AzKeyVault -VaultName $kv.VaultName | Select-Object -ExpandProperty AccessPolicies
            $hasAccess = $accessPolicies | Where-Object { $_.ObjectId -eq $funcApp.Identity.PrincipalId }
            
            if ($hasAccess) {
                Add-CheckResult -Name "Key Vault" -Passed $true -Message "Accessible by Function App MI"
            } else {
                Add-CheckResult -Name "Key Vault" -Passed $false -Message "Function App MI not in access policies" `
                    -Recommendation "Add access policy: Set-AzKeyVaultAccessPolicy -VaultName $($kv.VaultName) -ObjectId $($funcApp.Identity.PrincipalId) -PermissionsToSecrets get,list"
            }
        } else {
            Add-CheckResult -Name "Key Vault" -Passed $true -Message "$($kv.VaultName) exists"
        }
    } else {
        Add-CheckResult -Name "Key Vault" -Passed $false -Message "Not found" `
            -Recommendation "Check keyvault.bicep deployment"
    }

    # =========================================================================
    # 9. Storage account has required containers
    # =========================================================================
    Write-Verbose "Checking Storage Account..."
    $storageAccounts = Get-AzStorageAccount -ResourceGroupName $ResourceGroup -ErrorAction SilentlyContinue
    if ($storageAccounts.Count -gt 0) {
        $storage = $storageAccounts[0]
        $ctx = $storage.Context
        
        try {
            $containers = Get-AzStorageContainer -Context $ctx -ErrorAction SilentlyContinue
            $hasReports = $containers | Where-Object { $_.Name -eq 'reports' }
            $hasDiagnostics = $containers | Where-Object { $_.Name -eq 'diagnostics' }
            
            if ($hasReports -and $hasDiagnostics) {
                Add-CheckResult -Name "Storage" -Passed $true -Message "reports ✓, diagnostics ✓"
            } elseif (-not $hasReports) {
                Add-CheckResult -Name "Storage" -Passed $false -Message "'reports' container missing" `
                    -Recommendation "Create: New-AzStorageContainer -Name reports -Context `$ctx"
            } elseif (-not $hasDiagnostics) {
                Add-CheckResult -Name "Storage" -Passed $false -Message "'diagnostics' container missing" `
                    -Recommendation "Create: New-AzStorageContainer -Name diagnostics -Context `$ctx"
            }
        } catch {
            Add-CheckResult -Name "Storage" -Passed $false -Message "Cannot list containers (access denied?)" `
                -Recommendation "Verify RBAC permissions on storage account"
        }
    } else {
        Add-CheckResult -Name "Storage" -Passed $false -Message "Not found" `
            -Recommendation "Check storage.bicep deployment"
    }

    # =========================================================================
    # 10. AI Search service is running
    # =========================================================================
    Write-Verbose "Checking AI Search..."
    $searchServices = Get-AzResource -ResourceGroupName $ResourceGroup -ResourceType 'Microsoft.Search/searchServices' -ErrorAction SilentlyContinue
    if ($searchServices.Count -gt 0) {
        $search = $searchServices[0]
        Add-CheckResult -Name "AI Search" -Passed $true -Message "Running"
    } else {
        Add-CheckResult -Name "AI Search" -Passed $false -Message "Not found" `
            -Recommendation "Check search.bicep deployment"
    }

    # =========================================================================
    # 11. Foundry project exists
    # =========================================================================
    Write-Verbose "Checking Foundry project..."
    $foundryProjects = Get-AzResource -ResourceGroupName $ResourceGroup -ResourceType 'Microsoft.MachineLearningServices/workspaces' -ErrorAction SilentlyContinue
    if ($foundryProjects.Count -gt 0) {
        Add-CheckResult -Name "Foundry Project" -Passed $true -Message "exists"
    } else {
        Add-CheckResult -Name "Foundry Project" -Passed $false -Message "Not found" `
            -Recommendation "Check foundry.bicep deployment"
    }

    # =========================================================================
    # 12. Run Command works (test VM accessibility)
    # =========================================================================
    Write-Verbose "Testing Run Command..."
    if ($vm -and $powerState -eq 'VM running') {
        try {
            Write-Host "[⏳] Testing Invoke-AzVMRunCommand (this may take 30-60 seconds)..." -ForegroundColor Cyan
            $runResult = Invoke-AzVMRunCommand `
                -ResourceGroupName $ResourceGroup `
                -VMName $vmName `
                -CommandId 'RunPowerShellScript' `
                -ScriptString 'hostname' `
                -ErrorAction Stop
            
            $output = ($runResult.Value | Where-Object { $_.Code -eq 'ComponentStatus/StdOut/succeeded' }).Message
            if ($output -and $output.Trim()) {
                Add-CheckResult -Name "Run Command" -Passed $true -Message "hostname returned '$($output.Trim())'"
            } else {
                Add-CheckResult -Name "Run Command" -Passed $false -Message "Executed but no output" `
                    -Recommendation "Check VM guest OS status and VM agent health"
            }
        } catch {
            Add-CheckResult -Name "Run Command" -Passed $false -Message $_.Exception.Message `
                -Recommendation "Verify VM agent is running and Function App MI has 'Virtual Machine Contributor' role"
        }
    } else {
        Test-CheckSkipped -Name "Run Command" -Reason "VM is not running"
    }

    # =========================================================================
    # 13. Teams webhook (optional test)
    # =========================================================================
    if ($TestTeams) {
        Write-Verbose "Testing Teams webhook..."
        
        # Try to get webhook URL from Key Vault
        if ($kv) {
            try {
                $webhookSecret = Get-AzKeyVaultSecret -VaultName $kv.VaultName -Name 'TeamsWebhookUrl' -AsPlainText -ErrorAction Stop
                
                $testCard = @{
                    type = "message"
                    attachments = @(
                        @{
                            contentType = "application/vnd.microsoft.card.adaptive"
                            content = @{
                                type = "AdaptiveCard"
                                version = "1.4"
                                body = @(
                                    @{
                                        type = "TextBlock"
                                        size = "Large"
                                        weight = "Bolder"
                                        text = "[CHECK] Deployment Validation Test"
                                    }
                                    @{
                                        type = "TextBlock"
                                        text = "This is a test message from Validate-Deployment.ps1"
                                        wrap = $true
                                    }
                                    @{
                                        type = "FactSet"
                                        facts = @(
                                            @{ title = "Resource Group"; value = $ResourceGroup }
                                            @{ title = "Timestamp"; value = (Get-Date -Format 'o') }
                                            @{ title = "Status"; value = "[PASS] Validation in progress" }
                                        )
                                    }
                                )
                            }
                        }
                    )
                } | ConvertTo-Json -Depth 10

                $response = Invoke-RestMethod -Uri $webhookSecret -Method Post -Body $testCard -ContentType 'application/json' -ErrorAction Stop
                Add-CheckResult -Name "Teams Webhook" -Passed $true -Message "Test card sent successfully"
                
            } catch {
                Add-CheckResult -Name "Teams Webhook" -Passed $false -Message $_.Exception.Message `
                    -Recommendation "Verify webhook URL in Key Vault secret 'TeamsWebhookUrl'"
            }
        } else {
            Add-CheckResult -Name "Teams Webhook" -Passed $false -Message "Key Vault not found, cannot retrieve webhook URL" `
                -Recommendation "Deploy Key Vault first"
        }
    } else {
        Test-CheckSkipped -Name "Teams Webhook" -Reason "Skipped (use -TestTeams to test)"
    }

} catch {
    Write-Host ""
    Write-Host "[FAIL] Validation failed with error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    exit 1
}

# =========================================================================
# Print Summary
# =========================================================================
Write-Host ""
Write-Host "===============================================" -ForegroundColor Cyan

if ($failedCount -eq 0) {
    Write-Host "RESULT: $passedCount/$passedCount checks passed [PASS]" -ForegroundColor Green
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "[PASS] Deployment is ready for demo!" -ForegroundColor Green
    Write-Host ""
    exit 0
} else {
    Write-Host "RESULT: $passedCount checks passed, $failedCount failed [FAIL]" -ForegroundColor Red
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "[FAIL] Fix the failed checks above before proceeding." -ForegroundColor Red
    Write-Host ""
    exit 1
}
