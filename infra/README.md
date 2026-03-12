# ServerWhisperer Alert Automation — Deployment Guide

## Overview

This demo automates the complete journey from Azure Monitor alert to AI-powered diagnosis. When a metric alert fires (CPU high, disk low, memory critical), the system automatically investigates the affected Windows Server, runs diagnostics, analyzes results with a Microsoft Foundry agent, and delivers a root-cause diagnosis via Teams — all in under 2 minutes, at 3 AM, without human intervention.

**The flow:** Alert fires → Event Grid → Durable Function orchestrates diagnostics → Foundry agent analyzes → Teams notification with actionable remediation.

---

## Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│                      ALERT SOURCES                               │
│   Azure Monitor Metric Alerts (CPU, Disk, Memory)                │
└───────────┬────────────────────────────────────────────────────┘
            │
            ▼
┌──────────────────────────────────────────────────────────────────┐
│              EVENT GRID SYSTEM TOPIC                             │
│  Routes alerts by severity and resource type                    │
└───────────┬────────────────────────────────────────────────────┘
            │
            ▼
┌──────────────────────────────────────────────────────────────────┐
│        AZURE DURABLE FUNCTIONS ORCHESTRATION (PowerShell)        │
│                                                                  │
│  ┌─────────┐  ┌──────────┐  ┌─────────────┐  ┌──────────────┐  │
│  │ INTAKE  │→ │ CLASSIFY │→ │ INVESTIGATE │→ │ ANALYZE      │  │
│  │ Alert   │  │ Target   │  │ Via Run Cmd │  │ Foundry Agent│  │
│  │ Context │  │ VM       │  │ Bundled     │  │              │  │
│  └─────────┘  └──────────┘  │ Script      │  │ + Tools      │  │
│                              │ Diagnostics │  │ + KB         │  │
│                              └─────────────┘  └──────────────┘  │
│                                                         │        │
│                    ┌────────────────────────────────────┘        │
│                    ▼                                             │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ REPORT: Teams Webhook + Blob Storage                     │   │
│  │ Adaptive Card with root cause + remediation steps        │   │
│  └──────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────┘
            │
            ▼
┌──────────────────────────────────────────────────────────────────┐
│           AZURE VM EXECUTION (Run Command)                       │
│  No WinRM setup needed. Managed Identity authentication.         │
└──────────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

Before deploying, ensure you have:

### Azure Permissions
- **Azure subscription** with Owner or Contributor role + User Access Admin (to assign RBAC roles)
- Sufficient quota for a D2s_v5 VM in your target region (check [Azure Quotas](https://portal.azure.com/#blade/Microsoft_Azure_Capacity/QuotaMenuBlade))

### Local Tools
- **Azure CLI** — installed and authenticated (`az login` must work)
  - [Install Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
- **PowerShell 7+** — required for Bicep deployment and post-deployment scripts
  - [Install PowerShell](https://learn.microsoft.com/powershell/scripting/install/installing-powershell)

### Microsoft Teams
- **Microsoft Teams channel** with an Incoming Webhook configured
  - [How to create an Incoming Webhook in Teams](https://docs.microsoft.com/microsoftsoftware-teams/platform/webhooks-and-connectors/how-to/connectors-using)
  - Keep the webhook URL handy — you'll paste it during deployment

### Azure Services Registration
- **Access to Azure AI Foundry** — your subscription must be registered for `Microsoft.MachineLearningServices`
  - If unsure, run: `az provider show --namespace Microsoft.MachineLearningServices` — should return `"registrationState": "Registered"`
  - If not registered, run: `az provider register --namespace Microsoft.MachineLearningServices`

---

## Resource Providers — Pre-Registration

The deployment requires these Azure resource providers to be registered. Run each command once:

```powershell
# Core compute and monitoring
az provider register --namespace Microsoft.Compute
az provider register --namespace Microsoft.Insights
az provider register --namespace Microsoft.EventGrid
az provider register --namespace Microsoft.Web

# AI/ML services
az provider register --namespace Microsoft.MachineLearningServices
az provider register --namespace Microsoft.Search

# Security and storage
az provider register --namespace Microsoft.KeyVault
az provider register --namespace Microsoft.Storage
```

Registration typically completes in 2-3 minutes. You can check status with:
```powershell
az provider show --namespace Microsoft.Web --query "registrationState"
```

---

## Quick Start

### Step 1: Clone the Repository

```powershell
git clone https://github.com/AnthonyWatherston/win-investigator.git
cd win-investigator
```

### Step 2: Create an Azure Resource Group

Choose a region (e.g., `eastus`) and create a resource group:

```powershell
$ResourceGroup = "rg-serverwhisperer-demo"
$Location = "eastus"

az group create --name $ResourceGroup --location $Location
```

### Step 3: Prepare Deployment Parameters

⚠️ **Important:** Before running the deployment, you need:
1. Your Teams Incoming Webhook URL (from Prerequisites)
2. A strong password for the VM admin user (will be stored in Key Vault)

Create a local parameters file or note these values for the CLI:

```powershell
$TeamsWebhookUrl = "https://outlook.webhook.office.com/webhookb2/..."  # Your Teams webhook
$VmAdminPassword = "Your-Strong-P@ssw0rd"  # At least 12 chars, mixed case, numbers, symbols
```

### Step 4: Deploy Infrastructure with Bicep

This single command deploys all infrastructure: VM, monitoring, Function App, Foundry project, Key Vault, Storage, and networking.

```powershell
az deployment group create `
  --resource-group $ResourceGroup `
  --template-file infra/main.bicep `
  --parameters `
    location=$Location `
    vmAdminPassword=$VmAdminPassword `
    teamsWebhookUrl=$TeamsWebhookUrl
```

⏳ **Wait 10-15 minutes.** The deployment creates:
- Windows Server 2022 VM with WinRM HTTPS configured
- Azure Monitor alert rules (CPU, disk, memory)
- Event Grid system topic and subscription
- Flex Consumption Function App (PowerShell 7)
- AI Foundry project with GPT-4o-mini deployment
- Azure AI Search index (knowledge base)
- Key Vault, Storage account, and networking

Monitor progress in the Azure Portal → Resource Groups → `rg-serverwhisperer-demo` → Deployments.

### Step 5: Deploy Function App Code

After Bicep deployment completes, deploy the Durable Function code:

```powershell
./infra/scripts/deploy-function-code.ps1 `
  -ResourceGroup $ResourceGroup `
  -Location $Location
```

This publishes the Function App functions:
- `AlertIngress` — HTTP trigger for Event Grid
- `InvestigationOrchestrator` — Durable orchestrator
- `ClassifyTarget`, `ExecuteDiagnostics`, `AnalyzeWithFoundryAgent`, `SendReport` — Activity functions

### Step 6: Create the Foundry Agent

The Foundry agent is created via a post-deployment script (Foundry agent APIs aren't yet Bicep-native):

```powershell
./infra/scripts/create-foundry-agent.ps1 `
  -ResourceGroup $ResourceGroup `
  -Location $Location
```

This creates a Foundry agent named `serverwhisperer-diagnostician` with:
- System prompt tuned for Windows Server diagnostics
- Three tool definitions (Resource Graph, VM Power State, Activity Log queries)
- Knowledge base connected to Azure AI Search index

✅ **Deployment complete!** You now have a fully automated alert-to-diagnosis pipeline.

---

## Post-Deployment Configuration

### 1. Verify the Teams Webhook URL

The deployment stored your Teams webhook URL in Key Vault. Verify it's there:

```powershell
az keyvault secret show `
  --vault-name $(az keyvault list -g $ResourceGroup --query "[0].name" -o tsv) `
  --name teams-webhook-url
```

If the value appears encrypted or truncated, that's normal — Key Vault hides secret values for security.

### 2. Verify the Foundry Agent

Open the Azure Portal and navigate to your AI Project:

1. Resource Groups → `rg-serverwhisperer-demo`
2. Resources tab → Find `sw-ai-project` (AI Project resource)
3. Click **Agent Studio** or **Manage → Agents**
4. You should see `serverwhisperer-diagnostician` with status ✅ Active

Verify the agent has:
- ✅ System prompt (Windows Server diagnostic expert)
- ✅ Three tools defined (Resource Graph, Power State, Activity Log)
- ✅ Knowledge base connected (Azure AI Search index)

If the agent is missing or shows warnings, re-run `create-foundry-agent.ps1`.

### 3. Verify the Function App

Check that the Function App deployed successfully:

```powershell
$functionAppName = "sw-function-app-$([System.Guid]::NewGuid().ToString().Substring(0,8))"

# List all functions
az functionapp function list --resource-group $ResourceGroup --name $functionAppName --query "[].{Name:name, Bindings:bindings[].type}"
```

You should see:
- ✅ `AlertIngress` (httpTrigger)
- ✅ `InvestigationOrchestrator` (orchestrationTrigger)
- ✅ `ClassifyTarget` (activityTrigger)
- ✅ `ExecuteDiagnostics` (activityTrigger)
- ✅ `AnalyzeWithFoundryAgent` (activityTrigger)
- ✅ `SendReport` (activityTrigger)

### 4. Check Monitoring Alert Rules

In the Azure Portal:

1. Resource Groups → `rg-serverwhisperer-demo`
2. Search for "Alert Rules" or navigate to Monitor → Alert Rules
3. You should see three rules:
   - `sw-demo-vm-high-cpu` — Triggers if CPU > 80% for 5 minutes
   - `sw-demo-vm-low-disk` — Triggers if OS disk used % > 85%
   - `sw-demo-vm-high-memory` — Triggers if available memory < 500MB

All rules should show **Enabled** ✅ and **Action Group: ServerWhisperer-AG** attached.

### 5. NSG Rules for RDP/WinRM (Optional)

The deployment creates an NSG that locks down access. If you want to:
- **Connect via RDP:** Add your client IP to port 3389
- **Connect via WinRM PowerShell remoting:** Add your client IP to port 5986

Find your public IP:

```powershell
$myPublicIp = (Invoke-WebRequest -Uri "https://checkip.amazonaws.com" -UseBasicParsing).Content.Trim()
Write-Host "Your public IP: $myPublicIp"
```

Add NSG rule for WinRM (optional for interactive ServerWhisperer use):

```powershell
$nsgName = $(az network nsg list -g $ResourceGroup --query "[0].name" -o tsv)

az network nsg rule create `
  --resource-group $ResourceGroup `
  --nsg-name $nsgName `
  --name AllowWinRM-FromMyIP `
  --priority 1001 `
  --source-address-prefixes "$myPublicIp/32" `
  --destination-port-ranges 5986 `
  --access Allow `
  --protocol Tcp
```

### 6. VM Admin Credentials

The VM was created with the username `serveradmin` and the password you provided during deployment.

- **For Run Command:** No credentials needed — the Function App uses Managed Identity
- **For RDP access:** Use `serveradmin` + the password from the parameter
- **For WinRM remoting:** If you added the NSG rule above, you can use PowerShell remoting with these credentials

The password is NOT stored in the deployment output for security. It's referenced only in Key Vault (accessible only to the Function App Managed Identity).

---

## Running the Demo

### Option A: Trigger CPU Stress

Burn CPU to trigger the high-CPU alert:

```powershell
$ResourceGroup = "rg-serverwhisperer-demo"
$vmName = "sw-demo-vm"

az vm run-command invoke `
  --resource-group $ResourceGroup `
  --name $vmName `
  --command-id RunPowerShellScript `
  --scripts @infra/scripts/simulate-cpu-load.ps1 `
  --parameters DurationMinutes=10
```

This runs a CPU stress script on the VM that burns CPU on all cores for 10 minutes. Azure Monitor will detect the high CPU around minute 5-7 (wait for the alert window).

### Option B: Trigger Disk Pressure

Fill the temp disk to trigger the low-disk alert:

```powershell
az vm run-command invoke `
  --resource-group $ResourceGroup `
  --name $vmName `
  --command-id RunPowerShellScript `
  --scripts @infra/scripts/simulate-disk-pressure.ps1
```

⏳ **Timeline:**
- **0-5 minutes:** Stress runs on VM
- **~5 minutes:** Azure Monitor detects condition and fires alert
- **5-7 minutes:** Alert payload reaches Event Grid
- **~7 minutes:** Durable Function starts, classifies alert, executes Run Command diagnostics (~15s)
- **~8 minutes:** Foundry agent analyzes results, possibly calls tools (~20s)
- **~9 minutes:** SendReport function publishes Adaptive Card to Teams
- **Total:** ~7-9 minutes from stress start to Teams notification

📊 **Where to see results:**

1. **Teams Channel** — Adaptive Card arrives with:
   - Server name, status emoji (🟢🟡🔴), alert condition
   - Root cause analysis from Foundry agent
   - "View Full Report" link to Blob Storage
   - "View in Azure Portal" link to VM

2. **Blob Storage** — Full investigation report:
   - Resource Groups → `rg-serverwhisperer-demo`
   - Storage account → Containers → `reports`
   - Reports stored as JSON + rendered markdown

3. **Azure Monitor** — Alert details:
   - Monitor → Alert Rules → `sw-demo-vm-high-cpu` (or disk/memory)
   - View fired instances and alert history

4. **Function App Logs** — For debugging:
   ```powershell
   $functionAppName = $(az functionapp list -g $ResourceGroup --query "[0].name" -o tsv)
   az functionapp log tail --resource-group $ResourceGroup --name $functionAppName
   ```

---

## Cost Estimate

### Demo Environment (Recommended — VM deallocated between demos)

| Resource | SKU | Monthly Cost |
|----------|-----|--------------|
| Windows VM (D2s_v5, deallocated except demos) | Pay-as-you-go | $5-20 |
| Azure Functions (Flex Consumption) | Per-execution | $2 |
| Event Grid | Per-operation | $0.50 |
| AI Foundry + GPT-4o-mini | ~2K tokens per investigation | $5-10 |
| Azure AI Search | Free tier | $0 |
| Blob Storage | Hot tier, < 1GB | $1 |
| Key Vault | Standard tier | $0.50 |
| **Total (idle)** | | **~$15-25/month** |
| **Total (VM running)** | | **~$80-90/month** |

💡 **Tip:** Deallocate the VM when not demoing to save ~$70/month. Run Command still works on deallocated VMs.

```powershell
# Deallocate the VM
az vm deallocate --resource-group $ResourceGroup --name sw-demo-vm --no-wait

# Restart it for the next demo
az vm start --resource-group $ResourceGroup --name sw-demo-vm
```

---

## Troubleshooting

### "Alert didn't fire"

**Symptoms:** You ran the stress script but no alert appeared in ~7 minutes.

**Diagnosis:**
1. Check metric alert is **Enabled**:
   ```powershell
   az monitor metrics alert list -g $ResourceGroup --query "[].{Name:name, Enabled:enabled}"
   ```
   Should show `"Enabled": true` for all three rules.

2. Check the **evaluation window**:
   - Alert rules evaluate every 1 minute
   - Threshold must be exceeded for 5 minutes consecutively
   - CPU must stay > 80% for the full 5-minute window
   
3. Check the stress script is actually running:
   ```powershell
   # Check VM CPU metrics in the portal
   # Or check recent Run Command invocations:
   az vm run-command list --resource-group $ResourceGroup --name sw-demo-vm
   ```

4. **If still no alert:** Restart the alert rule:
   ```powershell
   az monitor metrics alert update -g $ResourceGroup --name sw-demo-vm-high-cpu --set enabled=false
   # Wait 10 seconds
   az monitor metrics alert update -g $ResourceGroup --name sw-demo-vm-high-cpu --set enabled=true
   ```

### "Function didn't trigger / Function failed"

**Symptoms:** Alert fired but no Teams notification appeared, or Function logs show errors.

**Diagnosis:**
1. Check Event Grid subscription:
   ```powershell
   az eventgrid system-topic-event-subscription list \
     --resource-group $ResourceGroup \
     --name sw-system-topic \
     --query "[].{Name:name, Endpoint:properties.destination.endpointUrl, Enabled:properties.enabled}"
   ```
   Should show the subscription with your Function App endpoint and `"Enabled": true`.

2. Check Function App logs:
   ```powershell
   $functionAppName = $(az functionapp list -g $ResourceGroup --query "[0].name" -o tsv)
   az functionapp log tail --resource-group $ResourceGroup --name $functionAppName
   ```
   Look for errors in `AlertIngress` or `InvestigationOrchestrator` functions.

3. Check Durable orchestration status (AppInsights):
   - Resource Groups → `rg-serverwhisperer-demo`
   - Find "Application Insights" resource
   - Go to **Logs** and query:
     ```kusto
     traces | where message contains "InvestigationOrchestrator" | order by timestamp desc | take 20
     ```

### "Foundry agent error / Analysis is blank"

**Symptoms:** Function logs show agent-related errors, or Teams card has no analysis text.

**Diagnosis:**
1. Verify the agent exists in AI Foundry:
   ```powershell
   # Check the agent was created
   $aiProjectId = $(az ml workspace list -g $ResourceGroup --kind Project --query "[0].id" -o tsv)
   # (Note: Check the Azure Portal Agent Studio for a simpler view)
   ```

2. Check the agent's RBAC permissions:
   - Resource Groups → `rg-serverwhisperer-demo`
   - Find AI Project → Access Control (IAM)
   - Function App Managed Identity should have role `Cognitive Services OpenAI User` or higher

3. Verify Foundry endpoint and agent ID in Function App settings:
   ```powershell
   az functionapp config appsettings list \
     --resource-group $ResourceGroup \
     --name $functionAppName \
     --query "[?name=='FOUNDRY_ENDPOINT' || name=='FOUNDRY_AGENT_ID'].{Name:name, Value:value}"
   ```
   Both should be populated (values may be partially redacted).

4. **If agent creation failed:** Re-run the creation script:
   ```powershell
   ./infra/scripts/create-foundry-agent.ps1 -ResourceGroup $ResourceGroup -Location $Location
   ```

### "Teams card not received"

**Symptoms:** Function reports success but nothing appears in your Teams channel.

**Diagnosis:**
1. Verify the webhook URL is correct in Key Vault:
   ```powershell
   $vaultName = $(az keyvault list -g $ResourceGroup --query "[0].name" -o tsv)
   az keyvault secret show --vault-name $vaultName --name teams-webhook-url --query "value"
   ```
   Should be your full webhook URL (starting with `https://outlook.webhook.office.com/...`).

2. Check the SendReport function logs:
   ```powershell
   az functionapp log tail --resource-group $ResourceGroup --name $functionAppName | Select-String "SendReport"
   ```
   Look for HTTP errors (4xx, 5xx) when posting to Teams.

3. **If the webhook URL is wrong:** Update it in Key Vault:
   ```powershell
   $newWebhookUrl = "https://outlook.webhook.office.com/webhookb2/..."  # Your correct URL
   az keyvault secret set \
     --vault-name $vaultName \
     --name teams-webhook-url \
     --value $newWebhookUrl
   ```

4. **If the Teams channel is deactivated:** Recreate the webhook in Teams and update Key Vault.

### "Run Command timeout or execution failed"

**Symptoms:** `ExecuteDiagnostics` function logs show Run Command errors or timeouts.

**Diagnosis:**
1. Check if the VM is running:
   ```powershell
   az vm get-instance-view -g $ResourceGroup --name sw-demo-vm --query "instanceView.statuses[?starts_with(code,'PowerState/')]"
   ```
   Should show `PowerState/running`. If deallocated, start it:
   ```powershell
   az vm start --resource-group $ResourceGroup --name sw-demo-vm --no-wait
   ```

2. Check if the VM is under heavy load:
   - Run Command execution queues per-VM (1 concurrent)
   - If another stress test is running, wait for it to finish

3. **If still timing out:** Check Run Command extension status:
   ```powershell
   az vm extension list --resource-group $ResourceGroup --vm-name sw-demo-vm
   ```
   Look for `RunCommandHandlerLinux` or `RunCommandHandlerWindows` with status `Succeeded`.

---

## Cleanup

To delete all resources and stop incurring charges:

```powershell
az group delete --resource-group $ResourceGroup --yes --no-wait
```

⏳ Deletion typically completes in 5-10 minutes. Monitor progress in the Portal.

⚠️ **Warning:** This deletes ALL resources in the group, including:
- VM and disks
- Function App and Durable Function state
- Key Vault (and all secrets stored within)
- Blob Storage (and all investigation reports)
- Event Grid subscriptions
- All others

There is **no undo** — make sure you've saved any reports you need before deleting.

---

## Next Steps

### After the Demo Works:

1. **Inspect Investigation Reports** — Browse Blob Storage to see what the Foundry agent analyzed and recommended
2. **Check Knowledge Base** — Query the Azure AI Search index to see how past investigations are indexed
3. **Extend Diagnostics** — Modify `Get-AllDiagnostics.ps1` to collect additional metrics relevant to your environment
4. **Tune Alert Rules** — Adjust CPU/disk/memory thresholds based on your typical workload
5. **Customize Foundry System Prompt** — Update the agent's instructions to match your runbook procedures

### For Production:

- Populate the knowledge base with real investigation reports
- Set up Azure Monitor Workbooks dashboard to track MTTR and alert trends
- Implement feedback loop in Teams cards (engineer rates diagnosis quality)
- Add auto-remediation for safe actions (e.g., restart a failed service)
- Move to private endpoints for all services (security hardening)

---

## Support

For issues or questions:

- **Deployment errors:** Check Azure Portal → Resource Groups → Deployments → Failed operations
- **Function errors:** Check Application Insights logs and Durable orchestration traces
- **Agent errors:** Review Azure AI Foundry Agent Studio UI for the agent status and configuration
- **Teams integration:** Verify webhook URL and Teams channel permissions

For details on the diagnostic framework, see [win-investigator README](../README.md).

For architecture and design decisions, see [Architecture Plan](https://github.com/AnthonyWatherston/win-investigator/blob/main/.squad/agents/scully/architecture-v2.md).
