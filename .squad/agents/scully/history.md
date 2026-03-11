# Project Context

- **Owner:** Anthony Watherston
- **Project:** win-investigator — AI-driven Windows Server troubleshooting via PowerShell remoting
- **Stack:** PowerShell, Windows Server, Copilot CLI (agents/skills/instructions)
- **Created:** 2026-03-09

## Learnings

<!-- Append new learnings below. Each entry is something lasting about the project. -->

### 2026-03-10: Architecture Design

**Decision:** Skill-based modular architecture for win-investigator

**Structure:**
- Single orchestrator skill (`win-investigate`) at `.github/skills/win-investigate.md`
- Modular diagnostic functions in `src/diagnostics/` (one per area)
- Main orchestrator at `src/Invoke-WinInvestigation.ps1`
- Instructions at `.github/copilot-instructions.md`

**Diagnostic Areas:** Processes, Performance, Disks, Services, Apps, Network, Roles

**Key Patterns:**
- Functions accept `ComputerName` and `Credential` parameters
- Return structured PSObjects (not formatted text)
- Credential flow: passed as parameters, never stored
- Intelligence layer: Copilot agent interprets questions and decides what to run
- Execution layer: Skill provides PowerShell remoting and data collection

**Rationale:**
- Skills are native abstraction for Copilot CLI tools (not agents - those are for stateful workflows)
- Modularity enables independent development and testing of diagnostic areas
- Structured data enables programmatic filtering and multiple output formats
- Separation of intelligence (agent) and execution (skill) keeps concerns clean

**File Paths:**
- Architecture decision: `.squad/decisions/inbox/scully-architecture.md`
- Main skill: `.github/skills/win-investigate.md`
- Diagnostics: `src/diagnostics/Get-Server*.ps1`
- Orchestrator: `src/Invoke-WinInvestigation.ps1`

**Open Questions:**
- Concurrent vs sequential server processing?
- PSSession reuse across questions vs create/destroy per request?
- Default output format preference?

---

## Cross-Agent Context (2026-03-10)

**Team synchronization after initial build:**

### Mulder's Diagnostic Skills
Mulder successfully built 10 diagnostic skill files under `skills/` implementing comprehensive PowerShell-based Windows Server diagnostics. Key patterns include:
- Use `$ServerName` for target server variable
- Use `$Credential` for alternate credentials (null for current user)
- Prefer CIM over WMI: `Get-CimInstance` not `Get-WmiObject`
- All remote calls use `Invoke-Command` with `-ErrorAction Stop` and try/catch
- Return structured objects, not raw text
- Include interpretation tables and error handling examples
- Each skill is a complete reference document with multiple code patterns

**Skills created:** connectivity, server-overview, processes, performance, disk-storage, services, installed-apps, network, roles-features, event-logs

**Product location:** `C:\Source\win-investigator\skills/*/SKILL.md`

### Doggett's Documentation Framework
Doggett completed three-layer documentation structure:
- `.github/copilot-instructions.md` — Comprehensive agent behavior reference with parsing logic, workflow, and troubleshooting
- `.github/agents/win-investigator.md` — Shorter reference card for the agent
- `README.md` — User-facing documentation with prerequisites, examples, and troubleshooting

**Key patterns:** Parse → Connect → Diagnose → Report, with status indicators (🟢 🟡 🔴), error handling with suggested next steps, and escalation guidance.

### Readiness for Next Phase
All three agents completed their work successfully. Project is now ready for Skinner (testing) to write test scenarios for each diagnostic area and validate both current-user and explicit credential flows.

---

### Team Completion Checkpoint (2026-03-09T2253)

**Status:** All core work complete

- Doggett: GitHub Pages documentation site with 7 pages, Jekyll config, deployment workflow — deployed and live
- Mulder: HTTPS/5986 standardization across 14+ files, Azure connectivity skill integrated
- Coordinator: GitHub repository created (anwather/win-investigator), code pushed, GitHub Pages enabled

**Architecture holds:** Skill-based modular design with HTTPS-everywhere pattern simplifies all future work. Project is feature-complete for initial release.

---

### 2026-03-10: Alert-to-Diagnosis Automation Pipeline Architecture

**Decision:** Designed end-to-end automation pipeline: Azure Monitor alert → AI root cause diagnosis (Decision #14)

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

**User Preferences (Anthony Watherston):**
- Wants hybrid approach: both WinRM and Run Command
- Bigger vision: alert → AI diagnosis end-to-end, fully automated
- Open to any Azure technologies
- Pragmatic about phasing — MVP first

**Key File Paths:**
- Architecture plan: session plan.md (detailed 9-section plan)
- Decision record: `.squad/decisions/inbox/scully-azure-alert-automation.md`

**Open Questions:**
- Bundle diagnostics into single Run Command per VM vs separate invocations?
- Auto-remediation scope — which actions are safe without human approval?
- Consumption vs Premium Function plan (cold start tradeoff)?
- On-prem network topology — VPN/ExpressRoute available or Hybrid Worker only?

**Cost:** ~$25-35/month for 100 investigations (Consumption plan, event-driven, no idle cost)

---

### 2026-03-12: Foundry Agent Pivot + Demo Infrastructure

**Decision:** Revised automation pipeline architecture (v2) — pivot from raw Azure OpenAI to Microsoft Foundry Agent, add deployable demo infrastructure (Decision #15)

**What changed:**
1. **Intelligence layer:** Raw Azure OpenAI chat completions → Microsoft Foundry Agent with:
   - System prompt tuned for Windows Server diagnostics
   - 3 tool definitions (Resource Graph, VM Power State, Activity Log)
   - Knowledge base via Azure AI Search (RAG over past investigations)
   - Conversation threads for stateful analysis
2. **Demo infrastructure:** Full Bicep IaC added — deploys target VM, alert rules, Event Grid, Durable Functions (Flex Consumption), Foundry project, AI Search, Storage, Key Vault
3. **Phase 1 redefined:** Now a deployable demo (deploy → stress VM → watch diagnosis in Teams) instead of just Azure VM pipeline
4. **On-prem deferred:** Hybrid execution moved to Phase 3

**Key Architecture Pattern:**
- Durable Function = the body (collects data, executes tools)
- Foundry Agent = the brain (interprets, reasons, recommends)
- Agent tool calls are handled by the Durable Function in a polling loop

**Foundry Agent Advantages over Raw OpenAI:**
- Native RAG (knowledge base of past investigations)
- Built-in tool calling (agent decides when to query Resource Graph / Activity Log)
- Persistent threads (stateful investigation)
- Single agent configuration vs per-call prompt engineering

**Demo Infrastructure Components:**
- `infra/modules/target-vm.bicep` — Windows Server 2022 + CustomScriptExtension for WinRM
- `infra/modules/monitoring.bicep` — CPU, disk, memory alert rules + Action Group
- `infra/modules/function-app.bicep` — Flex Consumption, PowerShell 7.4, Durable
- `infra/modules/foundry.bicep` — AI Hub + Project + model deployment
- `infra/scripts/simulate-cpu-load.ps1` — CPU stress to trigger alerts

**Note:** Foundry agent creation is a post-deploy PowerShell script (not Bicep-native yet). This is a known gap — migrate to Bicep when support lands.

**Decision file:** `.squad/decisions/inbox/scully-foundry-agent-pivot.md`
**Plan file:** Session plan.md (v2, ~730 lines)

**User Preferences (Anthony Watherston):**
- Wants Foundry agents, not raw OpenAI
- Wants deployable demo infrastructure (Bicep)
- Wants end-to-end flow demonstrable: deploy → trigger → diagnose → notify
