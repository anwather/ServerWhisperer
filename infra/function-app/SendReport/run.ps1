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

$severityLabel = switch -Regex ($alert.severity) {
    'Sev0|Sev1' { 'critical' }
    'Sev2' { 'warning' }
    default { 'info' }
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

# Get GitHub settings
$githubToken = $env:GitHubToken
$githubOwner = $env:GitHubOwner
$githubRepo = $env:GitHubRepo

if (-not $githubToken -or -not $githubOwner -or -not $githubRepo) {
    Write-Warning "GitHub settings incomplete. GitHubToken, GitHubOwner, and GitHubRepo are required."
    return @{
        ReportUrl    = $reportUrl
        StorageBlob  = $blobName
        GitHubStatus = 'Skipped: GitHub settings not configured'
    }
}

$analysisText = if ($analysis -is [string]) {
    $analysis
} elseif ($analysis.Analysis) {
    $analysis.Analysis
} else {
    $analysis | ConvertTo-Json -Depth 5
}

$portalUrl = "https://portal.azure.com/#resource$($alert.targetResourceId)"

# Create GitHub issue body
$issueBody = @"
## Alert Details
- **Server:** $vmName
- **Severity:** $($alert.severity)
- **Metric:** $($alert.metricName)
- **Value:** $($alert.metricValue)
- **Time:** $($alert.timestamp)
- **Resource ID:** $($alert.targetResourceId)

## AI Analysis
$analysisText

## Links
- [View Full Report (Blob Storage)]($reportUrl)
- [View VM in Azure Portal]($portalUrl)

---
*This issue was automatically created by ServerWhisperer alert automation.*
"@

$issueTitle = "[ServerWhisperer] $severityEmoji $($alert.alertRuleName) on $vmName"

$issuePayload = @{
    title  = $issueTitle
    body   = $issueBody
    labels = @('serverwhisperer', $severityLabel)
} | ConvertTo-Json -Depth 5

$githubApiUrl = "https://api.github.com/repos/$githubOwner/$githubRepo/issues"

try {
    $headers = @{
        Authorization = "token $githubToken"
        Accept        = 'application/vnd.github.v3+json'
    }
    
    $issue = Invoke-RestMethod -Method Post -Uri $githubApiUrl -Headers $headers -Body $issuePayload -ContentType 'application/json' -ErrorAction Stop
    $githubStatus = "Created issue #$($issue.number): $($issue.html_url)"
} catch {
    $githubStatus = "Failed: $($_.Exception.Message)"
}

@{
    ReportUrl    = $reportUrl
    StorageBlob  = $blobName
    GitHubStatus = $githubStatus
}
