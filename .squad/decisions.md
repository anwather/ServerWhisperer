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

### 14. Decision: Alert-to-Diagnosis Automation Pipeline

**Author:** Scully (Lead/Architect)  
**Date:** 2026-03-10  
**Status:** Proposed  
**Requested by:** Anthony Watherston  

**Summary:** End-to-end automation pipeline: Azure Monitor alert → AI root cause diagnosis.

**Architecture:**
- **Ingestion:** Azure Monitor → Action Groups → Event Grid (durable routing, fan-out, severity filtering)
- **Orchestration:** Azure Durable Functions (PowerShell) — code-first, fan-out/fan-in for parallel diagnostics
- **Hybrid Execution:**
  - Azure VMs: `Invoke-AzVMRunCommand` (no WinRM, Managed Identity, through fabric)
  - On-prem: Azure Automation Hybrid Runbook Worker → WinRM HTTPS/5986
- **AI Analysis:** Azure OpenAI GPT-4o with structured diagnostic data → root cause + remediation
- **Reporting:** Teams Adaptive Cards (severity-routed), Blob Storage (full reports), Log Analytics (trending)
- **Security:** Managed Identity everywhere, zero stored credentials in pipeline

**Key Design Decisions:**
- Durable Functions over Logic Apps: PowerShell-native, testable, fan-out/fan-in matches existing parallel job pattern
- Event Grid over direct webhook: retry, fan-out, filtering, dead-letter
- Run Command needs JSON serialization wrapper (returns text, 4KB stdout limit)
- Existing `src/diagnostics/` scripts reused in both interactive and automated paths
- Phased implementation: MVP (Azure VMs) → Hybrid (on-prem) → Intelligence (RAG, auto-remediation) → Observability

**Cost Estimate:** ~$25-35/month for 100 investigations (Consumption plan, event-driven, no idle cost)

**Open Questions:**
- Bundle diagnostics into single Run Command per VM vs separate invocations?
- Auto-remediation scope — which actions are safe without human approval?
- Consumption vs Premium Function plan (cold start tradeoff)?
- On-prem network topology — VPN/ExpressRoute available or Hybrid Worker only?

---

### 15. Decision: Pivot Intelligence Layer to Microsoft Foundry Agent

**Author:** Scully (Lead/Architect)  
**Date:** 2026-03-12  
**Status:** Proposed  
**Requested by:** Anthony Watherston  
**Supersedes:** Section 3.5 of Decision #14 (raw Azure OpenAI chat completions)

**Context:** The v1 automation pipeline architecture used raw Azure OpenAI chat completion calls for AI analysis. This works but is stateless — no memory of past investigations, no tool-calling during analysis, no knowledge base.

**Decision:** Replace raw Azure OpenAI chat completion calls with a **Microsoft Foundry Agent** (`serverwhisperer-diagnostician`) that provides:

1. **Persistent agent definition** — system prompt, model, and behavior configured once (not per-call)
2. **Tool definitions** — the agent can call functions during analysis:
   - `query_resource_graph` — VM metadata, tags, size, related resources
   - `check_vm_power_state` — power state + recent restart history
   - `query_activity_log` — control-plane events (deallocations, maintenance, Spot evictions)
3. **Knowledge base (RAG)** — Azure AI Search index over past investigation reports, enabling the agent to detect recurring patterns and reference historical context
4. **Conversation threads** — stateful investigation context per alert

The Durable Function remains the orchestrator: it collects diagnostics via Run Command, then creates a thread with the Foundry agent, sends diagnostic data, handles any tool call requests, and retrieves the analysis.

**Also Decided: Demo Infrastructure (Bicep IaC)**

Phase 1 is now a **deployable demo**, not just an architecture document. The Bicep IaC deploys:

- Target Windows VM (Server 2022, WinRM HTTPS via CustomScriptExtension)
- Azure Monitor alert rules (CPU, disk, memory)
- Action Group → Event Grid → Durable Function (Flex Consumption)
- AI Foundry project + agent + model deployment
- Azure AI Search (knowledge base index)
- Storage account, Key Vault
- Load simulation scripts

One deployment command + two post-deploy scripts → stress VM → watch diagnosis arrive in Teams.

**Rationale:**

| Factor | Raw OpenAI | Foundry Agent |
|--------|-----------|---------------|
| Knowledge base (RAG) | Build from scratch | Native AI Search integration |
| Tool calling | Manual implementation | Built-in, agent-managed |
| Historical memory | None | Via knowledge base index |
| System prompt | Repeated per call | Configured once on agent |
| Conversation state | Stateless | Persistent threads |
| Observability | DIY logging | Built-in Foundry metrics |

The agent abstraction is the right level. We'd end up building half of what Foundry provides if we stayed on raw OpenAI.

**Implications:**
- **Mulder:** Implement the `AnalyzeWithFoundryAgent` activity function with tool-call handling loop
- **Doggett:** Update architecture docs to reflect Foundry agent; document demo deployment steps
- **Skinner:** Test the full demo flow: deploy → stress → alert → diagnosis → Teams
- **All agents:** Foundry agent creation is a post-deployment script (not Bicep-native yet)

**Risks:**
1. **Foundry agent API maturity** — API may change; we're early adopters. Mitigated by abstracting behind the activity function.
2. **Bicep gap** — Agent creation isn't Bicep-native. Requires PowerShell post-deploy script.
3. **Cost increase** — AI Search adds ~$25/month at Basic tier for production. Free tier sufficient for demo.
4. **Tool call latency** — Agent may call 1-3 tools per investigation, adding 5-15 seconds. Acceptable for async pipeline.

**Alternatives Rejected:**
1. **Stay on raw OpenAI** — Works but no knowledge base, no tools, no memory. We'd rebuild what Foundry offers.
2. **Semantic Kernel orchestration** — More flexible but adds C#/.NET dependency to a PowerShell-native project.
3. **LangChain/Python agent** — Wrong language for the stack. All existing code is PowerShell.

---

### 16. User Directive: 2026-03-11T23:35:42Z

**By:** Anthony Watherston (via Copilot)  

**What:** Use Microsoft Foundry agents for the AI/intelligence layer instead of raw Azure OpenAI calls. Create demo infrastructure (IaC) that can be stood up to demonstrate the full alert-to-diagnosis flow.

**Why:** User request — captured for team memory

**Outcome:** Implemented via Decision #15 (Foundry Agent pivot + Bicep demo infrastructure)

---

## Governance

- All meaningful changes require team consensus
- Document architectural decisions here
- Keep history focused on work, decisions focused on direction

### 17. Decision: Phase 1 Demo Bicep IaC Layout

**Date:** 2026-03-12  
**Owner:** Mulder  
**Status:** Implemented

## Context
Phase 1 demo requires a single deployment that provisions VM diagnostics, monitoring, Foundry AI resources, and supporting services. Infrastructure must remain modular, repeatable, and tagged consistently for demo operations.

## Decision
Adopt a modular Bicep structure under infra/ with a main.bicep orchestrator and modules for networking, target VM, monitoring, Function App, Foundry + OpenAI deployment, storage, Key Vault, search, and optional Event Grid. All resources are tagged with project=serverwhisperer and nvironment=demo. Function App managed identity receives RG-level Reader, Monitoring Reader, and Virtual Machine Contributor plus Key Vault Secrets User at vault scope.

## Rationale
- Modularized Bicep keeps each concern independently testable and reusable.
- Central orchestration ensures one-shot deployment for demo setup.
- Managed identity + RBAC avoids storing credentials.
- Tags enable easy filtering and cleanup in demo subscriptions.

## Consequences
- Requires uploading configure-winrm.ps1 to a blob container and passing the URI to the VM extension.
- Foundry deployment relies on OpenAI account deployment for GPT-4o-mini until Foundry model deployment is Bicep-native.

---

### 18. Decision: Package Diagnostics Script with Function App Deployment

## Context
The Durable Function's ExecuteDiagnostics activity reads Get-AllDiagnostics.ps1 at runtime to invoke Azure Run Command. The function app code is deployed as a ZIP package, and the repository keeps the diagnostic script under infra/scripts/.

## Decision
The deployment script (infra/scripts/deploy-function-code.ps1) stages a temporary copy of the Function App code and adds Get-AllDiagnostics.ps1 at the Function App root before zipping. This guarantees the script is present in Azure and keeps the source-of-truth script in infra/scripts/.

## Consequences
- ExecuteDiagnostics can reliably load ..\Get-AllDiagnostics.ps1 in production.
- The repo avoids duplicating the script in multiple committed locations.
- Deployments are deterministic; the staging step is required.

---

### 19. Decision: Deployment Guide Structure for Alert Automation Demo

**Author:** Doggett (DevRel/Technical Writer)  
**Date:** 2026-03-12  
**Status:** Implemented  
**Request:** Anthony Watherston (deployment documentation for ServerWhisperer Alert Automation)

---

## Decision

Created infra/README.md as the definitive deployment guide for the ServerWhisperer Alert Automation demo infrastructure. The guide prioritizes **deployability** and **post-deployment verification** over architectural explanation (architecture is documented in Scully's plan).

### Structure Rationale

**Why this order?**

1. **Overview + Diagram** (top) — Readers need to understand the flow before they encounter commands
2. **Prerequisites** (before execution) — Catch blockers early (missing tools, permissions, services)
3. **Resource Providers** (before deployment) — Better to register namespaces in advance than fail mid-deployment
4. **Quick Start** (numbered, sequential) — Exactly mirrors the order: create RG → prepare params → deploy Bicep → deploy functions → create agent
5. **Post-Deployment Configuration** (verification, not troubleshooting) — New deployment is the happy path; verify before investigating issues
6. **Running the Demo** (triggers + expected timeline) — Only after infrastructure is verified
7. **Cost & Cleanup** (operational concerns) — Addressed after the demo runs successfully

**Why post-deployment verification is critical:**

- Deployment output doesn't always confirm success (Bicep ✅ doesn't mean Foundry agent was created)
- Users need explicit "check this exists" steps or they'll spend hours debugging non-existent resources
- Verification commands are testable entry points for troubleshooting (if verification fails, skip to troubleshooting)

### Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| All commands are copy-pasteable | Reduces transcription errors, increases successful deployments |
| Dynamic resource ID lookup ($(az ...)) | Infrastructure names might vary; avoid hardcoding |
| Parameter file guidance instead of hard-coded values | Teams webhook and VM password are user-provided; show where they go |
| Realistic timelines in comments | Users understand why they're waiting (10-15 min for Bicep, ~5-7 min for alert window) |
| Three troubleshooting "trees" (symptoms → diagnosis → fix) | Not all failures have the same root cause; users need branching decision logic |
| Cost section emphasizes deallocate-when-idle | Pivotal for demo economics; otherwise looks expensive |
| Cleanup explicitly warns of permanent deletion | Prevents accidental data loss after demo |

### Audience Assumptions

- User is an **Azure ops engineer or SRE** — familiar with Azure Portal, CLI, subscriptions, RBAC
- User **is NOT** a Foundry/AI expert — explain AI Foundry as "managed agent service" without deep theory
- User **has never deployed this specific demo** — walk them through one working example
- User **reads from top to bottom** — don't reference "see step 3" from step 8; keep each section self-contained

---

### 20. Decision: Validation Script Architecture for Demo Infrastructure

**Author:** Skinner (Tester/QA)  
**Date:** 2026-03-12  
**Status:** Implemented  
**Related:** Phase 1 Demo Infrastructure (Scully's architecture plan v2)

---

## Summary

Created two validation scripts for the Alert-to-Diagnosis pipeline demo infrastructure:

1. **Validate-Deployment.ps1** — Post-deployment smoke test (13 checks, ~2-3 min runtime)
2. **Test-EndToEnd.ps1** — Full integration test from alert to report blob (~10-15 min runtime)

Both scripts follow a consistent pattern: structured checks, visual output with emoji indicators, actionable error messages with remediation steps, and proper exit codes for CI/CD integration.

### Validation Strategy

| Script | Purpose | When to Run | Duration |
|--------|---------|-------------|----------|
| **Validate-Deployment** | Smoke test — verify all resources are deployed and configured correctly | After every z deployment group create, before demo | 2-3 min |
| **Test-EndToEnd** | Integration test — trigger alert, verify full pipeline execution, confirm report created | On demand or in CI pipeline | 10-15 min |

### Design Patterns

1. **Structured check results** — Consistent output format, immediate feedback with remediation
2. **Graceful resource discovery** — No hardcoded names, discovers by type, handles naming variations
3. **Time-boxed polling with elapsed time** — Users see progress, know script hasn't hung, understand remaining time

### Check Coverage

**Validate-Deployment.ps1 (13 checks):**
1. Resource Group exists (resource count)
2. VM is running (power state)
3. VM has system-assigned managed identity enabled
4. Function App is running
5. Function App app settings (FOUNDRY_ENDPOINT, FOUNDRY_AGENT_ID not placeholders)
6. Alert rules active (3/3 enabled)
7. Action Group exists with receivers
8. Key Vault accessible by Function App MI
9. Storage account has 'reports' and 'diagnostics' containers
10. AI Search service running
11. Foundry project exists
12. Run Command works (Invoke-AzVMRunCommand returns hostname)
13. Teams webhook test (optional with -TestTeams switch)

**Test-EndToEnd.ps1 flow:**
1. Run Validate-Deployment.ps1 (bail if fails)
2. Trigger CPU stress via Run Command (7 minutes by default)
3. Poll Azure Monitor Activity Log for alert (check every 30s)
4. Wait for orchestration processing (120s window — assumes execution without direct API access)
5. Check for report blob in storage (created in last 15 minutes)
6. Report success/failure with total elapsed time

---
