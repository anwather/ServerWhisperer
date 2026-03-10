---
layout: default
title: Usage Guide
nav_order: 2
description: "How to talk to ServerWhisperer. Simple examples, credential handling, understanding reports."
---

# Usage Guide
{: .no_toc }

**How to ask ServerWhisperer questions and read the reports.**
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

## How to Talk to the Agent

ServerWhisperer is like chatting with a colleague. Just describe what you want to know.

{: .note }
> **Include the server name** and **what you're concerned about**. The more specific, the better.

### Start an Interactive Session

```bash
cd ServerWhisperer
gh copilot
```

You'll see a prompt asking what you need help with. Just type your question naturally.

---

## Simple Examples (Start Here)

### ✅ General Health Check

Ask this when you want a quick overview:

```
? "What is going on with server01?"
```

You'll get: OS info, uptime, disk space, memory, and a snapshot of services.

### ✅ Something Specific is Broken

Ask this when you know what's wrong:

```
? "server01 is running out of disk space"
```

You'll get: Detailed disk analysis, biggest folders, cleanup suggestions.

### ✅ Is a Service Running?

Ask about a specific service:

```
? "Is the SQL service running on server02?"
```

You'll get: Service status, startup type, recent errors, event log entries.

### ✅ Server is Slow

Ask about performance:

```
? "server03 is slow — what's using the CPU?"
```

You'll get: Top processes by CPU/memory, system load, baseline comparison.

### ✅ Can You Reach It?

Ask about network connectivity:

```
? "Can you reach server04?"
```

You'll get: Network adapter status, IP config, ping tests, open ports.

---

## Tips for Better Questions

| Do This | Why | Example |
|---------|-----|---------|
| **Include server name** | Agent needs to know which server | ✅ "server01 is slow" |
| **Include what's wrong** | Helps agent pick the right diagnostic | ✅ "disk is full" vs ❌ "server01" |
| **Use plain English** | No special syntax needed | ✅ "Why is disk full?" vs ❌ "Get-Volume -Size" |
| **Mention urgency if high** | Agent prioritizes critical issues | ✅ "server01 is down" vs "investigate server01" |

---

## Credentials: Default vs. Explicit

### Default (Uses Your Current User)

By default, ServerWhisperer uses your Windows user account. If you have admin access to the target server, just ask:

```
? "Check server01"
```

No password prompt. It just works.

### Explicit Credentials (Pre-created Variable)

If you need to use a different account (e.g., a dedicated admin account), create the `$credential`
variable in your PowerShell session **before** running `gh copilot`:

```powershell
# Step 1: Create the credential (in PowerShell, before starting Copilot)
$credential = Get-Credential

# A secure Windows dialog opens — enter username and password there

# Step 2: Start Copilot (credential is automatically available)
gh copilot
```

Then just ask your question — the agent detects `$credential` and uses it automatically:

```
? "Check server01"
```

**How it works:**
1. You run `$credential = Get-Credential` — Windows opens a secure login dialog
2. You enter username/password in the dialog (password is hidden, never visible in chat)
3. You start `gh copilot` — the agent checks for the `$credential` variable
4. If found, the agent uses it for all remote connections
5. If not found, the agent tells you to create it

⚠️ **SECURITY: Never type passwords in the Copilot CLI chat.** Always create credentials 
using `$credential = Get-Credential` before starting Copilot. Passwords typed in chat are 
visible in plain text and stored in history.

**Important:** The `$credential` variable lasts for the lifetime of your PowerShell session. 
You can run multiple investigations without re-entering credentials. If you close PowerShell, 
run `$credential = Get-Credential` again in the new session.

---

## Understanding the Report

All reports follow the same structure, so they're easy to read.

### Parallel Background Investigations

When you ask for a full investigation, ServerWhisperer runs all diagnostics **simultaneously as background jobs** instead of one-by-one. This drastically cuts investigation time from 2-3 minutes down to 30-60 seconds.

{: .note }
> **What happens:** You ask your question → Agent starts 8-10 diagnostics as parallel jobs → Results stream in as they complete → You see findings prioritized by severity, not by completion order.

Some diagnostics are fast (overview, disk, network take 2-10s), while others are slow (Event Logs and Roles/Features can take 30-60s). The parallel approach means slow diagnostics don't block fast ones.

**You'll see results incrementally** — the report updates as each diagnostic finishes, so you get actionable findings quickly rather than waiting for everything.

### The Parts of a Report

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔍 SERVERWHISPERER REPORT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SERVER: server01                          ← Target server
STATUS: 🟡 Warning                        ← Overall health
TIMESTAMP: 2026-03-09T14:30:00Z           ← When the check ran

───────────────────────────────────────────────────
FINDINGS (most critical first)
───────────────────────────────────────────────────

🔴 Disk Space Critical                    ← Severity indicator
  C: drive is 92% full (4.6 GB free)      ← Specific data
  Impact: Apps may fail...                ← Why this matters
  Action: Delete temp files...            ← What to do

🟡 Memory Usage Elevated
  Currently 78% (12.5 GB of 16 GB)
  Impact: Performance may degrade...
  Action: Monitor trends...

───────────────────────────────────────────────────
SUMMARY
───────────────────────────────────────────────────

server01 is mostly healthy but disk is critically low...  ← Plain English
Next steps: Clean temp, then monitor memory.             ← What to do next
```

### Reading the Status Indicators

| Icon | Meaning | What to Do |
|------|---------|-----------|
| 🟢 Healthy | No problems, everything is normal | Monitor as usual |
| 🟡 Warning | Concerning trend, approaching limit | Investigate or monitor closely |
| 🔴 Critical | Problem now, action required | Act immediately |

---

## Common Beginner Questions

### Q: Can I ask multiple questions in one session?

**A:** Yes! After you get a response, you'll see the prompt again. Just ask another question.

```
? "Check server01"
[gets report]
? "Now check server02"
[gets report for server02]
```

### Q: What if the agent doesn't understand my question?

**A:** Rephrase it to be more specific. Include the server name and what you're concerned about.

```
❌ "diagnose"              ← Too vague
✅ "server01 is slow"      ← Clear and specific
```

### Q: Can I use this on my local machine or must it be a server?

**A:** Any Windows machine with PowerShell remoting enabled. Works for local workstations too.

### Q: What if I don't have admin access to a server?

**A:** Create a credential for a user who does, then start Copilot:

```powershell
$credential = Get-Credential
gh copilot
```

```
? "Check server01"
```

### Q: How long do checks usually take?

**A:** Depends on the investigation type. **Focused checks** (disk, services, network) take 5-15 seconds. **Full investigations** run all diagnostics in parallel and complete in 30-60 seconds total. A few diagnostics are slow by nature (Event Logs, Roles/Features) but run in the background while others finish — you see results as they complete.

| Diagnostic | Duration | Notes |
|-----------|----------|-------|
| Overview | 2-5s | Fast |
| Disks | 2-5s | Fast |
| Performance | 3-10s | Counter sampling |
| Services | 3-8s | Moderate |
| Processes | 5-15s | Depends on count |
| Network | 3-10s | Moderate |
| Event Logs | 15-60s | SLOW — background |
| Installed Apps | 5-10s | Fast (registry method) |
| Roles/Features | 10-30s | SLOW — background |

**Sequential total:** ~2-3 minutes. **Parallel total:** ~30-60 seconds.

### Q: Can I save the report?

**A:** Copy/paste the report text into a document, email, or Slack. Reports are in plain text.

---

## Automated Investigations (Advanced)

By default, ServerWhisperer is interactive — you ask questions and get reports instantly. But you can also configure it to **run automatically from Azure Monitor alerts**.

{: .note }
> See [Automated Investigations]({{ site.baseurl }}/automation.md) for the complete guide to setting up alert-triggered diagnostics, credential handling via Azure Key Vault, and GitHub Actions integration.

### When to Use Automation

- **After-hours alerts** — Automatic diagnostics when your team is offline
- **Proactive health checks** — Run on alert thresholds without manual intervention
- **Fast escalation** — Alert → GitHub Issue → Team notification (all automated)
- **Production systems** — Get diagnostics in seconds, not minutes

### Prerequisites for Automation

- Azure subscription with Azure Monitor
- Azure Key Vault to store server credentials
- GitHub Actions enabled in your repository
- Azure AD OIDC federation configured (optional but recommended)

---

## Limitations & When to Escalate

{: .note }
> ServerWhisperer is a **diagnostic tool**, not an automation tool. It reports findings and suggests actions — it does not make changes to your servers.

### What ServerWhisperer Can Do

- ✅ Report what's happening on your servers
- ✅ Identify problems and suggest causes
- ✅ Recommend next steps
- ✅ Collect findings in priority order

### What It Cannot Do

- ❌ Restart services (escalate to on-call admin)
- ❌ Modify server configuration (escalate to on-call admin)
- ❌ Add disk space or expand volumes (escalate to infrastructure)
- ❌ Fix database issues (escalate to DBA)
- ❌ Resolve security incidents (escalate to security team)

### When to Escalate

**On-call admin:**
- Service restart needed
- Configuration change needed
- Immediate action required

**DBA:**
- Database-specific issues (SQL, replication, backups)
- Performance tuning needed

**Infrastructure:**
- Disk expansion or capacity planning
- Hardware issues (failed drives, RAM problems)

**Security Team:**
- Security events or unauthorized access
- Potential malware

---

_Built by the ServerWhisperer team._
