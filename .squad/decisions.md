# Squad Decisions

## Active Decisions

### 1. Architecture Decision: win-investigator Structure
**Date:** 2026-03-10  
**Architect:** Scully  
**Status:** Implemented

**Summary:** Skill-based modular architecture with single orchestrator skill (`win-investigate`). Diagnostic functions modularized under `src/diagnostics/`, each returning structured PSObjects. Credential flow: passed as parameters, never stored.

**Diagnostic Areas:** Processes, Performance, Disks, Services, Apps, Network, Roles

**Key Patterns:**
- Functions accept `ComputerName` and `Credential` parameters
- Return structured PSObjects (not formatted text)
- Intelligence layer (Copilot agent) + Execution layer (PowerShell skill)

**Alternatives Rejected:** Agent-based architecture (too stateful), instructions-only (no encapsulation), multiple individual skills (too granular), standalone module (not primary deliverable)

**Open Questions:**
- Concurrent vs sequential server processing?
- PSSession reuse across questions vs create/destroy per request?
- Default output format preference?

**Implications:**
- Mulder: Implement diagnostic functions independently with structured returns
- Doggett: Document skill invocation and user examples
- Skinner: Test each diagnostic area, credentials flows, partial failures
- Future: Easy to extend with new diagnostic areas or export as module

---

### 2. Decision: Copilot Instruction Framework for Win-Investigator
**Author:** Doggett  
**Date:** 2026-03-09  
**Status:** Implemented

**Summary:** Three-layer documentation structure established:

1. **`.github/copilot-instructions.md`** — Main agent instructions (comprehensive behavior reference)
2. **`.github/agents/win-investigator.md`** — Agent definition (reference card)
3. **`README.md`** — User-facing documentation (tutorial-style)

**Workflow:** Parse → Connect → Diagnose → Report

**Patterns Applied:**
- Status indicators: 🟢 🟡 🔴 for severity
- Error handling with suggested next steps for each error type
- Escalation guidance for when to stop and ask for help
- Skills integration: reference by name, don't implement

**Reasoning:** Separates concerns — instructions (agent behavior), definition (what agent is), docs (user interaction)

---

### 3. Decision: Complete Beginner Documentation Rewrite

**Author:** Doggett (DevRel/Technical Writer)  
**Date:** 2026-03-10  
**Status:** Implemented  
**Requested by:** Anthony Watherston

**Summary:** Complete rewrite of 5 key documentation files to be beginner-centric:
- README.md — Quick Start (5-Minute Walkthrough)
- docs/index.md — Landing Page (Value Proposition)
- docs/getting-started.md — Complete Onboarding (Step 0-5 with exact commands)
- docs/usage.md — Beginner Context (Simple Examples, FAQ)
- docs/troubleshooting.md — Beginner-First Organization

**Key Patterns Applied:**
- Every instruction testable with expected output shown
- Exact commands as copy/paste blocks
- "What You'll Need" checklists
- Beginner issues first in troubleshooting
- FAQ section addressing common hesitations

**Target Audience:** Complete beginners with zero Copilot CLI experience.

**Testing Notes:** Documentation geared toward:
1. First time: Read README → Follow getting-started step-by-step
2. Ready to ask: Read usage.md → Run first investigation
3. Something breaks: Check troubleshooting (beginner issues first)

---

### 4. Decision: GitHub Pages Documentation Site

**Author:** Doggett  
**Date:** 2026-03-10  
**Status:** Implemented

**Summary:** Built GitHub Pages documentation site using Jekyll with `just-the-docs` theme.
- **Theme:** just-the-docs (via `remote_theme` for GitHub Pages compatibility)
- **Color scheme:** Dark — matches terminal/CLI nature
- **Deployment:** `.github/workflows/pages.yml` on `docs/**` changes
- **URL:** https://anwather.github.io/win-investigator

**Reasoning:** `just-the-docs` is the most popular Jekyll docs theme with built-in search and excellent navigation. `remote_theme` avoids Ruby gems while staying GitHub Pages compatible.

**Implications:**
- Documentation site is canonical public-facing docs
- README.md remains quick-start entry point
- New skills should be added to docs when created

---

### 5. Decision: Azure VM Connectivity Skill

**Author:** Mulder  
**Date:** 2026-03-10  
**Status:** Implemented

**Summary:** Created dedicated `skills/azure-connectivity/SKILL.md` for PowerShell remoting to Azure VMs over public IP.

**Problem:** Win-investigator targets may include Azure VMs accessed via public IP. Existing connectivity skill assumes domain-joined on-prem servers, failing for Azure scenarios.

**Decision:**
- **New skill** (`azure-connectivity`) handles full Azure VM remoting lifecycle
- **Existing connectivity skill** updated with Azure target detection
- **Copilot-instructions** updated with Azure credential rules and workflow guidance

**Key Technical Choices:**
1. HTTPS only for public IP
2. Explicit credentials mandatory (Kerberos doesn't work without domain trust)
3. Self-signed cert support via `-SkipCACheck -SkipCNCheck`
4. Detection heuristic — public IP or *.cloudapp.azure.com triggers Azure path
5. Alternative approaches documented (Azure Bastion, Serial Console, Run Command)

---

### 6. Decision: File-Based Encrypted Credential Storage

**Author:** Mulder (Backend/PowerShell Dev)  
**Date:** 2026-03-10  
**Status:** Implemented  
**Requested by:** Anthony Watherston

**Summary:** Implement file-based encrypted credential storage using PowerShell's Export-Clixml / Import-Clixml pattern.

**User Setup (One-Time):**
```powershell
New-Item -ItemType Directory -Path "$HOME\.wininvestigator" -Force
Get-Credential | Export-Clixml -Path "$HOME\.wininvestigator\credentials.xml"
```

**Agent Runtime:**
```powershell
$credPath = Join-Path $HOME ".wininvestigator" "credentials.xml"
if (Test-Path $credPath) {
    $credential = Import-Clixml -Path $credPath
}
```

**Benefits:**
- DPAPI encryption — file contains encrypted data, not plain text
- Tied to user + machine — only the creating user on the creating machine can decrypt
- Standard PowerShell pattern — used in enterprise automation for years
- Passwords never in chat — user creates file outside Copilot CLI
- Persistent — credentials persist between sessions

**Limitations:**
- Not portable — credential files cannot be moved between machines
- Per-machine setup — users must create credential files on each machine
- File management — users must remember to update if passwords change

**Implementation:** 14 files updated including core instructions, skills, documentation, and .gitignore.

**User Impact Before/After:**
- Before: Re-enter credentials every new PowerShell session
- After: Create credential file ONE TIME per machine; agent loads automatically

---

### 7. Decision: HTTPS-Only Connection Pattern (Universal)

**Author:** Mulder (Backend/PowerShell)  
**Date:** 2026-03-10  
**Directive from:** Anthony Watherston  
**Status:** Implemented

**Summary:** All PowerShell remoting connections use:
- **HTTPS on port 5986** — the ONLY transport
- **`-SkipCACheck -SkipCNCheck`** on all PSSessionOption and CimSessionOption
- **No TrustedHosts modification** — Skip flags eliminate this requirement
- **IP addresses supported directly** — connect to 10.0.0.5 with no extra setup

**Rationale:**
1. **Simplicity** — One connection pattern for all scenarios (domain, workgroup, Azure, IP, hostname)
2. **Security** — HTTPS encrypts all traffic; no accidental HTTP exposure
3. **No client modification** — SkipCA/SkipCN are session-scoped
4. **IP address support** — SkipCNCheck enables IP connections without TrustedHosts

**Standard Patterns:**
- PSSession: New-PSSessionOption with -SkipCACheck -SkipCNCheck
- CIM Session: New-CimSessionOption -UseSsl -SkipCACheck -SkipCNCheck
- Test: Test-WSMan -UseSSL

**Implications:**
- All agents: Follow this pattern in any new skill or code
- Skinner: Test scenarios should target port 5986 with HTTPS
- Target servers: Must have WinRM HTTPS listener on port 5986

---

### 8. Decision: Parallel Job-Based Diagnostic Execution

**Author:** Mulder (Backend Dev)  
**Date:** 2026-03-10  
**Status:** Implemented

**Context:** Long-running diagnostics were blocking sequential execution:
- Event Logs: 15-60 seconds
- Performance Counters: 10-30 seconds
- Installed Apps: 30-120+ seconds
- Roles/Features: 10-30 seconds

**Decision:** Implement parallel job-based execution using PowerShell background jobs. All diagnostics launch simultaneously; results collected as they complete.

**Performance Impact:**
- Sequential (before): ~120-180 seconds for full investigation
- Parallel (after): ~30-60 seconds for full investigation
- Improvement: 60-75% reduction in total wait time

**Pattern:** Fire All, Collect As Complete
1. Establish connection params once
2. Launch each diagnostic as background job
3. Collect results as they complete (120s timeout per job)
4. Clean up all jobs after results collected

**Diagnostic Speed Classifications:**
- **FAST** (2-5s): Overview, Disk Storage
- **MODERATE** (3-15s): Performance, Processes, Services, Network
- **SLOW** (15-60s): Event Logs
- **VERY SLOW** (30-120s): Installed Apps (Win32_Product)

**When to Use Parallel Execution:**
- Use: Full investigations, Multiple diagnostic areas, Generic health checks
- Don't use: Single specific concern, One metric

**Implementation:** 5 files updated; speed annotations added to all embedded skills.

**New Skills Added:**
- Installed Apps Skill — Registry-based method (FAST 5-10s) instead of Win32_Product (VERY SLOW)
- Roles & Features Skill — Get-WindowsFeature enumeration (SLOW 10-30s)

---

### 9. Decision: Copilot CLI Plugin Manifest for Distribution

**Author:** Mulder  
**Date:** 2026-03-10  
**Status:** Implemented

**Summary:** Added `.github/plugin/plugin.json` to enable installation via `/plugin install anwather/ServerWhisperer`.

**Manifest Structure:**
- **Location:** `.github/plugin/plugin.json`
- **Agents:** References `.github/agents/server-whisperer.md`
- **Skills:** References all 11 skill directories under `skills/`
- **Version:** Starts at 1.0.0 (functional)

**Reasoning:** Single manifest file is the standard mechanism for Copilot CLI plugin discovery and installation. All paths are repo-root-relative for correct resolution post-install.

**Implications:**
- Doggett: May want to add `/plugin install` instructions to docs
- Scully: New skill directories must be registered in plugin.json
- Skinner: Plugin install flow should be tested end-to-end

**Alternatives Rejected:**
- No manifest / manual setup: Poor UX, users need to clone and configure manually
- Separate manifest per skill: Too granular; plugin is a cohesive product

---

### 10. User Directives: Azure VM Support

**By:** Anthony Watherston (via Copilot)  
**Date:** 2026-03-09T22:55:00Z

**Directive 1:** Targets may include Azure VMs via public IP address. Ensure instructions/checks for remoting enabled and credentials configured correctly for Azure scenarios.

**Rationale:** Azure VM connectivity requires additional setup (NSG rules for WinRM ports, HTTPS transport, TrustedHosts config, certificate-based auth). Expands scope beyond domain-joined on-prem servers.

**Decision:** Implemented via Decision #5 (Azure VM Connectivity Skill) and Decision #7 (HTTPS-Only Connection Pattern).

---

**By:** Anthony Watherston (via Copilot)  
**Date:** 2026-03-09T22:58:00Z

**Directive 2:** Connections should support IP addresses directly. Do NOT modify TrustedHosts — instead use -SkipCACheck and -SkipCNCheck (user said -SkipPublisherChecks but meant -SkipCNCheck) on session options. All connections via HTTPS on port 5986.

**Rationale:** Simpler setup, no client-side config changes needed. HTTPS on 5986 is standard for non-domain-joined and Azure VM scenarios.

**Decision:** Implemented via Decision #7 (HTTPS-Only Connection Pattern).

---

### 11. Decision: Pre-Created $credential Variable Pattern

**Author:** Mulder (Backend/PowerShell Dev)  
**Date:** 2026-03-10  
**Status:** Implemented  
**Requested by:** Anthony Watherston

**Context:** Copilot CLI runs in non-interactive mode and cannot reliably pop up GUI dialogs. Previous Get-Credential approach didn't work well.

**Decision:** Users create `$credential` variable in PowerShell session BEFORE running Copilot CLI (or when prompted).

**User Workflow:**
1. User opens PowerShell terminal
2. User runs: `$credential = Get-Credential`
3. Secure Windows dialog appears
4. User enters username/password in dialog
5. User starts `gh copilot`
6. Agent detects and uses pre-created `$credential` variable

**Agent Pattern:**
```powershell
if (-not $credential) {
    Write-Host "⚠️ I need credentials to connect to $ServerName."
    Write-Host "Please run this in your PowerShell session:"
    Write-Host "  $credential = Get-Credential"
    return
}
```

**Key Principles:**
1. NEVER run Get-Credential inline
2. Check for variable first
3. Guide users clearly
4. Passwords never in chat
5. Default still works (current user identity when no $credential exists)

**Files Updated:** 11 total (core instructions, skills, documentation, history)

---

### 12. Decision: Secure Credential Handling for Win-Investigator

**Author:** Mulder (Backend/PowerShell Dev)  
**Date:** 2026-03-09  
**Status:** Implemented  
**Requested by:** Anthony Watherston

**Problem:** Risk that users could type passwords directly in Copilot CLI chat, exposing them in plain text in conversation history.

**Decision:** Implement comprehensive secure credential handling across ALL files.

**Primary Method:** Get-Credential (Secure GUI Dialog)
```powershell
$cred = Get-Credential -Message "Enter credentials for ServerName"
$session = New-PSSession -ComputerName $ServerName -Credential $cred -UseSSL -Port 5986
```

**Alternative Method:** Windows Credential Manager
```powershell
$cred = Get-StoredCredential -Target "server01"
```

**Default:** Current User (No Prompt) — for domain-joined machines accessing domain servers.

**Security Principles:**
1. Passwords are NEVER typed in Copilot CLI chat
2. Get-Credential opens Windows GUI dialog for secure entry
3. Passwords never visible in conversation history
4. PSCredential objects never logged or displayed
5. Credentials used once and discarded
6. Pre-stored credentials use Windows Credential Manager

**Files Updated:** 10 total

**Patterns Established:**
- Correct (Agent): Use Get-Credential before passing credential to skills
- Correct (Skills): Accept $Credential as parameter; use conditionally
- Never: Ask for passwords in chat, use plain text ConvertTo-SecureString, display PSCredential objects

---

### 13. Decision: Automatic Skill Loading via Embedded Code

**Author:** Mulder (Backend/PowerShell Dev)  
**Date:** 2026-03-09T23:40Z  
**Status:** Implemented  
**Requested by:** Anthony Watherston

**Problem:** Diagnostic skills in `skills/*/SKILL.md` are NOT automatically loaded when users run `gh copilot`. Copilot CLI only automatically loads `.github/copilot-instructions.md`. Users would need additional setup steps.

**Decision:** Embed all diagnostic skill PowerShell code directly into `.github/copilot-instructions.md`.

**Implementation:**
1. Created "Diagnostic Skills Reference" section in copilot-instructions.md
2. Embedded 9 skills (only runnable PowerShell code, no explanatory prose)
3. Maintained source files in `skills/*/SKILL.md` as source of truth
4. Fixed path references from `.squad/skills/` to `skills/`

**Embedded Skills:** connectivity, server-overview, processes, performance, disk-storage, services, network, event-logs, azure-connectivity

**Benefits:**
1. Zero setup required — Clone repo → run `gh copilot` → everything works
2. Performance — All skill code loaded once at session start
3. Reliability — No file path issues, no "skill not found" errors
4. Clear ownership — copilot-instructions.md is runtime reference; skills/ is source of truth

**Maintenance Pattern:**
1. Edit source file: `skills/<skill-name>/SKILL.md`
2. Extract updated PowerShell code
3. Update corresponding section in `.github/copilot-instructions.md`
4. Test by running `gh copilot`

**Trade-offs:**
- **Pro:** Automatic loading, fast execution, simple architecture
- **Con:** Duplication (skill code in two places), manual sync required, larger instructions file (~800 lines)

**Mitigation:** Clear documentation on maintenance pattern; consider automation script in future.

---

## Governance

- All meaningful changes require team consensus
- Document architectural decisions here
- Keep history focused on work, decisions focused on direction
