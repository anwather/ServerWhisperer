$ErrorActionPreference = 'Stop'

$modules = @(
    'Az.Accounts',
    'Az.Compute',
    'Az.ResourceGraph',
    'Az.Monitor',
    'Az.KeyVault',
    'Az.Storage'
)

foreach ($module in $modules) {
    Import-Module $module -ErrorAction Stop
}

try {
    $null = Get-AzContext -ErrorAction Stop
} catch {
    try {
        Connect-AzAccount -Identity -ErrorAction Stop | Out-Null
    } catch {
        Write-Error "Managed identity authentication failed. Ensure the Function App has a system-assigned identity. $($_.Exception.Message)"
        throw
    }
}
