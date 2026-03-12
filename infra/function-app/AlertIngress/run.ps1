using namespace System.Net

param(
    $Request,
    $TriggerMetadata,
    $starter
)

Write-Host "AlertIngress triggered. Method: $($Request.Method)"

try {
    if (-not $Request.Body) {
        throw 'Request body is empty.'
    }

    $payload = if ($Request.Body -is [string]) {
        $Request.Body | ConvertFrom-Json
    } else {
        $Request.Body
    }

    Write-Host "Parsed alert payload. Schema: $($payload.schemaId)"

    $essentials = $payload.data.essentials
    $alertContext = $payload.data.alertContext

    $metricContext = $alertContext.condition.allOf | Select-Object -First 1

    $alertInput = [ordered]@{
        alertRuleName    = $essentials.alertRule
        severity         = $essentials.severity
        signalType       = $essentials.signalType
        monitorCondition = $essentials.monitorCondition
        targetResourceId = ($essentials.alertTargetIDs | Select-Object -First 1)
        metricName       = $metricContext.metricName
        metricValue      = $metricContext.metricValue
        timestamp        = $essentials.firedDateTime
        alertDescription = $essentials.description
        rawAlert         = $payload
    }

    if (-not $alertInput.targetResourceId) {
        $alertInput.targetResourceId = $alertContext.resourceId
    }

    if ([string]::IsNullOrWhiteSpace($alertInput.metricName)) {
        $alertInput.metricName = $alertContext.metricName
    }

    if ($null -eq $alertInput.metricValue) {
        $alertInput.metricValue = $alertContext.metricValue
    }

    if (-not $alertInput.timestamp) {
        $alertInput.timestamp = $alertContext.timestamp
    }

    Write-Host "Starting orchestration for alert: $($alertInput.alertRuleName) on $($alertInput.targetResourceId)"
    Write-Host "Durable client binding present: $($null -ne $starter)"

    $instanceId = Start-DurableOrchestration -FunctionName 'InvestigationOrchestrator' -Input $alertInput -DurableClient $starter
    Write-Host "Orchestration started. InstanceId: $instanceId"

    $checkStatusResponse = New-DurableOrchestrationCheckStatusResponse -Request $Request -InstanceId $instanceId -DurableClient $starter

    Push-OutputBinding -Name Response -Value $checkStatusResponse
} catch {
    Write-Error "AlertIngress failed: $($_.Exception.Message)"
    Write-Error $_.ScriptStackTrace

    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::InternalServerError
        Body       = (@{ error = $_.Exception.Message; stack = $_.ScriptStackTrace } | ConvertTo-Json)
        Headers    = @{ 'Content-Type' = 'application/json' }
    })
}
