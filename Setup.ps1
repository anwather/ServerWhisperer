################################################################################
# SERVERWHISPERER Setup Script
################################################################################
# 
# This script removes development files you don't need as an end user.
# These files are used by the development team but aren't required for
# running investigations with "gh copilot".
#
# Safe to run multiple times - checks before removing.
# Does NOT use git commands - just deletes files/folders.
#
################################################################################

Write-Host ""
Write-Host "🔧 SERVERWHISPERER Setup" -ForegroundColor Cyan
Write-Host "══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "This script removes development artifacts you don't need." -ForegroundColor Yellow
Write-Host "It keeps all the important files for investigating servers." -ForegroundColor Yellow
Write-Host ""

# Track what we remove
$removedItems = @()
$keptItems = @(
    ".github\copilot-instructions.md",
    ".github\agents\SERVERWHISPERER.md",
    ".github\skills\win-investigate.md",
    "skills\ (all diagnostic skills)",
    "src\ (PowerShell diagnostic scripts)",
    ".copilot\ (MCP configuration)",
    "README.md",
    ".gitignore"
)

# Items to remove
$itemsToRemove = @(
    @{ Path = ".squad"; Type = "Folder"; Description = "AI team development files" },
    @{ Path = ".gitattributes"; Type = "File"; Description = "Squad merge configuration" },
    @{ Path = ".github\agents\squad.agent.md"; Type = "File"; Description = "Squad agent definition" },
    @{ Path = ".github\workflows\squad-heartbeat.yml"; Type = "File"; Description = "Squad heartbeat workflow" },
    @{ Path = ".github\workflows\squad-issue-assign.yml"; Type = "File"; Description = "Squad issue assignment workflow" },
    @{ Path = ".github\workflows\squad-triage.yml"; Type = "File"; Description = "Squad triage workflow" },
    @{ Path = ".github\workflows\sync-squad-labels.yml"; Type = "File"; Description = "Squad label sync workflow" },
    @{ Path = ".github\workflows\pages.yml"; Type = "File"; Description = "GitHub Pages workflow" },
    @{ Path = "docs"; Type = "Folder"; Description = "GitHub Pages source (read docs online at https://anwather.github.io/ServerWhisperer/)" }
)

Write-Host "Removing unnecessary files..." -ForegroundColor Green
Write-Host ""

foreach ($item in $itemsToRemove) {
    $fullPath = Join-Path $PSScriptRoot $item.Path
    
    if (Test-Path $fullPath) {
        try {
            if ($item.Type -eq "Folder") {
                Remove-Item -Path $fullPath -Recurse -Force -ErrorAction Stop
                Write-Host "  ✓ Removed folder: $($item.Path)" -ForegroundColor Gray
            } else {
                Remove-Item -Path $fullPath -Force -ErrorAction Stop
                Write-Host "  ✓ Removed file: $($item.Path)" -ForegroundColor Gray
            }
            $removedItems += "$($item.Path) - $($item.Description)"
        }
        catch {
            Write-Host "  ✗ Failed to remove $($item.Path): $_" -ForegroundColor Red
        }
    } else {
        Write-Host "  · Skipped (not found): $($item.Path)" -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host "══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "✓ Setup Complete!" -ForegroundColor Green
Write-Host "══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Summary
if ($removedItems.Count -gt 0) {
    Write-Host "REMOVED ($($removedItems.Count) items):" -ForegroundColor Yellow
    foreach ($item in $removedItems) {
        Write-Host "  - $item" -ForegroundColor Gray
    }
    Write-Host ""
}

Write-Host "KEPT (everything you need):" -ForegroundColor Green
foreach ($item in $keptItems) {
    Write-Host "  ✓ $item" -ForegroundColor Gray
}
Write-Host ""

Write-Host "══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "📚 Next Steps:" -ForegroundColor Cyan
Write-Host "══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Set up server credentials (if needed):" -ForegroundColor White
Write-Host "   New-Item -ItemType Directory -Path `"`$HOME\.serverwhisperer`" -Force" -ForegroundColor Gray
Write-Host "   Get-Credential | Export-Clixml -Path `"`$HOME\.serverwhisperer\credentials.xml`"" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Start investigating your servers:" -ForegroundColor White
Write-Host "   gh copilot" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Ask a question like:" -ForegroundColor White
Write-Host "   `"What is going on with server01?`"" -ForegroundColor Gray
Write-Host ""
Write-Host "📖 Full documentation: https://anwather.github.io/ServerWhisperer/" -ForegroundColor Cyan
Write-Host ""
