# Project Context

- **Owner:** Anthony Watherston
- **Project:** win-investigator — AI-driven Windows Server troubleshooting via PowerShell remoting
- **Stack:** PowerShell, Windows Server, Copilot CLI (agents/skills/instructions)
- **Created:** 2026-03-09

## Learnings

<!-- Append new learnings below. Each entry is something lasting about the project. -->

### 2026-03-12: Validation Script Patterns for Azure Infrastructure

**Context:** Created `Validate-Deployment.ps1` and `Test-EndToEnd.ps1` for Phase 1 demo infrastructure validation.

**Validation patterns implemented:**

1. **Layered validation approach:**
   - Pre-deployment validation (smoke tests) before attempting end-to-end flow
   - Fail fast on missing prerequisites
   - Clear error messages with remediation steps for each failure

2. **Resource verification patterns:**
   - Check existence first, then configuration, then connectivity
   - Use `-ErrorAction SilentlyContinue` when resource might not exist, handle gracefully
   - For VMs: Check existence → check power state → check managed identity → test Run Command
   - For Function Apps: Check existence → check state → verify app settings → check RBAC

3. **Common failure modes identified:**
   - **Placeholder values in app settings** — Common when Foundry agent isn't created yet. Check for 'PLACEHOLDER', 'your-', 'example' patterns.
   - **VM agent not ready** — Invoke-AzVMRunCommand fails if VM guest agent isn't running. Always check VM power state first.
   - **Missing RBAC assignments** — Function App MI needs Virtual Machine Contributor to use Run Command. Key Vault access policies needed for secrets.
   - **Alert evaluation timing** — Alert rules evaluate every 1-5 minutes. End-to-end tests must account for this delay.
   - **Storage container access** — MI needs Storage Blob Data Contributor. Public access is disabled by default.

4. **Testing timing patterns:**
   - Run Command: 30-60s per execution (includes Azure fabric routing)
   - Alert evaluation: 1-5 minutes (configurable in alert rule)
   - Durable Function orchestration: 30-120s depending on diagnostic scope
   - Full end-to-end: Plan for 10-15 minutes minimum

5. **Output format for operations scripts:**
   - Use emoji status indicators consistently: 🟢 🟡 🔴 for severity, ✅ ❌ for pass/fail
   - Show elapsed time with each progress message: `[+30.5s]`
   - Print recommendations immediately under failures, not at the end
   - Exit codes: 0 = success, 1 = failure (enables scripting/CI integration)

6. **Foundry agent integration validation:**
   - Check both FOUNDRY_ENDPOINT and FOUNDRY_AGENT_ID app settings
   - Agent ID is set post-deployment (not in Bicep), so script must handle "not yet configured" gracefully
   - Provide exact command to run: `infra/scripts/create-foundry-agent.ps1 -ResourceGroup <rg>`

7. **Teams webhook testing:**
   - Use Adaptive Card format (not MessageCard — deprecated)
   - Store webhook URL in Key Vault, never in plain text
   - Make webhook test optional (via switch) to avoid spamming during repeated test runs
   - Test card should be minimal and clearly labeled as "test"

**Reusable patterns for future validation scripts:**

```powershell
# Pattern 1: Check resource existence with actionable error
$resource = Get-AzResource -Name $name -ResourceType $type -ErrorAction SilentlyContinue
if (-not $resource) {
    Add-CheckResult -Passed $false -Message "Not found" `
        -Recommendation "Run: az deployment group create -f path/to/template.bicep"
}

# Pattern 2: Check configuration values for placeholders
$setting = $appSettings | Where-Object { $_.Name -eq 'KEY' }
$isValid = $setting -and $setting.Value -and $setting.Value -notmatch 'PLACEHOLDER|your-|example'

# Pattern 3: Time-boxed polling with progress updates
$startTime = Get-Date
$timeout = 300  # 5 minutes
while (((Get-Date) - $startTime).TotalSeconds -lt $timeout) {
    $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 0)
    Write-Verbose "[$elapsed/$timeout seconds] Checking..."
    
    # ... check condition ...
    if ($conditionMet) { break }
    
    Start-Sleep -Seconds 30
}

# Pattern 4: Structured result collection
$checks = @()
function Add-CheckResult {
    $script:checks += [PSCustomObject]@{ Name = $name; Passed = $passed; Message = $msg }
}
```

**Testing strategy for infrastructure:**
- Smoke tests (Validate-Deployment.ps1) run in ~2-3 minutes — fast feedback
- End-to-end tests (Test-EndToEnd.ps1) run in ~10-15 minutes — full integration validation
- Run smoke tests on every deployment, E2E tests on demand or in CI pipeline
