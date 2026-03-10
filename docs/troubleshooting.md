---
layout: default
title: Troubleshooting
nav_order: 5
description: "Fixes for common setup and connection issues. Start here if something isn't working."
---

# Troubleshooting
{: .no_toc }

**Something not working?** We've got solutions.
{: .fs-6 .fw-300 }

{: .important }
> **Security Note:** Never type passwords in the Copilot CLI chat. Always create credential files 
> using Export-Clixml **before** running `gh copilot`: `Get-Credential | Export-Clixml -Path "$HOME\.serverwhisperer\credentials.xml"`

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

## First Time Setup Issues

### `gh: command not found`

**Problem:** PowerShell doesn't recognize the `gh` command.

**Cause:** GitHub CLI is not installed or not in your PATH.

**Solution:**

1. Verify it installed:
   ```bash
   gh --version
   ```

2. If that fails:
   - Download from: https://cli.github.com/
   - Or reinstall via PowerShell:
     ```powershell
     winget install GitHub.cli
     ```

3. **Restart PowerShell** after installing, then try again.

---

### `Error: not authenticated` or `not logged in`

**Problem:** `gh auth status` shows "You are not logged in to any GitHub hosts."

**Cause:** You skipped the authentication step (Step 2 of Getting Started).

**Solution:**

```bash
gh auth logout
gh auth login
```

Follow the prompts to authenticate via web browser.

---

### `copilot extension not found`

**Problem:** `gh extension list | grep copilot` returns nothing.

**Cause:** The Copilot CLI extension is not installed.

**Solution:**

```bash
gh extension install github/gh-copilot
```

Verify it worked:

```bash
gh extension list
# Should show: github/gh-copilot
```

---

### `Error: Extension not available`

**Problem:** `gh extension install github/gh-copilot` fails with: "Extension not available."

**Cause:** Usually a network or authentication issue.

**Solution:**

1. Verify you're authenticated:
   ```bash
   gh auth status
   ```

2. If needed, re-authenticate:
   ```bash
   gh auth logout
   gh auth login
   ```

3. Try the install again:
   ```bash
   gh extension install github/gh-copilot
   ```

---

## Credential Issues

### Credential file not found

**Problem:** The agent says "No saved credentials found" when trying to connect.

**Cause:** You haven't created the encrypted credential file yet.

**Solution:**

Run these commands in your PowerShell session (outside of Copilot):

```powershell
# Step 1: Create the credentials directory
New-Item -ItemType Directory -Path "$HOME\.serverwhisperer" -Force

# Step 2: Save your credentials (opens secure GUI dialog)
Get-Credential | Export-Clixml -Path "$HOME\.serverwhisperer\credentials.xml"
```

A secure Windows dialog will open. Enter your username and password there. The file will be saved with DPAPI encryption. Then start Copilot:

```powershell
gh copilot
```

The agent will automatically load the saved credentials when needed.

{: .note }
> Credential files persist until you delete them. You only need to create them once per machine (unless you need to update credentials).

### Credential file won't decrypt

**Problem:** The agent can't decrypt the credential file, or you get an encryption error.

**Cause:** Credential files are encrypted with DPAPI and tied to the specific user + machine. If you:
- Moved the file from another machine
- Are logged in as a different user
- Restored from backup on a different computer

...the file cannot be decrypted.

**Solution:**

Delete the old file and create a new one on this machine:

```powershell
# Delete old credential file
Remove-Item "$HOME\.serverwhisperer\credentials.xml" -ErrorAction SilentlyContinue

# Create new credential file for this user + machine
Get-Credential | Export-Clixml -Path "$HOME\.serverwhisperer\credentials.xml"
```

{: .warning }
> DPAPI encryption is not portable by design — this is a security feature. Credential files only work on the machine where they were created, for the user who created them.

### Wrong username or password (Access Denied)

**Problem:** The agent loads credentials but connections fail with "Access denied".

**Solution:**

1. **Verify the username format** when creating the credential file:
   - Domain account: `domain\username` or `username@domain.com`
   - Local account: `.\username` or `ServerName\username`
   - Azure VM local: `VMName\AdminUser`
   - Azure VM with Azure AD: `user@domain.com`

2. **Re-create the credential file** with the correct username and password:
   ```powershell
   Remove-Item "$HOME\.serverwhisperer\credentials.xml"
   Get-Credential | Export-Clixml -Path "$HOME\.serverwhisperer\credentials.xml"
   ```

3. **Check Caps Lock** is off when typing password in the credential dialog

4. **Verify the account is not locked**:
   ```powershell
   # On domain controller:
   Get-ADUser username -Properties LockedOut
   ```

5. **Check the account has admin rights** on the target server

---

## Connection Issues

### `Test-WSMan: Unable to connect to the remote host`

**Problem:** `Test-WSMan server01 -UseSSL` fails.

**Cause:** PowerShell remoting is not enabled on the target server, or firewall blocks port 5986.

**Solution (on target server):**

1. **Re-enable PowerShell remoting:**

   ```powershell
   Enable-PSRemoting -Force
   winrm quickconfig -q
   ```

2. **Start the WinRM service:**

   ```powershell
   Start-Service WinRM
   Set-Service WinRM -StartupType Automatic
   ```

3. **Open Windows Firewall for WinRM HTTPS:**

   ```powershell
   New-NetFirewallRule -DisplayName "WinRM HTTPS" `
     -Name "WINRM-HTTPS-In-TCP" -Profile Any -LocalPort 5986 `
     -Protocol TCP -Action Allow -Direction Inbound -ErrorAction SilentlyContinue
   ```

4. **From your machine, test again:**

   ```powershell
   Test-WSMan server01 -UseSSL -Port 5986 -SkipCACheck -SkipCNCheck
   ```

   **Expected output:**
   ```
   wsmid           : http://schemas.dmtf.org/wbem/wsman/identity/identity.xsd
   ProtocolVersion : http://schemas.dmtf.org/wbem/wsmanidentity/1.0.0
   ```

---

### `Error: Cannot resolve server hostname`

**Problem:** `Test-WSMan server01` fails with: "Cannot find the target computer name."

**Cause:** DNS can't resolve the server name, or the server is offline.

**Solution:**

1. **Verify the server is online:**
   ```powershell
   ping server01
   ```

2. **Check DNS can resolve it:**
   ```powershell
   nslookup server01
   ```

3. **Try the FQDN (fully qualified domain name):**
   ```powershell
   Test-WSMan server01.contoso.com -UseSSL -Port 5986 -SkipCACheck -SkipCNCheck
   ```

4. **Try the IP address:**
   ```powershell
   Test-WSMan 192.168.1.10 -UseSSL -Port 5986 -SkipCACheck -SkipCNCheck
   ```

5. **Check your DNS settings:**
   ```powershell
   ipconfig /all | grep DNS
   ```

---

### `Error: Access denied`

**Problem:** ServerWhisperer can reach the server but gets "access denied" errors.

**Cause:** Your user account doesn't have admin rights on the target.

**Solution 1: Verify admin rights**

On **target server**, check if your user is admin:

```powershell
net localgroup Administrators
```

Your user should be listed. If not, and you have local admin, add them:

```powershell
net localgroup Administrators domain\username /add
```

**Solution 2: Use explicit credentials**

Create a `$credential` variable before starting Copilot:

```powershell
$credential = Get-Credential
gh copilot
```

```
? "Check server01"
```

The agent will automatically use the `$credential` for the connection.

---

### `Error: Server certificate invalid`

**Problem:** Connection fails with: "Server certificate validation failed."

**Cause:** WinRM is using a self-signed certificate (normal) but your machine doesn't trust it.

**Solution:**

All ServerWhisperer connections use `-SkipCACheck -SkipCNCheck`, which handles this automatically. If you see this error anyway:

```powershell
# From your machine, test with the right flags:
$SessionOption = New-PSSessionOption -SkipCACheck -SkipCNCheck
Test-WSMan server01 -UseSSL -Port 5986 -SessionOption $SessionOption
```

---

## After Connection Issues

### `Error: Unable to connect to server01` (from ServerWhisperer)

**Checklist:**

{: .important }
> Verify each step in order before moving to the next:

1. ✅ Server name/IP is correct: `ping server01`
2. ✅ Server is online and reachable
3. ✅ PowerShell remoting enabled on target: `Enable-PSRemoting -Force`
4. ✅ WinRM service running on target: `Get-Service WinRM`
5. ✅ Firewall allows port 5986 on target
6. ✅ Test from your machine: `Test-WSMan server01 -UseSSL -Port 5986 -SkipCACheck -SkipCNCheck`
7. ✅ You have admin rights on target (or saved credentials with Export-Clixml)

If all of these pass, try your investigation again.

---

### `Error: WinRM is not responding`

**Problem:** ServerWhisperer times out or fails with WinRM errors.

**Solution:**

1. **On target server, restart WinRM:**

   ```powershell
   Stop-Service WinRM -Force
   Start-Service WinRM
   ```

2. **Re-enable PowerShell remoting:**

   ```powershell
   Enable-PSRemoting -Force
   winrm quickconfig -q
   ```

3. **From your machine, verify Test-WSMan works:**

   ```powershell
   Test-WSMan server01 -UseSSL -Port 5986 -SkipCACheck -SkipCNCheck
   ```

4. **Then try your investigation again.**

---

## Runtime Issues

### Investigation is taking longer than expected

**Problem:** You expected 30-60 seconds but it's taking 2+ minutes.

**Cause:** Several slow diagnostics may be running (Event Logs, Roles/Features). Or the target server is under heavy load and responses are slow.

**Solution:**

1. **This is expected for full investigations:**
   - Event Logs diagnostic can take 15-60s depending on log size
   - Roles/Features diagnostic can take 10-30s
   - If running both in parallel, worst case is 60s total (not sequential)
   - Compare to sequential mode: would take 2-3 minutes

2. **If consistently slow (>2 minutes):**
   - Target server may be under heavy load
   - Check server responsiveness:
     ```powershell
     ping server01
     Get-Process -ComputerName server01 | Sort-Object CPU -Descending | Select-Object -First 5
     ```
   - Try a focused investigation instead:
     ```
     ? "Check server01's disk"  ← Faster than full investigation
     ```

3. **Background jobs continue running:**
   - Slow diagnostics run in the background
   - You see fast results immediately
   - Slow results arrive as they complete
   - This is intentional — provides value without waiting

{: .note }
> **Timing reference:** Overview + Disk + Network in parallel = ~10-15 seconds. Add Event Logs = ~40-60 seconds total. All jobs run concurrently, not sequentially.

---

### Job timed out after 120 seconds

**Problem:** Full investigation fails with "Operation timed out" after ~2 minutes.

**Cause:** One or more background jobs exceeded the 120-second timeout. This can happen when:
- Target server is overloaded (CPU/memory maxed)
- Event log is very large (thousands of entries)
- Network latency is high
- Roles/Features enumeration is slow

**Solution:**

1. **Check target server load:**
   ```powershell
   Get-Process -ComputerName server01 | Sort-Object CPU -Descending | Select-Object -First 5
   Get-CimInstance Win32_OperatingSystem -ComputerName server01 | Select-Object Name, TotalVisibleMemorySize, FreePhysicalMemory
   ```

2. **If server is overloaded:**
   - Wait 5-10 minutes and try again
   - Or investigate specific area instead of full investigation

3. **Try a focused investigation first:**
   ```
   ? "Check server01's disk"          ← Fast, no timeout risk
   ? "What services are running?"      ← Fast
   ? "Check performance on server01"   ← Moderate speed
   ```

4. **For Event Log analysis:**
   - Full Event Log search can take time on large servers
   - Try specifying a time window:
     ```
     ? "Show errors on server01 from the last hour"
     ```

{: .warning }
> If a single diagnostic consistently times out, there may be a connectivity or server issue. Try the troubleshooting steps in **Connection Issues** section above.

---

### Partial results — some diagnostics succeeded, others failed

**Problem:** Investigation completes but shows "Failed to collect [diagnostic name]" or similar errors.

**Cause:** Background jobs run independently. One or more may fail due to:
- Insufficient permissions (can't read Security event log, for example)
- PowerShell module missing on target
- Network interruption mid-job
- Target server process killed mid-operation

**Solution:**

This is **normal and expected**. ServerWhisperer is designed to handle partial failure gracefully:

1. **Successful diagnostics are reported normally** — you get findings for those
2. **Failed diagnostics are noted** — report shows which ones failed and why
3. **Continue with actionable findings** — act on what succeeded

**Example partial result:**
```
Findings collected:
  ✅ Overview — Success
  ✅ Disk — Success
  ✅ Services — Success
  ⚠️  Event Logs — Failed (access denied to Security log)
  ✅ Network — Success
  ❌ Roles/Features — Timed out (10s elapsed)

Report shows: Overview, Disk, Services, Network findings
Note: Event Logs and Roles/Features partial/failed — not included in report
```

**If a critical diagnostic fails consistently:**

1. Check permissions (ensure admin/elevated rights):
   ```powershell
   $credential = Get-Credential  # Use explicit admin credentials
   gh copilot
   ```

2. Try a simpler investigation:
   ```
   ? "What is going on with server01?"  ← Tries fewer diagnostics
   ```

3. If Event Log access denied, verify admin rights on target:
   ```powershell
   net localgroup Administrators | findstr /I "youruser"
   ```

---

## Network / Firewall Issues

### `Firewall blocks port 5986`

**On target server, verify the rule exists:**

```powershell
Get-NetFirewallRule -DisplayName "*WinRM*" | Select-Object DisplayName, Enabled
```

If you don't see an enabled rule for port 5986, create one:

```powershell
New-NetFirewallRule -DisplayName "WinRM HTTPS" `
  -Name "WINRM-HTTPS-In-TCP" -Profile Any -LocalPort 5986 `
  -Protocol TCP -Action Allow -Direction Inbound
```

Then test from your machine:

```powershell
Test-WSMan server01 -UseSSL -Port 5986 -SkipCACheck -SkipCNCheck
```

---

### Servers on Different Networks

If your machine and target servers are on different networks (e.g., datacenter behind a proxy):

1. Ensure network routing permits HTTPS traffic on port 5986
2. Verify no proxy is blocking the connection (proxies often block remoting)
3. Try the IP address instead of hostname
4. Contact network admin if firewalls block the connection

---

## Escalation Guide

When ServerWhisperer identifies issues but can't fix them, here's who to contact:

| Issue | Escalate To | What to Share |
|-------|-------------|-------------------|
| Service needs restart | On-call admin | Server name, service name, error events |
| Disk critically full | Infrastructure | Drive letter, free space, largest folders |
| Database issues | DBA | SQL instance, memory usage, error events |
| Security events | Security team | Event IDs, timestamps, affected accounts |
| Hardware failure | Infrastructure | Disk health, SMART data, error counts |
| Application crash | App owner | Process name, PID, error events |
| Network issues | Network admin | Adapter status, DNS config, open ports |

Always share the ServerWhisperer report — it gives the specific data responders need.

---

_Built by the ServerWhisperer team._
