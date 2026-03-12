param($InputData)

$ErrorActionPreference = 'Stop'

Write-Host "ClassifyTarget received input type: $($InputData.GetType().FullName)"
Write-Host "ClassifyTarget input keys: $(($InputData | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name) -join ', ')"
Write-Host "ClassifyTarget targetResourceId: '$($InputData.targetResourceId)'"

if (-not $InputData.targetResourceId) {
    throw "Alert payload missing targetResourceId. Input dump: $($InputData | ConvertTo-Json -Depth 2 -Compress)"
}

$resourceId = $InputData.targetResourceId
$subscriptionIdFromId = ($resourceId -split '/')[2]
$query = @"
Resources
| where id =~ '$resourceId'
| project name, resourceGroup, subscriptionId, location, tags, type, properties
"@

try {
    $resource = Search-AzGraph -Query $query -Subscription $subscriptionIdFromId -First 1 -ErrorAction Stop | Select-Object -First 1
} catch {
    throw "Resource Graph query failed for $resourceId. $($_.Exception.Message)"
}

if (-not $resource) {
    throw "Target resource not found in Resource Graph: $resourceId"
}

$alertType = if ($InputData.metricName) { $InputData.metricName } else { $InputData.alertRuleName }

$areas = @('Overview', 'Performance', 'Disks', 'Services', 'Processes', 'Events')
switch -Regex ($alertType) {
    'cpu' { $areas = @('Overview', 'Performance', 'Processes', 'Events') }
    'memory' { $areas = @('Overview', 'Performance', 'Processes', 'Events') }
    'disk' { $areas = @('Overview', 'Disks', 'Services', 'Events') }
}

@{
    Target = @{
        VMName            = $resource.name
        ResourceGroupName = $resource.resourceGroup
        SubscriptionId    = $resource.subscriptionId
        Location          = $resource.location
        VmSize            = $resource.properties.hardwareProfile.vmSize
        OsType            = $resource.properties.storageProfile.osDisk.osType
        ResourceId        = $resourceId
        Tags              = $resource.tags
        ResourceType      = $resource.type
    }
    DiagnosticPlan = @{
        RunFullDiagnostics = $true
        Areas              = $areas
    }
    AlertType  = $alertType
    SignalType = $InputData.signalType
}
