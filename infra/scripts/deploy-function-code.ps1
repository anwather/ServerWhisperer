param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroup,

    [string]$FunctionAppName,

    [string]$DeploymentName = 'main'
)

$ErrorActionPreference = 'Stop'

function Resolve-FunctionAppName {
    if ($FunctionAppName) {
        return $FunctionAppName
    }

    $name = az deployment group show `
        --resource-group $ResourceGroup `
        --name $DeploymentName `
        --query 'properties.outputs.functionAppName.value' `
        -o tsv 2>$null

    if (-not $name) {
        throw 'Function App name not provided and not found in deployment outputs.'
    }

    return $name
}

$functionApp = Resolve-FunctionAppName

$sourceRoot = Join-Path $PSScriptRoot '..\function-app'
$diagnosticScript = Join-Path $PSScriptRoot 'Get-AllDiagnostics.ps1'

if (-not (Test-Path $sourceRoot)) {
    throw "Function app source not found at $sourceRoot."
}

if (-not (Test-Path $diagnosticScript)) {
    throw "Diagnostic script not found at $diagnosticScript."
}

$stagingRoot = Join-Path $env:TEMP ("functionapp-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stagingRoot | Out-Null

try {
    Copy-Item -Path (Join-Path $sourceRoot '*') -Destination $stagingRoot -Recurse -Force
    Copy-Item -Path $diagnosticScript -Destination (Join-Path $stagingRoot 'Get-AllDiagnostics.ps1') -Force

    $zipPath = Join-Path $env:TEMP ("functionapp-" + [guid]::NewGuid().ToString('N') + '.zip')
    Compress-Archive -Path (Join-Path $stagingRoot '*') -DestinationPath $zipPath -Force

    az functionapp deployment source config-zip `
        --resource-group $ResourceGroup `
        --name $functionApp `
        --src $zipPath `
        --only-show-errors
} finally {
    if (Test-Path $stagingRoot) {
        Remove-Item -Path $stagingRoot -Recurse -Force
    }
    if (Test-Path $zipPath) {
        Remove-Item -Path $zipPath -Force
    }
}

Write-Host "Function app deployment complete: $functionApp"
