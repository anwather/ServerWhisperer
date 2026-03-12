$ErrorActionPreference = 'Stop'

# Import Az modules — managed dependencies may still be installing on first cold start
$modules = @(
    'Az.Accounts',
    'Az.Compute',
    'Az.ResourceGraph',
    'Az.Monitor',
    'Az.KeyVault',
    'Az.Storage'
)

$allLoaded = $true
foreach ($module in $modules) {
    try {
        Import-Module $module -ErrorAction Stop
    } catch {
        Write-Warning "Module $module not yet available: $($_.Exception.Message)"
        $allLoaded = $false
    }
}

if ($allLoaded) {
    $ctx = Get-AzContext
    if (-not $ctx -or -not $ctx.Account) {
        try {
            Connect-AzAccount -Identity -ErrorAction Stop | Out-Null
            Write-Host "Connected to Azure via Managed Identity"
        } catch {
            Write-Warning "Managed identity auth failed: $($_.Exception.Message)"
        }
    } else {
        Write-Host "Already connected as $($ctx.Account.Id)"
    }
} else {
    Write-Warning "Not all Az modules loaded. Managed dependencies may still be installing."
}

# Helper function available to all functions
function Ensure-AzConnected {
    $ctx = Get-AzContext
    if (-not $ctx -or -not $ctx.Account) {
        Connect-AzAccount -Identity -ErrorAction Stop | Out-Null
    }
}
