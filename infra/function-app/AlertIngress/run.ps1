using namespace System.Net

param(
    $Request,
    $TriggerMetadata,
    $starter
)

$ErrorActionPreference = 'Stop'

try {
    if (-not $Request.Body) {
        throw 'Request body is empty.'
    }

    $payload = if ($Request.Body -is [string]) {
        $Request.Body | ConvertFrom-Json
    } else {
        $Request.Body
    }

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

    $instanceId = Start-DurableOrchestration -FunctionName 'InvestigationOrchestrator' -Input $alertInput -Client $starter
    $Response = New-DurableOrchestrationCheckStatusResponse -Request $Request -InstanceId $instanceId -Client $starter
} catch {
    $Response = [HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::BadRequest
        Body       = @{ error = $_.Exception.Message } | ConvertTo-Json
        Headers    = @{ 'Content-Type' = 'application/json' }
    }
}
