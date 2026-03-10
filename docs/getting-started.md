---
layout: default
title: Getting Started
nav_order: 1
description: "Step-by-step setup for complete beginners. Install GitHub CLI, authenticate, clone the repo, run your first investigation."
---

# Getting Started
{: .no_toc }

**Complete beginner walkthrough.** We'll get you from zero to your first investigation in 5 minutes.
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

## What You'll Need

Before you start, make sure you have:

- ✅ **A Windows machine** (your local desktop or laptop)
- ✅ **Admin access to at least one Windows Server** you want to investigate
- ✅ **Internet connection** (to download tools and authenticate)
- ✅ **A free GitHub account** (sign up at https://github.com if needed)

---

## Step 0: Verify PowerShell

Open PowerShell on your local machine and check the version:

```powershell
$PSVersionTable.PSVersion
```

Expected output: `5.1` or higher (e.g., `7.4.0`)

If you see an older version, you can upgrade to PowerShell 7+ from: https://github.com/PowerShell/PowerShell/releases

---

## Step 1: Install GitHub CLI

GitHub CLI is the tool that runs Copilot. Install it:

**Windows (PowerShell):**

```powershell
winget install GitHub.cli
```

**Or download:** https://cli.github.com/

**Verify the installation:**

```bash
gh --version
```

Expected output: `gh version 2.X.X (YYYY-MM-DD)`

If this fails, restart PowerShell and try again.

---

## Step 2: Authenticate with GitHub

Now authenticate with GitHub so that `gh` can access the Copilot extension:

```bash
gh auth login
```

You'll see prompts:

```
? What account do you want to log into?
› GitHub.com

? What is your preferred protocol for Git operations?
› HTTPS

? Authenticate Git with your GitHub credentials?
› Y

? How would you like to authenticate GitHub CLI?
› Login with a web browser (recommended)
```

A browser window will open. Click **Authorize GitHub CLI** and you're done.

**Back in PowerShell, you should see:**

```
✓ Authentication complete. You're ready to use GitHub CLI.
```

---

## Step 3: Install the Copilot CLI Extension

```bash
gh extension install github/gh-copilot
```

**Expected output:**

```
✓ Installation complete
```

Verify it:

```bash
gh copilot --version
```

---

## Step 4: Clone ServerWhisperer

```bash
gh repo clone anwather/ServerWhisperer
cd ServerWhisperer
```

This creates a folder and copies all the agent instructions and diagnostic skills.

---

## Step 4.5: Run the Setup Script

{: .important }
> **Run this FIRST after cloning!** This removes development files you don't need as an end user.

```powershell
.\Setup.ps1
```

The setup script will:
- Remove development artifacts (`.squad/` folder, GitHub Pages files, etc.)
- Keep everything you need for investigations
- Show you a summary of what was removed
- Tell you the next steps

After running the script, you'll have a clean installation ready to use.

**No separate skill installation needed!** When you run `gh copilot` in this directory, the `.github/copilot-instructions.md` file is automatically loaded with all diagnostic skill PowerShell code embedded. Everything just works out of the box.

---

## Step 5: Enable PowerShell Remoting on Target Servers

{: .important }
> **This is a one-time setup per target server.** You need local admin rights.

On **each target Windows Server**, open PowerShell as Administrator and run:

```powershell
Enable-PSRemoting -Force
winrm quickconfig -q
```

Expected output:

```
WinRM has been updated for remote management.
WinRM service type changed successfully.
WinRM service started.
```

**Verify it's enabled** (run this from YOUR machine):

```powershell
Test-WSMan server01 -UseSSL -Port 5986 -SkipCACheck -SkipCNCheck
```

Replace `server01` with your actual server name or IP address.

**Expected output:**

```
wsmid           : http://schemas.dmtf.org/wbem/wsman/identity/identity.xsd
ProtocolVersion : http://schemas.dmtf.org/wbem/wsmanidentity/1.0.0
ProductVendor   : Microsoft Corporation
ProductVersion  : 10.0.17763.1
```

If this fails, see the [Troubleshooting](#troubleshooting) section below.

---

## Setting Up Credentials

ServerWhisperer needs credentials to connect to your servers. There are two approaches:

### Default: Current User (No Setup Needed)

If your Windows machine is domain-joined and you have admin rights on the target servers, 
**no credential setup is needed**. ServerWhisperer uses your current user identity automatically.

```
User: "What is going on with server01?"
→ Connects using your current Windows identity (seamless)
```

### Explicit: File-Based Encrypted Credentials

When connecting to servers where you need different credentials (like Azure VMs, cross-domain servers, or workgroup servers), 
you must **save credentials to an encrypted file ONE TIME** before using ServerWhisperer.

**How to set up credentials (one-time):**

1. Open your PowerShell terminal
2. Create the credentials directory:
   ```powershell
   New-Item -ItemType Directory -Path "$HOME\.serverwhisperer" -Force
   ```
3. Save your credentials to an encrypted file:
   ```powershell
   Get-Credential | Export-Clixml -Path "$HOME\.serverwhisperer\credentials.xml"
   ```
4. A **secure Windows login dialog** will appear
5. Enter your username and password in the dialog (NOT in the chat)
6. The password is entered securely and encrypted using DPAPI (tied to your user + machine)
7. The encrypted file is saved to `$HOME\.serverwhisperer\credentials.xml`
8. Start `gh copilot` — the agent will load the credentials automatically when needed

**What the dialog looks like:**
- A standard Windows credential prompt window pops up
- Title: "Windows PowerShell credential request"
- Fields: Username and Password (hidden dots)
- You type the password there, NOT in the Copilot chat

**Security benefits:**
- **DPAPI encryption** — Only you on this machine can decrypt the file
- **Not portable** — File cannot be moved between machines or users (by design)
- **Never in chat** — Passwords never appear in chat history
- **Standard PowerShell pattern** — Used in enterprise automation for years

**If the agent needs credentials and you haven't created the file:**
The agent will tell you:
```
⚠️ No saved credentials found.

To save credentials for server connections, run:
  New-Item -ItemType Directory -Path "$HOME\.serverwhisperer" -Force
  Get-Credential | Export-Clixml -Path "$HOME\.serverwhisperer\credentials.xml"

Then ask me again and I'll load the saved credentials.
```

**Multiple servers with different credentials:**
You can create server-specific credential files:
```powershell
Get-Credential | Export-Clixml -Path "$HOME\.serverwhisperer\server01-cred.xml"
Get-Credential | Export-Clixml -Path "$HOME\.serverwhisperer\azure-vm-cred.xml"
```
The agent will check for server-specific credentials first, then fall back to the default `credentials.xml`.

⚠️ **IMPORTANT SECURITY NOTE:** Never type passwords in the Copilot CLI chat. Passwords typed 
in the conversation are visible in plain text and stored in chat history. Always create credential 
files using Export-Clixml outside of Copilot CLI.

---

## Verify Your Setup

Before your first investigation, run these checks to make sure everything is ready:

### ✅ Check 1: Is gh installed?

```bash
gh --version
```

Should show: `gh version 2.X.X (YYYY-MM-DD)`

### ✅ Check 2: Are you authenticated?

```bash
gh auth status
```

Should show: `Logged in to github.com as YOUR-USERNAME`

### ✅ Check 3: Is Copilot CLI extension installed?

```bash
gh extension list | grep copilot
```

Should show: `github/gh-copilot` in the list

### ✅ Check 4: Is ServerWhisperer cloned?

```bash
cd ServerWhisperer
ls
```

Should show files like `README.md`, `.squad/`, `docs/`, etc.

### ✅ Check 5: Can you reach your target server?

From **your local machine**:

```bash
Test-WSMan server01 -UseSSL -Port 5986 -SkipCACheck -SkipCNCheck
```

Should show protocol and product info (see Step 5 above for example output).

---

## Your First Investigation

Now you're ready! Open PowerShell in the ServerWhisperer folder and start an interactive session:

```bash
cd ServerWhisperer
gh copilot
```

You'll see a prompt asking what you need help with. Just ask a question about your server:

```
? What would you like help with?
> What is going on with server01?
```

ServerWhisperer will:

1. Connect to server01 using your current Windows credentials
2. Run quick diagnostics (disk space, memory, services, etc.)
3. Return a structured report

### Example Output

```
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

server01 is mostly healthy but has two concerns: disk space is critically
low at 92% full, and memory is elevated at 78%. Prioritize freeing disk
space to prevent application failures, then monitor memory trends.

Next steps: Clean C:\Temp and C:\Windows\Temp directories, then review
IIS logs for archival.
```

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔍 WIN-INVESTIGATOR REPORT
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

server01 is mostly healthy but has two concerns: disk space is critically
low at 92% full, and memory is elevated at 78%. Prioritize freeing disk
space to prevent application failures, then monitor memory trends.

Next steps: Clean C:\Temp and C:\Windows\Temp directories, then review
IIS logs for archival.
```

---

## Troubleshooting

### `gh command not found`

**Problem:** PowerShell doesn't recognize the `gh` command.

**Solution:**

1. Verify installation: `gh --version`
2. If that fails, download from: https://cli.github.com/
3. Restart PowerShell after installing
4. Try again: `gh --version`

### `Extension not installed: copilot`

**Problem:** `gh extension list` doesn't show the copilot extension.

**Solution:**

```bash
gh extension install github/gh-copilot
```

If you get an error, make sure you're authenticated:

```bash
gh auth status
```

If not authenticated, run: `gh auth login`

### `Error: Unable to authenticate`

**Problem:** `gh auth login` fails or `gh auth status` shows "not logged in".

**Solution:**

```bash
gh auth logout
gh auth login
```

Follow the prompts to authenticate with GitHub via web browser.

### `Test-WSMan: Unable to connect to the remote host`

**Problem:** Your machine can't reach the target server on port 5986.

**Solution (on target server):**

1. **Re-enable PowerShell remoting:**

   ```powershell
   Enable-PSRemoting -Force
   winrm quickconfig -q
   ```

2. **Check the WinRM service is running:**

   ```powershell
   Get-Service WinRM
   ```

   If it shows "Stopped", start it:

   ```powershell
   Start-Service WinRM
   ```

3. **Check Windows Firewall allows port 5986:**

   ```powershell
   Get-NetFirewallRule -DisplayName "WinRM HTTPS" -ErrorAction SilentlyContinue | Select-Object DisplayName, Enabled
   ```

   If you don't see it, or it's disabled, create it:

   ```powershell
   New-NetFirewallRule -DisplayName "WinRM HTTPS" -Name "WINRM-HTTPS-In-TCP" -Profile Any -LocalPort 5986 -Protocol TCP -Action Allow -Direction Inbound
   ```

4. **Try Test-WSMan again from your machine:**

   ```powershell
   Test-WSMan server01 -UseSSL -Port 5986 -SkipCACheck -SkipCNCheck
   ```

### `Error: Access denied`

**Problem:** ServerWhisperer can reach the server but can't run commands.

**Solution:**

1. **Verify your user is admin on the target:**

   ```powershell
   net localgroup Administrators
   ```

   Your user should be listed. If not, add them (requires admin on target):

   ```powershell
   net localgroup Administrators domain\username /add
   ```

2. **Or use explicit credentials:**

   When ServerWhisperer asks a question, mention credentials:

   ```
   ? "Check server01 with domain\admin credentials"
   ```

   It will prompt for a password.

### `Error: Cannot resolve server hostname`

**Problem:** `Test-WSMan` fails with: "Cannot find the target computer name".

**Solution:**

1. **Verify the server name is correct:**

   ```powershell
   # Try ping
   ping server01
   ```

2. **Try the FQDN instead of short name:**

   ```powershell
   Test-WSMan server01.contoso.com -UseSSL -Port 5986 -SkipCACheck -SkipCNCheck
   ```

3. **Try the IP address instead:**

   ```powershell
   Test-WSMan 192.168.1.10 -UseSSL -Port 5986 -SkipCACheck -SkipCNCheck
   ```

4. **Check your DNS settings:**

   ```powershell
   nslookup server01
   ```

---

## Next Steps

Once you've verified your setup and run your first investigation:

- [Learn how to ask better questions →](/ServerWhisperer/usage)
- [See what diagnostics are available →](/ServerWhisperer/diagnostics)
- [Check out example sessions →](/ServerWhisperer/examples)

---

_Built by the ServerWhisperer team._
