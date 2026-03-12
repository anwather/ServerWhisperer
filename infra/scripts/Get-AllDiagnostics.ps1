param(
    [string]$AlertType = 'Unknown',
    [int]$MaxBytes = 3800
)

$ErrorActionPreference = 'Stop'

function Limit-String {
    param(
        [string]$Value,
        [int]$MaxLength = 200
    )
    if (-not $Value) { return $Value }
    if ($Value.Length -le $MaxLength) { return $Value }
    return $Value.Substring(0, $MaxLength)
}

function Get-Overview {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $cs = Get-CimInstance -ClassName Win32_ComputerSystem
    $uptime = (Get-Date) - $os.LastBootUpTime
    [PSCustomObject]@{
        Hostname     = $cs.Name
        OSName       = $os.Caption
        OSVersion    = $os.Version
        LastBootTime = $os.LastBootUpTime
        UptimeDays   = [Math]::Round($uptime.TotalDays, 2)
        TotalRAM_GB  = [Math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
    }
}

function Get-Performance {
    $cpu = $null
    try {
        $cpu = [Math]::Round((Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples[0].CookedValue, 2)
    } catch {
        $cpu = $null
    }

    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $totalMemGB = [Math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $freeMemGB = [Math]::Round($os.FreePhysicalMemory / 1MB, 2)

    [PSCustomObject]@{
        CPU_PercentUsed    = $cpu
        Memory_TotalGB     = $totalMemGB
        Memory_FreeGB      = $freeMemGB
        Memory_PercentUsed = if ($totalMemGB -gt 0) { [Math]::Round((1 - ($freeMemGB / $totalMemGB)) * 100, 2) } else { $null }
    }
}

function Get-Disks {
    Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
        [PSCustomObject]@{
            Drive       = $_.DeviceID
            SizeGB      = [Math]::Round($_.Size / 1GB, 2)
            FreeGB      = [Math]::Round($_.FreeSpace / 1GB, 2)
            PercentFree = if ($_.Size -gt 0) { [Math]::Round(($_.FreeSpace / $_.Size) * 100, 2) } else { 0 }
        }
    }
}

function Get-Services {
    $services = Get-CimInstance Win32_Service
    $services | Where-Object { $_.StartMode -eq 'Auto' -and $_.State -ne 'Running' } |
        Select-Object -First 20 -Property Name, DisplayName, State, StartMode
}

function Get-Processes {
    Get-CimInstance Win32_Process | ForEach-Object {
        [PSCustomObject]@{
            ProcessId    = $_.ProcessId
            Name         = $_.Name
            WorkingSetMB = [Math]::Round($_.WorkingSetSize / 1MB, 2)
            ThreadCount  = $_.ThreadCount
        }
    } | Sort-Object WorkingSetMB -Descending | Select-Object -First 10
}

function Get-Events {
    $startTime = (Get-Date).AddDays(-1)
    Get-WinEvent -FilterHashtable @{ LogName = 'System'; Level = 1, 2; StartTime = $startTime } -MaxEvents 20 -ErrorAction SilentlyContinue |
        ForEach-Object {
            [PSCustomObject]@{
                TimeCreated = $_.TimeCreated
                Level       = if ($_.Level -eq 1) { 'Critical' } else { 'Error' }
                EventId     = $_.Id
                Source      = $_.ProviderName
                Message     = Limit-String -Value ($_.Message.Split("`n")[0]) -MaxLength 200
            }
        }
}

$report = [ordered]@{
    AlertType   = $AlertType
    CollectedAt = (Get-Date).ToUniversalTime().ToString('o')
    Overview    = Get-Overview
    Performance = Get-Performance
    Disks       = Get-Disks
    Services    = Get-Services
    Processes   = Get-Processes
    Events      = Get-Events
    Truncated   = $false
}

$json = $report | ConvertTo-Json -Depth 6 -Compress

if ($json.Length -gt $MaxBytes) {
    $report.Services = $report.Services | Select-Object -First 10
    $report.Processes = $report.Processes | Select-Object -First 5
    $report.Events = $report.Events | Select-Object -First 10
    $report.Truncated = $true
    $json = $report | ConvertTo-Json -Depth 6 -Compress
}

if ($json.Length -gt $MaxBytes) {
    $report.Events = $report.Events | Select-Object -First 5
    $report.Truncated = $true
    $json = $report | ConvertTo-Json -Depth 6 -Compress
}

if ($json.Length -gt $MaxBytes) {
    $report.Events = @()
    $report.Services = @()
    $report.Processes = @()
    $report.Truncated = $true
    $report.TruncationNote = 'Diagnostics trimmed to meet Run Command output limit.'
    $json = $report | ConvertTo-Json -Depth 6 -Compress
}

Write-Output $json
