[CmdletBinding()]
param(
    [string]$DriveLetter = 'C',
    [int]$TargetUsagePercent = 85,
    [int]$ChunkSizeMB = 512,
    [switch]$Cleanup
)

$ErrorActionPreference = 'Stop'
$targetRoot = "${DriveLetter}:\Temp\DiskPressure"

function Get-DiskUsage {
    param([string]$Letter)
    $drive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='${Letter}:'"
    if (-not $drive) {
        throw "Drive ${Letter}: not found."
    }
    $percentUsed = [math]::Round((1 - ($drive.FreeSpace / $drive.Size)) * 100, 2)
    [PSCustomObject]@{
        SizeGB = [math]::Round($drive.Size / 1GB, 2)
        FreeGB = [math]::Round($drive.FreeSpace / 1GB, 2)
        PercentUsed = $percentUsed
    }
}

if ($Cleanup) {
    if (Test-Path $targetRoot) {
        Remove-Item -Path $targetRoot -Recurse -Force
    }
    Write-Host "🧹 Cleanup complete for $targetRoot."
    return
}

New-Item -ItemType Directory -Path $targetRoot -Force | Out-Null

$usage = Get-DiskUsage -Letter $DriveLetter
Write-Host "Starting disk pressure on ${DriveLetter}: (Used: $($usage.PercentUsed)%). Target: $TargetUsagePercent%."

$index = 1
while ($usage.PercentUsed -lt $TargetUsagePercent) {
    $filePath = Join-Path $targetRoot ("fill_{0}.bin" -f $index)
    $bytes = $ChunkSizeMB * 1MB
    fsutil file createnew $filePath $bytes | Out-Null

    $usage = Get-DiskUsage -Letter $DriveLetter
    Write-Host "Filled $filePath ($ChunkSizeMB MB). Used: $($usage.PercentUsed)% | Free: $($usage.FreeGB) GB."

    if ($usage.FreeGB -lt 0.5) {
        Write-Warning 'Less than 0.5 GB free remaining, stopping to avoid disk exhaustion.'
        break
    }

    $index++
}

Write-Host "✅ Disk pressure simulation complete. Current usage: $($usage.PercentUsed)%."
