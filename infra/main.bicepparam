using 'main.bicep'

param location = 'australiaeast'
param resourcePrefix = 'sw'
param vmAdminUsername = 'azureuser'
param vmAdminPassword = 'ReplaceWithSecurePassword123!'
param deployerPublicIp = '167.220.242.221/32'
param teamsWebhookUrl = 'https://placeholder.webhook.office.com/not-configured-yet'
param foundryAgentId = 'TODO-AGENT-ID'
param enableEventGrid = false
