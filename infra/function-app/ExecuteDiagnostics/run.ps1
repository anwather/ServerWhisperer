param($InputData)

$ErrorActionPreference = 'Stop'

$target = $InputData.Target
if (-not $target.VMName -or -not $target.ResourceGroupName) {
    throw 'ExecuteDiagnostics requires Target.VMName and Target.ResourceGroupName.'
}

if ($target.SubscriptionId) {
    try {
        Set-AzContext -SubscriptionId $target.SubscriptionId -ErrorAction Stop | Out-Null
    } catch {
        throw "Failed to set Az context to subscription $($target.SubscriptionId). $($_.Exception.Message)"
    }
}

$scriptPath = Join-Path $PSScriptRoot '..\Get-AllDiagnostics.ps1'
if (-not (Test-Path $scriptPath)) {
    throw "Diagnostic script not found at $scriptPath. Ensure deployment includes Get-AllDiagnostics.ps1."
}

$scriptContent = Get-Content -Path $scriptPath -Raw
$parameters = @{ AlertType = $InputData.AlertType }

try {
    $runResult = Invoke-AzVMRunCommand `
        -ResourceGroupName $target.ResourceGroupName `
        -VMName $target.VMName `
        -CommandId 'RunPowerShellScript' `
        -ScriptString $scriptContent `
        -Parameter $parameters `
        -TimeoutInSeconds 90 `
        -ErrorAction Stop
} catch {
    throw "Invoke-AzVMRunCommand failed for $($target.VMName). $($_.Exception.Message)"
}

$stdout = $runResult.Value |
    Where-Object { $_.Code -eq 'ComponentStatus/StdOut/succeeded' } |
    Select-Object -ExpandProperty Message -ErrorAction SilentlyContinue
$stderr = $runResult.Value |
    Where-Object { $_.Code -eq 'ComponentStatus/StdErr/succeeded' } |
    Select-Object -ExpandProperty Message -ErrorAction SilentlyContinue

$stdoutText = if ($stdout -is [array]) { $stdout -join "`n" } else { $stdout }
$stderrText = if ($stderr -is [array]) { $stderr -join "`n" } else { $stderr }

$parsed = $null
$parseError = $null
try {
    if ($stdoutText) {
        $parsed = $stdoutText | ConvertFrom-Json -ErrorAction Stop
    }
} catch {
    $parseError = $_.Exception.Message
}

@{
    Success      = ($runResult.Status -eq 'Succeeded')
    Output       = $parsed
    RawOutput    = $stdoutText
    StdErr       = $stderrText
    ParseError   = $parseError
    TimestampUtc = (Get-Date).ToUniversalTime().ToString('o')
}
