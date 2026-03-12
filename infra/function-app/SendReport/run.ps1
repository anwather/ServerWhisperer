param($InputData)

$ErrorActionPreference = 'Stop'
Ensure-AzConnected

$alert = $InputData.Alert
$analysis = $InputData.Analysis
$results = $InputData.Results
$target = $InputData.Target

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
    $tempFile = Join-Path $env:TEMP $blobName
    $reportJson | Set-Content -Path $tempFile -Encoding UTF8 -Force
    Set-AzStorageBlobContent -Context $context -Container $containerName -Blob $blobName -File $tempFile -Properties @{ ContentType = 'application/json' } -Force | Out-Null
    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
} catch {
    throw "Failed to write report to storage. $($_.Exception.Message)"
}

$reportUrl = "https://$storageAccount.blob.core.windows.net/$containerName/$blobName"

function Get-TeamsWebhookUrl {
    if ($env:TEAMS_WEBHOOK_URL) {
        return $env:TEAMS_WEBHOOK_URL
    }

    if ($env:TeamsWebhookUrl -and $env:TeamsWebhookUrl -notmatch '@Microsoft\.KeyVault') {
        return $env:TeamsWebhookUrl
    }

    if ($env:KEYVAULT_NAME) {
        $secretName = if ($env:TEAMS_WEBHOOK_SECRET_NAME) { $env:TEAMS_WEBHOOK_SECRET_NAME } else { 'teams-webhook-url' }
        try {
            $secret = Get-AzKeyVaultSecret -VaultName $env:KEYVAULT_NAME -Name $secretName -ErrorAction Stop
            return [System.Net.NetworkCredential]::new('', $secret.SecretValue).Password
        } catch {
            return $null
        }
    }

    return $null
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
    if ($webhookUrl) {
        Invoke-RestMethod -Method Post -Uri $webhookUrl -Body ($teamsPayload | ConvertTo-Json -Depth 8) -ContentType 'application/json' -ErrorAction Stop | Out-Null
        $teamsStatus = 'Sent'
    } else {
        $teamsStatus = 'Skipped: No webhook URL configured'
    }
} catch {
    $teamsStatus = "Failed: $($_.Exception.Message)"
}

@{
    ReportUrl   = $reportUrl
    StorageBlob = $blobName
    TeamsStatus = $teamsStatus
}
