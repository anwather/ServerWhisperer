---
layout: default
title: Automated Investigations
nav_order: 7
description: "How to configure ServerWhisperer to run automatically from Azure Monitor alerts via GitHub Actions"
---

# Automated Investigations
{: .no_toc }

**Trigger ServerWhisperer automatically when Azure Monitor alerts fire — fast diagnostics without manual intervention.**
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

## Overview

By default, ServerWhisperer runs **interactively** through the Copilot CLI — you ask a question, get a report. This page explains how to extend it to run **automatically** when Azure Monitor alerts fire.

### When to Use Automated Investigations

Automated investigations are ideal for:

- **After-hours alerts** — When your on-call team is unavailable, get an automated diagnostic in real time
- **Proactive health checks** — Run diagnostics automatically on alert thresholds without waiting for a human
- **Escalation workflows** — Alert → Issue → Diagnostics → Notification (all automated)
- **SLA monitoring** — Production systems that need fast response (seconds, not minutes)
- **Trend analysis** — Collect diagnostics automatically for trending and root cause analysis

### Limitations

Automated investigations require:

- GitHub Actions enabled in your repository
- Network access from GitHub Actions runners to your servers (public IP or self-hosted runner)
- Azure Key Vault to store server credentials securely
- Azure AD OIDC federation configured

This is an **advanced feature** — start with interactive mode first, then add automation as your confidence grows.

---

## Architecture

Here's how the end-to-end automation flow works:

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. Azure Alert Fires                                            │
│    CPU > 90%, Memory > 85%, Disk > 90%, Service down, etc.     │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. Azure Monitor Action Group                                   │
│    Sends webhook to GitHub repository_dispatch endpoint         │
│    Includes: server name, alert type, severity, timestamp       │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. GitHub repository_dispatch Event                             │
│    Triggers workflow with alert payload                         │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. GitHub Actions Workflow                                      │
│    • Authenticate to Azure via OIDC (no stored secrets)         │
│    • Pull server credentials from Azure Key Vault               │
│    • Run PowerShell diagnostics against target server           │
│    • Collect results in structured format                       │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│ 5. Create or Update GitHub Issue                                │
│    • Issue title: "[ALERT] High CPU on server01 (Sev2)"         │
│    • Issue body: Diagnostic results + findings + next steps     │
│    • Comment with full report                                   │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│ 6. Notification (GitHub, Slack, Email, etc.)                    │
│    Team is alerted that diagnostics are available               │
└─────────────────────────────────────────────────────────────────┘
```

### Why Not Store Secrets in GitHub?

**You should NOT store server credentials in GitHub Secrets.** Instead:

1. **Azure Key Vault** stores the server admin credential securely
2. **OIDC workload identity federation** allows GitHub Actions to authenticate to Azure without long-lived secrets
3. **GitHub Actions** pulls the credential from Key Vault at runtime — it never appears in logs or repository
4. **Credential is used once** — deleted from the runner memory after diagnostics complete

This is the **recommended enterprise pattern** and requires zero credential rotation.

---

## Example Alert Triggers

These Azure Monitor alert scenarios are perfect for automated investigation:

### CPU/Memory Alerts

| Alert Type | Configuration | Why Investigate |
|------------|----------------|-----------------|
| **High CPU Usage** | CPU > 90% for 5 minutes | Identify runaway processes; may cause cascade failures |
| **High Memory Usage** | Memory > 85% for 10 minutes | Check for memory leaks; slow disk paging indicates trouble |
| **CPU Spike** | CPU goes from 20% to 80%+ in 2 minutes | Sudden behavior change suggests new workload or runaway process |

**Example alert rule:**
```
Metric: Percentage CPU
Threshold: > 90%
Duration: 5 minutes
Frequency: Every 1 minute
```

### Disk Space Alerts

| Alert Type | Configuration | Why Investigate |
|------------|----------------|-----------------|
| **Low Disk Space** | OS disk < 10% free | Immediate risk: apps may fail to write temp files, event logs may stop |
| **Rapid Disk Growth** | Free space decreased by 5 GB in 1 hour | Identify runaway processes (logs, temp files, app caches) |

**Example alert rule:**
```
Metric: Available Disk Space
Threshold: < 10% of total volume
Duration: 2 minutes
Frequency: Every 1 minute
```

### Service Health Alerts

| Alert Type | Configuration | Why Investigate |
|------------|----------------|-----------------|
| **Windows Service Stopped** | SQL Server / IIS / Custom Service = Stopped | Business impact; get state ASAP for recovery |
| **Service Restart Loop** | Service restarts 3+ times in 5 minutes | Diagnostic failure; get event logs and recent errors |

**Example alert rule (via Data Collection Rule):**
```
Event Log: System
Event ID: 7030 (Service Control Manager error)
OR Event ID: 7031 (Service crashed/hung)
Collect logs when triggered
```

### Heartbeat/Availability Alerts

| Alert Type | Configuration | Why Investigate |
|------------|----------------|-----------------|
| **Heartbeat Missing** | VM heartbeat gap > 5 minutes | Server may be hung, overloaded, or disconnected |
| **Ping Timeout** | Target unreachable for 3 minutes | Network issue or server offline |

**Example alert rule:**
```
Metric: Heartbeat (Azure Monitor Agent)
Condition: Missed heartbeat > 5 minutes
Frequency: Every 2 minutes
```

### Performance Degradation Alerts

| Alert Type | Configuration | Why Investigate |
|------------|----------------|-----------------|
| **Response Time Spike** | App response time > 2 seconds (baseline 0.5s) | Identify bottleneck: database, CPU, disk I/O |
| **Disk Latency High** | Avg. disk read/write latency > 50ms | Storage performance degradation; affects all operations |

### Event Log Alerts

| Alert Type | Configuration | Why Investigate |
|------------|----------------|-----------------|
| **Critical/Error Events** | System or Application log: Severity = Critical or Error | Root cause of issues often in event logs |
| **Repeated Errors** | Same error > 5 times in 10 minutes | Pattern indicates systemic problem, not transient |

**Example alert rule (via Data Collection Rule):**
```
Event Log: System + Application
Event Level: Critical, Error
Condition: More than 5 events in 10 minutes
Action: Trigger webhook
```

### Network Alerts

| Alert Type | Configuration | Why Investigate |
|------------|----------------|-----------------|
| **Packet Loss** | Packet loss > 5% for 2 minutes | Network instability; may cause connection failures |
| **Connection Failures** | Failed connections spike 10x baseline | Firewall rule, network path, or destination issue |

---

## Prerequisites

Before setting up automated investigations, ensure you have:

### Azure Requirements

- ✅ Active **Azure subscription**
- ✅ **Azure Monitor** configured with alert rules
- ✅ **Azure Key Vault** (to store server credentials)
- ✅ **Azure AD app registration** (for OIDC federation)
- ✅ **Microsoft Entra OIDC provider** configured

### GitHub Requirements

- ✅ GitHub repository with **Actions enabled**
- ✅ GitHub account with **repo admin access**
- ✅ PAT (Personal Access Token) with `repo` scope for webhook (optional but recommended)

### Target Server Requirements

- ✅ Windows Server 2012 R2+ or Windows 10+
- ✅ **PowerShell Remoting enabled** (`Enable-PSRemoting -Force`)
- ✅ **WinRM HTTPS on port 5986** (or HTTP on 5985 if on same network)
- ✅ **Network access from GitHub Actions runner** (public IP or self-hosted runner in VNET)
- ✅ **Server credentials stored in Azure Key Vault** (username + password as separate secrets)

### Local Development Requirements

- ✅ Azure CLI (`az` command)
- ✅ PowerShell 5.1+ or PowerShell 7+

---

## Configuration Steps

### Step 1: Set Up Azure Key Vault

Store your server credentials in Azure Key Vault so they're never stored in GitHub.

#### 1a. Create a Key Vault (if you don't have one)

```bash
# Using Azure CLI
az keyvault create --resource-group <YourResourceGroup> \
  --name <YourKeyVaultName> \
  --location <Region>

# Example:
az keyvault create --resource-group my-rg \
  --name mycompany-kv \
  --location eastus
```

#### 1b. Store Server Credentials as Secrets

```bash
# Create secret for server admin username
az keyvault secret set --vault-name <YourKeyVaultName> \
  --name "server-admin-username" \
  --value "domain\admin"

# Create secret for server admin password
az keyvault secret set --vault-name <YourKeyVaultName> \
  --name "server-admin-password" \
  --value "YourComplexPassword123!"

# List secrets to verify
az keyvault secret list --vault-name <YourKeyVaultName>
```

{: .note }
> Store the **username** and **password as separate secrets** so you can grant different access levels if needed. Use strong passwords (30+ characters, mix of upper/lower/numbers/symbols).

#### 1c. Note Your Key Vault URL

You'll need this in the GitHub Actions workflow. It looks like:
```
https://<YourKeyVaultName>.vault.azure.net/
```

### Step 2: Configure OIDC Workload Identity Federation

This allows GitHub Actions to authenticate to Azure **without storing secrets in GitHub**.

#### 2a. Create an Azure AD App Registration

```bash
# Create app registration
az ad app create --display-name "serverwhisperer-automation"

# Get the app ID (you'll need this)
APP_ID=$(az ad app list --query "[?displayName=='serverwhisperer-automation'].appId" -o tsv)
echo "App ID: $APP_ID"
```

#### 2b. Create a Service Principal

```bash
az ad sp create --id $APP_ID

# Get the service principal object ID
SPOBJ=$(az ad sp show --id $APP_ID --query id -o tsv)
echo "Service Principal Object ID: $SPOBJ"
```

#### 2c. Grant Key Vault Access

```bash
# Give the service principal access to read Key Vault secrets
az role assignment create --role "Key Vault Secrets User" \
  --assignee-object-id $SPOBJ \
  --assignee-principal-type ServicePrincipal \
  --scope "/subscriptions/<YourSubscriptionID>/resourcegroups/<YourResourceGroup>/providers/Microsoft.KeyVault/vaults/<YourKeyVaultName>"

# Example:
az role assignment create --role "Key Vault Secrets User" \
  --assignee-object-id $SPOBJ \
  --assignee-principal-type ServicePrincipal \
  --scope "/subscriptions/12345678-1234-1234-1234-123456789012/resourcegroups/my-rg/providers/Microsoft.KeyVault/vaults/mycompany-kv"
```

#### 2d. Configure OIDC Federation

Tell Azure AD to trust GitHub Actions workflows from your repository.

```bash
# Get your GitHub repo details
GITHUB_OWNER="anwather"  # Your GitHub username/org
GITHUB_REPO="ServerWhisperer"  # Your repo name

# Create OIDC federation credential
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-actions-credential",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'"$GITHUB_OWNER"'/'"$GITHUB_REPO"':ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Verify the credential was created
az ad app federated-credential list --id $APP_ID
```

### Step 3: Create GitHub Repository Secrets

Store Azure credentials as GitHub repository secrets (used only for the OIDC handshake).

```bash
# Get your Azure subscription ID and tenant ID
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

echo "AZURE_CLIENT_ID: $APP_ID"
echo "AZURE_TENANT_ID: $TENANT_ID"
echo "AZURE_SUBSCRIPTION_ID: $SUBSCRIPTION_ID"
```

Add these as **GitHub repository secrets** (Settings → Secrets → New repository secret):

| Secret Name | Value |
|-------------|-------|
| `AZURE_CLIENT_ID` | App registration ID (from step 2a) |
| `AZURE_TENANT_ID` | Azure AD tenant ID (from above) |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID (from above) |
| `AZURE_KEYVAULT_NAME` | Key Vault name (from step 1c) |

Optional (for manual webhook testing):

| Secret Name | Value |
|-------------|-------|
| `GITHUB_PAT` | GitHub PAT with `repo` scope (only if not using OIDC for webhook) |

### Step 4: Create the GitHub Actions Workflow

Create a new workflow file at `.github/workflows/alert-investigation.yml`:

```yaml
name: Alert Investigation

on:
  repository_dispatch:
    types: [azure-alert]

jobs:
  investigate:
    runs-on: windows-latest
    permissions:
      id-token: write        # For OIDC
      contents: read         # To access repo
      issues: write          # To create/comment on issues
    
    steps:
      - uses: actions/checkout@v4
      
      # Authenticate to Azure using OIDC (no long-lived secrets)
      - uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      
      # Retrieve server credentials from Key Vault
      - name: Get server credentials from Key Vault
        id: keyvault
        run: |
          $kv_name = "${{ secrets.AZURE_KEYVAULT_NAME }}"
          $username = az keyvault secret show --name "server-admin-username" --vault-name $kv_name --query value -o tsv
          $password = az keyvault secret show --name "server-admin-password" --vault-name $kv_name --query value -o tsv
          
          # Create PSCredential object
          $securePass = $password | ConvertTo-SecureString -AsPlainText -Force
          $credential = New-Object System.Management.Automation.PSCredential($username, $securePass)
          
          # Export for next steps
          "username=$username" | Out-File -FilePath $Env:GITHUB_OUTPUT -Encoding utf8 -Append
        shell: pwsh
      
      # Extract alert details from webhook payload
      - name: Parse alert details
        id: alert
        run: |
          $payload = ${{ toJson(github.event.client_payload) }}
          $alert = $payload | ConvertFrom-Json
          
          $server = $alert.server
          $alertName = $alert.alert_name
          $severity = $alert.severity
          $description = $alert.description
          $timestamp = $alert.timestamp
          
          "server=$server" | Out-File -FilePath $Env:GITHUB_OUTPUT -Encoding utf8 -Append
          "alert_name=$alertName" | Out-File -FilePath $Env:GITHUB_OUTPUT -Encoding utf8 -Append
          "severity=$severity" | Out-File -FilePath $Env:GITHUB_OUTPUT -Encoding utf8 -Append
          "description=$description" | Out-File -FilePath $Env:GITHUB_OUTPUT -Encoding utf8 -Append
          "timestamp=$timestamp" | Out-File -FilePath $Env:GITHUB_OUTPUT -Encoding utf8 -Append
        shell: pwsh
      
      # Run ServerWhisperer diagnostics
      - name: Run diagnostics
        id: diagnostics
        run: |
          # Clone the repo with diagnostics skills
          git clone https://github.com/${{ github.repository }}.git ServerWhisperer
          cd ServerWhisperer
          
          # Example: Run an overview diagnostic
          $server = "${{ steps.alert.outputs.server }}"
          $username = "${{ steps.keyvault.outputs.username }}"
          
          # Create PSCredential from stored username and Key Vault password
          # (In real workflow, retrieve password from Key Vault again or store securely)
          
          Write-Host "Running diagnostics on server: $server"
          Write-Host "Alert: ${{ steps.alert.outputs.alert_name }}"
          Write-Host "Severity: ${{ steps.alert.outputs.severity }}"
          
          # TODO: Integrate ServerWhisperer's diagnostic skills here
          # For now, placeholder that shows structure
          $diagnosticResult = @{
            server = $server
            status = "🟡 Warning"
            findings = @(
              "Finding 1: [Description]",
              "Finding 2: [Description]"
            )
            summary = "Automated diagnostic complete"
            timestamp = Get-Date -Format "o"
          }
          
          $diagnosticJson = $diagnosticResult | ConvertTo-Json
          "result=$($diagnosticJson | ConvertTo-Json -Compress)" | Out-File -FilePath $Env:GITHUB_OUTPUT -Encoding utf8 -Append
        shell: pwsh
      
      # Create or update GitHub Issue with results
      - name: Create issue from alert
        uses: actions/github-script@v7
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          script: |
            const server = "${{ steps.alert.outputs.server }}";
            const alertName = "${{ steps.alert.outputs.alert_name }}";
            const severity = "${{ steps.alert.outputs.severity }}";
            const description = "${{ steps.alert.outputs.description }}";
            const timestamp = "${{ steps.alert.outputs.timestamp }}";
            
            const title = `[ALERT] ${alertName} on ${server} (${severity})`;
            const body = `
            **Alert Details**
            - Server: ${server}
            - Alert: ${alertName}
            - Severity: ${severity}
            - Description: ${description}
            - Detected: ${timestamp}
            - Automated: Yes (triggered by Azure Monitor)
            
            **Investigation Results**
            \`\`\`
            ${{ steps.diagnostics.outputs.result }}
            \`\`\`
            
            ---
            *This issue was automatically created by ServerWhisperer Alert Automation workflow*
            `;
            
            // Search for existing issue with same alert on same server
            const issues = await github.rest.issues.listForRepo({
              owner: context.repo.owner,
              repo: context.repo.repo,
              state: "open",
              labels: ["automated-alert"],
              per_page: 100
            });
            
            let existingIssue = issues.data.find(i => 
              i.title.includes(alertName) && i.title.includes(server)
            );
            
            if (existingIssue) {
              // Comment on existing issue
              await github.rest.issues.createComment({
                owner: context.repo.owner,
                repo: context.repo.repo,
                issue_number: existingIssue.number,
                body: `**New occurrence detected at ${timestamp}**\n\n${body}`
              });
              console.log(`Commented on existing issue #${existingIssue.number}`);
            } else {
              // Create new issue
              const newIssue = await github.rest.issues.create({
                owner: context.repo.owner,
                repo: context.repo.repo,
                title: title,
                body: body,
                labels: ["automated-alert", "azure-alert"]
              });
              console.log(`Created new issue #${newIssue.data.number}`);
            }
```

{: .note }
> This is a **template workflow**. You'll need to:
> 1. Replace placeholder diagnostic code with actual ServerWhisperer skill execution
> 2. Adapt to your specific server naming, credential patterns, and alert payload format
> 3. Test in a non-production environment first

### Step 5: Configure Azure Monitor Action Group

Create an **Action Group** in Azure Monitor to send alerts to GitHub.

#### 5a. Create Action Group

```bash
az monitor action-group create --name "github-webhook" \
  --resource-group <YourResourceGroup>
```

#### 5b. Add Webhook Action

You have two options:

**Option A: Using GitHub PAT (simpler, less secure)**

```bash
# Store your GitHub PAT in Key Vault first
az keyvault secret set --vault-name <YourKeyVaultName> \
  --name "github-pat" \
  --value "ghp_YourPersonalAccessToken123..."

# Configure webhook in Action Group
az monitor action-group update --name "github-webhook" \
  --resource-group <YourResourceGroup> \
  --add-action call-webhook web-hook-receiver \
    --webhook-service-uri "https://api.github.com/repos/<GitHubOwner>/<GitHubRepo>/dispatches" \
    --use-common-schema true
```

**Option B: Using Azure Automation Runbook (more complex, more secure)**

Create an Azure Automation Runbook that:
1. Receives the alert
2. Retrieves GitHub PAT from Key Vault
3. Calls the GitHub API with the alert payload
4. Sends `repository_dispatch` event

(See Azure Automation documentation for details)

#### 5c. Create Alert Rule

Example alert rule that triggers the Action Group:

```bash
az monitor metrics alert create --name "High CPU Alert" \
  --resource-group <YourResourceGroup> \
  --resource-type "microsoft.compute/virtualmachines" \
  --resource <YourServerName> \
  --condition "avg Percentage CPU > 90" \
  --window-size "5m" \
  --evaluation-frequency "1m" \
  --action <YourActionGroupID>
```

To get the Action Group ID:

```bash
az monitor action-group show --name "github-webhook" \
  --resource-group <YourResourceGroup> \
  --query id -o tsv
```

---

## Sample Webhook Payload

When Azure Monitor fires an alert, it sends a JSON payload to the GitHub webhook. Here's what it looks like:

```json
{
  "action": "azure-alert",
  "client_payload": {
    "server": "server01",
    "alert_name": "High CPU Usage",
    "severity": "Sev2",
    "description": "CPU usage exceeded 90% for 5 minutes on server01",
    "timestamp": "2026-03-10T01:30:00Z",
    "alert_id": "alert-12345",
    "metric": "Percentage CPU",
    "metric_value": "95.5",
    "threshold": "90",
    "resource_group": "my-rg",
    "subscription_id": "12345678-1234-1234-1234-123456789012"
  }
}
```

### Parsing in Workflow

Your workflow can access these values:

```powershell
# In the workflow
$payload = ${{ toJson(github.event.client_payload) }}
$alert = $payload | ConvertFrom-Json

$server = $alert.server                    # "server01"
$alertName = $alert.alert_name             # "High CPU Usage"
$severity = $alert.severity                # "Sev2"
$description = $alert.description          # "CPU usage exceeded..."
$timestamp = $alert.timestamp              # "2026-03-10T01:30:00Z"
$metricValue = $alert.metric_value         # "95.5"
```

---

## Setting Up the Azure Monitor Webhook

### Manual Configuration (Azure Portal)

1. Go to **Azure Monitor** → **Alerts** → **Action Groups**
2. Create new Action Group (or edit existing)
3. Add **Webhook** action:
   - Name: "GitHub Webhook"
   - Webhook URL: `https://api.github.com/repos/<Owner>/<Repo>/dispatches`
   - Headers:
     - `Authorization: token <GitHub_PAT>`
     - `Content-Type: application/json`
   - Payload (custom):
     ```json
     {
       "event_type": "azure-alert",
       "client_payload": {
         "server": "server01",
         "alert_name": "{{ AlertName }}",
         "severity": "{{ Severity }}",
         "description": "{{ Description }}",
         "timestamp": "{{ Timestamp }}"
       }
     }
     ```
4. Test the webhook
5. Save

### CLI Configuration

```bash
# Create the action group
az monitor action-group create \
  --name "github-webhook" \
  --resource-group <YourResourceGroup>

# Add webhook receiver (requires template)
az monitor action-group webhook-receiver create \
  --action-group-name "github-webhook" \
  --resource-group <YourResourceGroup> \
  --name "github-dispatch" \
  --webhook-service-uri "https://api.github.com/repos/<Owner>/<Repo>/dispatches"
```

{: .warning }
> **GitHub PAT Security:** If using a PAT for the webhook, treat it like a password. Consider:
> 1. Store it in **Azure Key Vault**, not GitHub Secrets
> 2. Use a **minimal-scope PAT** (only `repo:status` if possible)
> 3. **Rotate quarterly** or on team changes
> 4. Monitor GitHub PAT usage in GitHub audit logs

---

## Security Considerations

### Key Vault Access Logging

All Key Vault access is logged in Azure:

```bash
# View Key Vault access logs
az monitor diagnostic-settings list --resource <KeyVaultID>

# Enable detailed logging if not already
az monitor diagnostic-settings create --name "kv-logging" \
  --resource <KeyVaultID> \
  --logs '[{"category": "AuditEvent", "enabled": true}]' \
  --storage-account <StorageAccountID>
```

### OIDC Benefits

- **No long-lived secrets** — GitHub Actions authenticate via short-lived tokens
- **Audit trail** — Every token request is logged in Azure AD
- **Scope-limited** — GitHub can only authenticate for specific repo + branch combinations
- **Easy revocation** — Remove OIDC credential anytime

### Credential File Protection

- Server credentials in Key Vault are **encrypted at rest**
- DPAPI credentials (from interactive CLI mode) won't work in GitHub Actions
- Credentials are **never logged** in workflow output (masked by GitHub)
- Credentials **deleted from runner memory** after diagnostics complete

### IP Restrictions (Optional)

Restrict Key Vault access to specific IPs:

```bash
# Add firewall rule to Key Vault
az keyvault network-rule add --name <YourKeyVaultName> \
  --ip-address <GitHubActionsRunnerIP>/32
```

If using **self-hosted runners**, add the runner's IP. If using GitHub-hosted runners, they use dynamic IPs — not practical for IP restrictions. Instead, rely on OIDC + Azure AD authentication.

### Minimal GitHub PAT Scope

If using a GitHub PAT for the webhook:

```bash
# Create PAT with minimal scope (via GitHub CLI)
gh auth refresh --scopes repo:status,public_repo

# Or in GitHub UI:
# Settings → Developer settings → Personal access tokens → New token
# Scopes: Only check "repo:status" and "public_repo"
```

---

## Limitations

Automated investigations have these constraints:

### Network Access

- GitHub Actions runners must reach your servers
- If on-premises: use a **self-hosted runner** in your network
- If Azure VMs: configure **NSG rules** to allow port 5986 from runner
- If behind proxy: configure runner's proxy settings

### Credential Rotation

- Server credentials must be updated in **both** Key Vault and your credentials file (interactive mode)
- Consider automated credential rotation for production (cycle every 90 days)

### Concurrent Alerts

- Multiple alerts firing simultaneously = multiple workflows running
- This is fine — each gets its own GitHub Actions runner
- Potential impact: dozens of diagnostics running in parallel on a single server (may cause load spike)

### Self-Hosted Runners

If using self-hosted runners for on-premises access:

- Runner must be online and healthy to receive alerts
- OIDC requires **GitHub Actions version 1.0.0+**
- Not recommended for critical systems without runner failover

### Diagnostic Limitations

See main [README.md Limitations](#limitations) section — automated investigations have the same constraints as interactive mode:

- Cannot modify server state (only report)
- Cannot restart services (escalate to ops)
- Cannot expand volumes (escalate to infrastructure)

---

## Troubleshooting

### "Failed to authenticate to Azure"

**Symptom:** Workflow fails at OIDC login step.

**Check:**
1. OIDC federation credential is created: `az ad app federated-credential list --id <AppID>`
2. Service principal has Key Vault access: `az role assignment list --assignee-object-id <SPObjectID>`
3. GitHub repo and branch match the OIDC subject: `repo:owner/repo:ref:refs/heads/branch`

### "Key Vault secret not found"

**Symptom:** Workflow fails when retrieving credentials from Key Vault.

**Check:**
1. Secret names match: `server-admin-username` and `server-admin-password`
2. Service principal has "Key Vault Secrets User" role
3. Key Vault exists in the correct subscription

### "Failed to connect to target server"

**Symptom:** Diagnostic step times out or reports "Connection refused".

**Check:**
1. Server is online: `Test-WSMan <ServerName>`
2. Port 5986 is accessible from runner IP
3. PowerShell remoting is enabled: `Enable-PSRemoting -Force`
4. Credentials are correct (test manually first)

### "Webhook never fires"

**Symptom:** Alert fires in Azure but GitHub issue is never created.

**Check:**
1. Action Group is associated with alert rule
2. Webhook URL is correct: `https://api.github.com/repos/Owner/Repo/dispatches`
3. GitHub PAT has `repo` scope
4. GitHub PAT is not expired
5. Test webhook manually: `curl -X POST https://api.github.com/repos/Owner/Repo/dispatches -H "Authorization: token PAT" -H "Content-Type: application/json" -d '{"event_type":"azure-alert","client_payload":{"server":"test"}}'`

---

## Next Steps

1. **Start with prerequisites** — Set up Key Vault, OIDC, and GitHub Actions
2. **Test the workflow manually** — Trigger it without an alert first
3. **Create a simple alert** — Test with a non-critical metric (e.g., CPU on a dev server)
4. **Monitor the results** — Check GitHub Issues and workflow logs
5. **Expand to production alerts** — Once confident, add real alert rules
6. **Integrate with on-call tools** — Route GitHub issues to Slack, PagerDuty, etc.

---

## Example: Complete End-to-End Setup

Here's a complete walkthrough for setting up a single alert:

```bash
# Step 1: Create Key Vault and secrets
az keyvault create --resource-group my-rg --name my-kv --location eastus
az keyvault secret set --vault-name my-kv --name "server-admin-username" --value "domain\admin"
az keyvault secret set --vault-name my-kv --name "server-admin-password" --value "MyPassword123!"

# Step 2: Create Azure AD app and OIDC federation
APP_ID=$(az ad app create --display-name "github-actions" --query appId -o tsv)
az ad sp create --id $APP_ID
SPOBJ=$(az ad sp show --id $APP_ID --query id -o tsv)

# Step 3: Grant Key Vault access
az role assignment create --role "Key Vault Secrets User" \
  --assignee-object-id $SPOBJ \
  --assignee-principal-type ServicePrincipal \
  --scope "/subscriptions/$(az account show --query id -o tsv)/resourcegroups/my-rg/providers/Microsoft.KeyVault/vaults/my-kv"

# Step 4: Create OIDC federation
az ad app federated-credential create --id $APP_ID --parameters '{
  "name": "github-actions",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:anwather/ServerWhisperer:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}'

# Step 5: Add secrets to GitHub (Settings → Secrets)
echo "Add these to GitHub repository secrets:"
echo "AZURE_CLIENT_ID=$APP_ID"
echo "AZURE_TENANT_ID=$(az account show --query tenantId -o tsv)"
echo "AZURE_SUBSCRIPTION_ID=$(az account show --query id -o tsv)"
echo "AZURE_KEYVAULT_NAME=my-kv"

# Step 6: Create GitHub Actions workflow (.github/workflows/alert-investigation.yml)
# [See workflow YAML above]

# Step 7: Create Azure alert rule (example: CPU > 90%)
az monitor metrics alert create \
  --name "High CPU Alert" \
  --resource-group my-rg \
  --resource-type "microsoft.compute/virtualmachines" \
  --resource "server01" \
  --condition "avg Percentage CPU > 90" \
  --window-size 5m \
  --evaluation-frequency 1m
```

---

_Built by the ServerWhisperer team._
