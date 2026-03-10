---
layout: default
title: Home
nav_order: 0
description: "🔮 ServerWhisperer — AI-driven Windows Server troubleshooting via Copilot CLI"
permalink: /
---

# 🔮 ServerWhisperer
{: .fs-9 }

**Ask questions about your Windows Servers in plain English. Get answers instantly.**
{: .fs-6 .fw-300 }

No complex commands. No scripts to learn. Just ask what's wrong.
{: .fs-5 .fw-400 }

[Get Started in 5 Minutes](/ServerWhisperer/getting-started){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-2 }
[View on GitHub](https://github.com/anwather/ServerWhisperer){: .btn .fs-5 .mb-4 .mb-md-0 }

---

## ⚡ Install Now (30 Seconds)

The **fastest way to get started** is to install ServerWhisperer as a Copilot CLI plugin:

```bash
copilot
/plugin install anwather/ServerWhisperer
```

Then ask a question:

```
? "What is going on with server01?"
```

That's it! All diagnostic skills are built-in. [Full instructions →](/ServerWhisperer/getting-started)

---

{: .highlight }
> ⚡ **First time using Copilot CLI?** No problem. We'll walk you through installing everything, step by step.

---

## The Simple Way vs. The Old Way

### ❌ The Old Way (Manual)

You: _"Why is server01 slow?"_

```powershell
$session = New-PSSession -ComputerName server01 -UseSSL
Invoke-Command $session { Get-Process | Sort-Object -Property CPU -Descending | Select-Object -First 10 }
Invoke-Command $session { Get-CimInstance Win32_PerfFormattedData_PerfProc_Process ... }
Invoke-Command $session { Get-WmiObject Win32_LogicalDisk ... }
# ... more commands ...
```

After 20 minutes: You have raw data but no insights.

### ✅ The ServerWhisperer Way

You: _"server01 is slow — what's using the CPU?"_

```bash
gh copilot
? "server01 is slow — what's using the CPU?"
```

ServerWhisperer:

```
🔴 CPU Spike — Process Analysis
  - explorer.exe: 45% CPU (Windows Explorer stuck scanning network)
  - svchost.exe: 28% CPU (Windows Update indexing)
  - sqlserver.exe: 18% CPU (normal operation)

💡 Action: Kill explorer.exe and restart Windows Update service

Next steps: Check Task Manager for explorer.exe handle locks
```

**Time:** 30 seconds. Actionable insights included.

---

## Quick Example

```bash
copilot "What's going on with server01?"
```

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔍 SERVERWHISPERER REPORT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SERVER: server01
STATUS: 🟡 Warning

🔴 Disk Space Critical — C: is 92% full (4.6 GB free)
🟡 Memory Usage Elevated — 78% of 16 GB in use
🟢 Critical Services Running — SQL, IIS, Defender all healthy

Next steps: Clean temp folders, then monitor memory trends.
```

---

## Questions You Can Ask

- _"What is going on with server01?"_
- _"Why is server01 running out of disk space?"_
- _"Is the SQL service running on server02?"_
- _"server03 is slow — what's using the resources?"_
- _"Can you reach server04?"_

---

## 10 Built-In Diagnostics

ServerWhisperer includes focused diagnostic skills for connectivity, server overview, disk storage, performance, processes, services, network configuration, event logs, installed applications, and Windows Server roles & features.

[See all diagnostics →](/ServerWhisperer/diagnostics){: .btn .btn-outline }

---

{: .note }
> ServerWhisperer is a **diagnostic tool**, not an automation tool. It reports findings and recommends actions — it does not make changes to your servers.

---

_Built by the ServerWhisperer team._
