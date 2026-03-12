[CmdletBinding()]
param(
    [int]$DurationMinutes = 10,
    [int]$CoreCount = (Get-CimInstance Win32_Processor | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum
)

$ErrorActionPreference = 'Stop'

if ($CoreCount -lt 1) {
    throw 'CoreCount must be at least 1.'
}

Write-Host "🔥 Starting CPU stress on $CoreCount cores for $DurationMinutes minutes..."

$endTime = (Get-Date).AddMinutes($DurationMinutes)
$jobs = 1..$CoreCount | ForEach-Object {
    Start-Job -ScriptBlock {
        param($end)
        while ((Get-Date) -lt $end) {
            [Math]::Sqrt([Math]::PI) | Out-Null
        }
    } -ArgumentList $endTime
}

Write-Host '⏳ Stress running. Alert should fire within 5-7 minutes.'
Write-Host '   Press Ctrl+C to stop early, or wait for auto-stop.'

$jobs | Wait-Job -Timeout ($DurationMinutes * 60 + 30) | Out-Null
$jobs | Remove-Job -Force

Write-Host '✅ CPU stress complete.'
