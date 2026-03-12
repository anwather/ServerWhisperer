param($Context)

$alert = $Context.Input

$retryOptions = New-DurableRetryOptions -FirstRetryInterval (New-TimeSpan -Seconds 5) -MaxNumberOfAttempts 3

$classification = Invoke-DurableActivity -FunctionName 'ClassifyTarget' -Input $alert -RetryOptions $retryOptions

$diagnostics = Invoke-DurableActivity -FunctionName 'ExecuteDiagnostics' -Input @{
    Target    = $classification.Target
    AlertType = $classification.AlertType
    Alert     = $alert
} -RetryOptions $retryOptions

$analysis = Invoke-DurableActivity -FunctionName 'AnalyzeWithFoundryAgent' -Input @{
    Alert       = $alert
    Diagnostics = $diagnostics
    ServerName  = $classification.Target.VMName
    Target      = $classification.Target
} -RetryOptions $retryOptions

$report = Invoke-DurableActivity -FunctionName 'SendReport' -Input @{
    Alert    = $alert
    Analysis = $analysis
    Results  = $diagnostics
    Target   = $classification.Target
} -RetryOptions $retryOptions

@{
    Status     = 'Completed'
    Report     = $report
    Target     = $classification.Target
    AlertRule  = $alert.alertRuleName
    Severity   = $alert.severity
}
