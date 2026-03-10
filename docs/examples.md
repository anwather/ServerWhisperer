---
layout: default
title: Examples
nav_order: 4
description: "Example ServerWhisperer sessions showing real diagnostic output"
---

# Example Sessions
{: .no_toc }

Real-world examples showing how ServerWhisperer handles different scenarios.
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

## General Health Check

The most common question — a broad overview of server health.

```bash
$ copilot "What's going on with server01?"
```

```
Parsing... server01, general health check, using current user credentials
Connecting to server01 via PowerShell remoting...
Running overview + key health checks...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔍 SERVERWHISPERER REPORT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SERVER: server01
STATUS: 🟡 Warning
TIMESTAMP: 2026-03-09T14:30:00Z

───────────────────────────────────────────────────
FINDINGS
───────────────────────────────────────────────────

🔴 Disk Space Critical
  C: drive is 92% full (4.6 GB free of 60 GB total)
  Impact: Apps may fail to write temp files, event logs may not record
  Action: Delete temp files, archive old logs, or expand volume

🟡 Memory Usage Elevated
  Currently 78% (12.5 GB of 16 GB), SQL Server using 8.2 GB
  Impact: System may slow down under load; disk paging increases
  Action: Monitor trends; if persistent, check SQL for memory leaks

🟢 Critical Services Running
  SQL Server Agent: Running
  IIS World Wide Web Publishing: Running
  Windows Defender: Running

───────────────────────────────────────────────────
SUMMARY
───────────────────────────────────────────────────

server01 is mostly healthy but has two concerns: disk space is critically low
at 92% full, and memory is elevated at 78%. Prioritize freeing disk space to
prevent application failures, then monitor memory trends.

Next steps: Clean C:\Temp and C:\Windows\Temp directories, then review IIS
logs for archival.
```

---

## Disk Space Investigation

When a server is running out of disk space, ServerWhisperer identifies what's consuming it and suggests a safe cleanup sequence.

```bash
$ copilot "server01 is out of disk space. What can I delete?"
```

```
Parsing... server01, disk space concern, using current user credentials
Running disk-storage diagnostic skill...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔍 SERVERWHISPERER REPORT — DISK ANALYSIS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SERVER: server01
FOCUS: Disk Space Analysis
STATUS: 🔴 Critical
TIMESTAMP: 2026-03-09T14:32:00Z

───────────────────────────────────────────────────
FINDINGS
───────────────────────────────────────────────────

💾 Volume C: at Capacity
  Total: 60 GB | Used: 55.4 GB | Free: 4.6 GB (92% full)
  Danger: Below 10% free threshold

📂 Top Folders (cleanup candidates, in order of size):
  1. C:\Windows\Logs — 8.2 GB
     Contents: Event logs, IIS logs, system logs
     Risk: Low (logs can be archived)

  2. C:\inetpub\logs\LogFiles — 6.1 GB
     Contents: Old IIS request logs (Jan-Feb 2026)
     Risk: Very low (old logs, safe to archive)

  3. C:\Temp — 2.8 GB
     Contents: Application temp files
     Risk: Very low (apps recreate as needed)

  4. C:\Windows\Temp — 1.9 GB
     Contents: System temp files
     Risk: Very low (system recreates)

  5. C:\Program Files\App\Backup — 1.7 GB
     Contents: Application backups (dates unknown)
     Risk: Medium (verify before deleting)

🗑️ Safe Cleanup Sequence:
  Step 1: Delete C:\Windows\Temp (1.9 GB freed, very safe)
  Step 2: Delete C:\Temp (2.8 GB freed, very safe)
  Step 3: Archive IIS logs to external storage (6.1 GB freed)
  Step 4: Review backups in C:\Program Files\App\Backup (1.7 GB potential)

───────────────────────────────────────────────────
SUMMARY
───────────────────────────────────────────────────

C: drive is critically full. You can safely free ~11.5 GB by cleaning temp
directories and archiving old IIS logs. Start with the temp directories
(lowest risk), then tackle IIS logs if needed.

Next steps: Execute the cleanup sequence above, then verify free space
with a follow-up check.
```

---

## Service Troubleshooting

Checking if a specific service is running and investigating recent issues.

```bash
$ copilot "Is the SQL service running on server02?"
```

```
Parsing... server02, SQL service status, using current user credentials
Running services diagnostic skill...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔍 WIN-INVESTIGATOR REPORT — SERVICE CHECK
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SERVER: server02
FOCUS: SQL Service Status
STATUS: 🟡 Warning
TIMESTAMP: 2026-03-09T15:00:00Z

───────────────────────────────────────────────────
FINDINGS
───────────────────────────────────────────────────

🟢 MSSQLSERVER (SQL Server)
  Status: Running
  Start Type: Automatic
  Process ID: 4832
  Memory: 6.4 GB

🔴 SQLSERVERAGENT (SQL Server Agent)
  Status: Stopped
  Start Type: Automatic
  ⚠ This service is set to Auto but is NOT running

🟡 Recent Service Crashes (last 7 days)
  2026-03-08 03:14:22 — SQL Server Agent crashed (Event 7034)
  2026-03-07 11:45:00 — SQL Server Agent crashed (Event 7031)
  → SQL Server Agent has crashed 2 times in the past week

───────────────────────────────────────────────────
SUMMARY
───────────────────────────────────────────────────

SQL Server itself is running fine, but SQL Server Agent is stopped and has
crashed twice this week. Scheduled jobs, alerts, and replication tasks
that depend on SQL Agent are not executing.

Next steps: Restart SQL Server Agent service. If it crashes again, check
the SQL Agent error log and Application event log for root cause.
```

---

## Network Connectivity Check

Testing whether a server is reachable and diagnosing network issues.

```bash
$ copilot "Can you reach server04?"
```

```
Parsing... server04, connectivity test, using current user credentials
Running connectivity diagnostic skill...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔍 WIN-INVESTIGATOR REPORT — CONNECTIVITY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SERVER: server04
FOCUS: Connectivity Test
STATUS: 🔴 Critical
TIMESTAMP: 2026-03-09T15:15:00Z

───────────────────────────────────────────────────
FINDINGS
───────────────────────────────────────────────────

🟢 Ping Test
  ✓ server04 is responding to ping
  Average latency: 2.4 ms

🔴 WinRM Test
  ✗ WinRM is not responding on server04
  Error: "The WinRM client cannot process the request"

🔴 PowerShell Remoting
  ✗ Cannot execute remote commands
  Cause: WinRM service may not be enabled

───────────────────────────────────────────────────
SUMMARY
───────────────────────────────────────────────────

server04 is reachable on the network (ping succeeds) but PowerShell
remoting is not available. WinRM is either not enabled or is blocked
by a firewall rule.

Next steps:
1. On server04, run: Enable-PSRemoting -Force
2. Verify WinRM service is running: Get-Service WinRM
3. Check firewall allows port 5986: Get-NetFirewallRule -DisplayName "WinRM HTTPS"
```

---

## Using Alternate Credentials

When your current user doesn't have admin rights on the target server.

```bash
$ copilot "Check server03 memory with domain\admin credentials"
```

```
Parsing... server03, memory check, explicit credentials requested
Enter password for domain\admin: ********
Connecting to server03 with provided credentials...
Running performance diagnostic skill...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔍 WIN-INVESTIGATOR REPORT — PERFORMANCE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SERVER: server03
FOCUS: Memory & Performance
STATUS: 🔴 Critical
TIMESTAMP: 2026-03-09T15:30:00Z
CREDENTIALS: domain\admin

───────────────────────────────────────────────────
FINDINGS
───────────────────────────────────────────────────

🔴 Memory Usage Critical
  Total: 32 GB | Used: 30.1 GB (94%) | Free: 1.9 GB
  Pages/sec: 842 (severe memory pressure — swapping to disk)
  Available: 1,946 MB

🔴 Top Memory Consumers
  1. javaw.exe (PID 6102) — 14.2 GB
  2. sqlservr.exe (PID 2044) — 8.6 GB
  3. w3wp.exe (PID 5580) — 3.1 GB
  4. w3wp.exe (PID 5612) — 2.8 GB

🟡 CPU Usage Elevated
  Current: 72%
  Top consumer: javaw.exe (PID 6102) at 45%

───────────────────────────────────────────────────
SUMMARY
───────────────────────────────────────────────────

server03 is under severe memory pressure at 94% used. A Java application
(javaw.exe) is consuming 14.2 GB alone and is also the top CPU consumer.
The system is actively swapping to disk (842 pages/sec), which is
dramatically impacting performance.

Next steps: Investigate the Java application (PID 6102) — it may have a
memory leak. Consider restarting the application or increasing server RAM.
```

{: .note }
> When using explicit credentials, the credential prompt appears inline. The credentials are used for this check only and are never stored.

---

_Built by the ServerWhisperer team._
