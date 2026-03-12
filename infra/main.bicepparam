using 'main.bicep'

param location = 'eastus'
param resourcePrefix = 'sw'
param vmAdminUsername = 'azureuser'
param vmAdminPassword = 'ReplaceWithSecurePassword123!'
param deployerPublicIp = '0.0.0.0/32'
param teamsWebhookUrl = 'https://outlook.office.com/webhook/your-webhook'
param foundryAgentId = 'TODO-AGENT-ID'
param configureWinrmScriptUri = 'https://<storage-account>.blob.core.windows.net/function-deploy/configure-winrm.ps1'
param enableEventGrid = false
