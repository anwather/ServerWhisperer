---
layout: default
title: Diagnostics Reference
nav_order: 3
description: "Complete reference of all ServerWhisperer diagnostic skills and what they check"
---

# Diagnostics Reference
{: .no_toc }

ServerWhisperer includes 10 focused diagnostic skills. Each one is triggered by the type of question you ask.
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

## Overview

| Skill | Purpose | Example Question |
|-------|---------|-----------------|
| [Connectivity](#connectivity) | Test reachability and WinRM | _"Can you reach server01?"_ |
| [Server Overview](#server-overview) | OS info, uptime, hardware | _"What is going on with server01?"_ |
| [Disk Storage](#disk-storage) | Volume space, disk health, SMART | _"server01 is out of disk space"_ |
| [Performance](#performance) | CPU, memory, disk I/O, network throughput | _"server01 is slow"_ |
| [Processes](#processes) | Running processes, top consumers, hung apps | _"What's using CPU on server01?"_ |
| [Services](#services) | Service status, crashes, dependencies | _"Is SQL running on server02?"_ |
| [Network](#network) | Adapters, DNS, ports, firewall | _"Check network on server01"_ |
| [Event Logs](#event-logs) | Critical errors, crashes, security events | _"Any errors on server01?"_ |
| [Installed Apps](#installed-applications) | Software inventory, updates, hotfixes | _"What software is on server01?"_ |
| [Roles & Features](#roles--features) | Server roles, features, role-specific config | _"What roles are on server01?"_ |

---

## Connectivity

**Purpose:** Test connectivity to a Windows Server and establish a PowerShell remoting session. This is typically the first skill to run before any diagnostics.

### What It Checks

- **Ping (ICMP)** — Is the server reachable on the network?
- **WinRM** — Is PowerShell remoting enabled and responding?
- **Authentication** — Can we execute commands with current or provided credentials?
- **CIM session** — Can we establish a CIM session for WMI data?

### Triggers

- _"Can you reach server01?"_
- _"Test connectivity to server01"_
- _"Is server01 online?"_

### Common Failures

| Error | Cause | Fix |
|-------|-------|-----|
| Access is denied | Insufficient permissions | Use account with local admin rights |
| Cannot be resolved | DNS/name resolution failure | Check hostname, try IP address |
| WinRM cannot process | WinRM not enabled | Run `Enable-PSRemoting -Force` on target |
| Connection timed out | Firewall blocking | Check port 5986 (HTTPS) |
| Logon failure | Bad credentials | Verify username/password |

---

## Server Overview

**Purpose:** Get a high-level overview of the target server — hostname, OS version, uptime, domain membership, and basic hardware info.

### What It Checks

- OS name, version, build number, architecture
- Hostname, FQDN, domain membership, domain role
- Last boot time and uptime
- Hardware: manufacturer, model, RAM, CPU count
- BIOS information

### Triggers

- _"What is going on with server01?"_
- _"Give me an overview of server01"_
- _"Check server01"_ (general)

### Key Thresholds

| Metric | Good | Warning | Critical |
|--------|------|---------|----------|
| Uptime | 7–60 days | 60–90 days | >90 days (missing patches) or <1 day (frequent reboots) |

{: .note }
> Uptime >90 days typically means the server is missing Windows Updates that require a reboot.

---

## Disk Storage

**Purpose:** Analyze disk storage including volume space, disk health, SMART data, large files, and I/O performance.

### What It Checks

- **Volume space** — Size, used, free, percent free per drive
- **Physical disks** — Health status, media type, bus type
- **SMART data** — Temperature, read/write errors, power-on hours
- **Large files/folders** — Top space consumers for cleanup
- **Disk I/O** — Read/write latency, queue length

### Triggers

- _"server01 is out of disk space"_
- _"What can I delete on server01?"_
- _"Check disk health on server01"_

### Space Thresholds

| Free Space | Status | Action |
|------------|--------|--------|
| >20% | 🟢 Healthy | Monitor regularly |
| 10–20% | 🟡 Warning | Plan cleanup or expansion |
| 5–10% | 🔴 Critical | Immediate action needed |
| <5% | 🔴 Emergency | System may become unstable |

### I/O Performance

| Metric | SSD Good | HDD Good | Problem |
|--------|----------|----------|---------|
| Read Latency | <10 ms | <15 ms | >50 ms |
| Write Latency | <10 ms | <15 ms | >50 ms |
| Queue Length | <1 | <2 | >5 |

---

## Performance

**Purpose:** Collect real-time performance metrics — CPU, memory, disk I/O, and network throughput — with optional continuous sampling.

### What It Checks

- **CPU** — Utilization %, processor queue length
- **Memory** — Total/used/free, percent used, page faults/sec, pages/sec
- **Disk** — Reads/writes per second, latency, queue length
- **Network** — Bytes sent/received, Mbps throughput

### Triggers

- _"server01 is slow"_
- _"Get baseline performance on server01"_
- _"What's using resources on server01?"_

### CPU Thresholds

| Metric | Healthy | Warning | Critical |
|--------|---------|---------|----------|
| % Processor Time | <70% | 70–90% | >90% |
| Processor Queue | <2 per core | 2–5 per core | >5 per core |

### Memory Thresholds

| Metric | Healthy | Warning | Critical |
|--------|---------|---------|----------|
| Available Memory | >20% of total | 10–20% | <10% |
| Pages/sec | <100 | 100–500 | >500 |

{: .warning }
> **Pages/sec >100** indicates memory pressure — the system is swapping to disk, which severely impacts performance.

---

## Processes

**Purpose:** Analyze running processes — identify top CPU and memory consumers, detect hung applications, and spot anomalies.

### What It Checks

- Total process count and aggregate memory usage
- **Top 10 CPU consumers** with process details
- **Top 10 memory consumers** with handle/thread counts
- Processes with high handle count (>10,000) — potential resource leak
- Processes with high thread count (>100) — potential deadlock
- Hung/not responding processes (GUI apps)
- Process search by name pattern

### Triggers

- _"What's using CPU on server01?"_
- _"server01 is slow — what process is the cause?"_
- _"Is w3wp running on server01?"_

### Warning Signs

| Indicator | Possible Issue |
|-----------|---------------|
| Process count >500 | Runaway process spawning |
| Unknown process >50% CPU | Malware or misconfiguration |
| High handle count (>10k) | Resource leak |
| Processes in Temp folders | Potential malware |
| Misspelled system processes | Malware (e.g., "svch0st.exe") |

---

## Services

**Purpose:** Analyze Windows services — status, startup type, crashes, dependencies, and services that should be running but aren't.

### What It Checks

- Total service count (running, stopped, disabled)
- **Auto-start services that aren't running** — potential crashes or failures
- Recent service crash events (Event IDs 7031, 7034)
- Service dependencies (what depends on what)
- Services running with custom/privileged accounts

### Triggers

- _"Is SQL running on server02?"_
- _"Check services on server01"_
- _"What services have crashed on server01?"_

### Key Services by Role

| Role | Critical Services |
|------|------------------|
| Domain Controller | NTDS, DNS Server, Kerberos KDC, Netlogon |
| Web Server (IIS) | W3SVC, WAS |
| SQL Server | MSSQLSERVER, SQLSERVERAGENT |
| File Server | LanmanServer, DFS |
| Any domain member | RpcSs, Dnscache, Netlogon, EventLog |

---

## Network

**Purpose:** Analyze network configuration — adapters, IP config, DNS, open ports, firewall rules, and connectivity tests.

### What It Checks

- **Network adapters** — Status, IP, DNS, gateway, link speed, DHCP
- **Listening ports** — What's listening and which process owns it
- **Established connections** — Active TCP connections
- **DNS resolution** — Can the server resolve hostnames?
- **Connectivity tests** — Ping + port tests to target hosts
- **Firewall rules** — Enabled inbound/outbound rules

### Triggers

- _"Check network on server01"_
- _"Can server01 reach the internet?"_
- _"What ports are open on server01?"_

### Common Port Reference

| Port | Service | Purpose |
|------|---------|---------|
| 53 | DNS | Name resolution |
| 80 / 443 | HTTP / HTTPS | Web traffic |
| 445 | SMB | File sharing |
| 1433 | SQL Server | Database |
| 3389 | RDP | Remote Desktop |
| 5986 | WinRM | PowerShell remoting (HTTPS) |

---

## Event Logs

**Purpose:** Analyze Windows Event Logs for critical errors, warnings, crashes, unexpected reboots, and security events.

### What It Checks

- **System log** — Critical and error events (last 7 days by default)
- **Application log** — Critical and error events
- **Security log** — Logon successes/failures (if accessible)
- **Crash analysis** — Blue screens (1001), unexpected shutdowns (6008), kernel power events (41)
- **Event grouping** — Top error sources by frequency

### Triggers

- _"Any errors on server01?"_
- _"Has server01 crashed recently?"_
- _"Check event logs on server01"_

### Key Event IDs

| Event ID | Log | Meaning |
|----------|-----|---------|
| 41 | System | Unexpected reboot (Kernel-Power) |
| 1001 | System | Blue Screen (BugCheck) |
| 6008 | System | Unexpected shutdown |
| 7031 / 7034 | System | Service crashed |
| 1000 | Application | Application error |
| 4625 | Security | Failed logon attempt |

---

## Installed Applications

**Purpose:** Get a software inventory — installed applications, recent installs, Windows updates/hotfixes, and potential problems.

### What It Checks

- **Full application inventory** via registry (fast and reliable)
- **Recent installations** — Software installed in the last 30 days
- **Windows hotfixes** — Installed updates and patch status
- **Search by pattern** — Find specific software (e.g., `*SQL*`, `*Java*`)

### Triggers

- _"What software is on server01?"_
- _"Is Java installed on server01?"_
- _"When was server01 last patched?"_

### Patch Health

| Status | Meaning | Risk |
|--------|---------|------|
| Updated in last 30 days | Healthy | Low |
| No updates in 60+ days | Warning | Medium |
| No updates in 90+ days | Critical | High — missing security patches |

{: .important }
> Servers without recent patches are a security risk. Check the Windows Update service if patches are overdue.

---

## Roles & Features

**Purpose:** Inventory installed Windows Server roles, role services, and features — plus role-specific configuration checks.

### What It Checks

- **Installed roles** — AD DS, DNS, IIS, Hyper-V, File Services, etc.
- **Installed role services** — Sub-components of roles
- **Installed features** — .NET Framework, PowerShell, RSAT tools, etc.
- **Role-specific config** — IIS sites/app pools, AD DS domain info, FSMO roles

### Triggers

- _"What roles are on server01?"_
- _"Is IIS installed on server01?"_
- _"Show AD DS configuration on dc01"_

### Common Server Roles

| Role | Display Name | Purpose |
|------|-------------|---------|
| AD-Domain-Services | Active Directory Domain Services | Domain controller |
| DNS | DNS Server | Name resolution |
| Web-Server | Web Server (IIS) | Web hosting |
| File-Services | File and Storage Services | File sharing |
| Hyper-V | Hyper-V | Virtualization |
| DHCP | DHCP Server | IP address assignment |

---

_Built by the ServerWhisperer team._
