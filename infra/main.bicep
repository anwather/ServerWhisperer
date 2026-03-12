@description('Location for all resources.')
param location string = resourceGroup().location

@description('Prefix used for resource names.')
param resourcePrefix string = 'sw'

@description('Admin username for the target VM.')
param vmAdminUsername string

@description('Admin password for the target VM.')
@secure()
param vmAdminPassword string

@description('Public IP/CIDR allowed to access RDP and WinRM on the VM.')
param deployerPublicIp string

@description('Teams webhook URL stored in Key Vault.')
@secure()
param teamsWebhookUrl string

@description('Foundry agent ID (placeholder until created post-deploy).')
param foundryAgentId string = 'TODO-AGENT-ID'

@description('URI to configure-winrm.ps1 script in a blob container.')
param configureWinrmScriptUri string

@description('Enable Event Grid system topic and subscription.')
param enableEventGrid bool = false

var tags = {
  project: 'serverwhisperer'
  environment: 'demo'
}

module storage 'modules/storage.bicep' = {
  name: 'storage'
  params: {
    location: location
    resourcePrefix: resourcePrefix
    tags: tags
  }
}

module keyVault 'modules/keyvault.bicep' = {
  name: 'keyVault'
  params: {
    location: location
    resourcePrefix: resourcePrefix
    teamsWebhookUrl: teamsWebhookUrl
    tags: tags
  }
}

resource keyVaultExisting 'Microsoft.KeyVault/vaults@2024-01-01' existing = {
  name: keyVault.outputs.keyVaultName
}

module networking 'modules/networking.bicep' = {
  name: 'networking'
  params: {
    location: location
    resourcePrefix: resourcePrefix
    deployerPublicIp: deployerPublicIp
    tags: tags
  }
}

module targetVm 'modules/target-vm.bicep' = {
  name: 'targetVm'
  params: {
    location: location
    resourcePrefix: resourcePrefix
    adminUsername: vmAdminUsername
    adminPassword: vmAdminPassword
    subnetId: networking.outputs.vmSubnetId
    configureWinrmScriptUri: configureWinrmScriptUri
    tags: tags
  }
}

module foundry 'modules/foundry.bicep' = {
  name: 'foundry'
  params: {
    location: location
    resourcePrefix: resourcePrefix
    storageAccountId: storage.outputs.storageAccountId
    keyVaultId: keyVault.outputs.keyVaultId
    tags: tags
  }
}

module search 'modules/search.bicep' = {
  name: 'search'
  params: {
    location: location
    resourcePrefix: resourcePrefix
    tags: tags
  }
}

module functionApp 'modules/function-app.bicep' = {
  name: 'functionApp'
  params: {
    location: location
    resourcePrefix: resourcePrefix
    storageConnectionString: storage.outputs.storageConnectionString
    foundryEndpoint: foundry.outputs.foundryEndpoint
    foundryAgentId: foundryAgentId
    teamsWebhookSecretUri: keyVault.outputs.teamsWebhookSecretUri
    tags: tags
  }
}

var functionWebhookUrl = 'https://${functionApp.outputs.functionDefaultHostName}/api/AlertIngress'

module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring'
  params: {
    resourcePrefix: resourcePrefix
    vmResourceId: targetVm.outputs.vmId
    functionWebhookUrl: functionWebhookUrl
    tags: tags
  }
}

module eventGrid 'modules/event-grid.bicep' = if (enableEventGrid) {
  name: 'eventGrid'
  params: {
    location: location
    resourcePrefix: resourcePrefix
    functionWebhookUrl: functionWebhookUrl
    tags: tags
  }
}

resource vmContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, functionApp.outputs.functionPrincipalId, 'vm-contributor')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '9980e02c-c2be-4d73-94e8-173b1dc7cf3c')
    principalId: functionApp.outputs.functionPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource readerRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, functionApp.outputs.functionPrincipalId, 'reader')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7')
    principalId: functionApp.outputs.functionPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource monitoringReaderRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, functionApp.outputs.functionPrincipalId, 'monitoring-reader')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '43d0d8ad-25c7-4714-9337-8ba259a9fe05')
    principalId: functionApp.outputs.functionPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource keyVaultSecretsUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.outputs.keyVaultId, functionApp.outputs.functionPrincipalId, 'kv-secrets-user')
  scope: keyVaultExisting
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
    principalId: functionApp.outputs.functionPrincipalId
    principalType: 'ServicePrincipal'
  }
}

@description('Name of the deployed Function App.')
output functionAppName string = functionApp.outputs.functionAppName

@description('Public IP address of the target VM.')
output vmPublicIp string = targetVm.outputs.vmPublicIp

@description('Foundry endpoint for AI workloads.')
output foundryEndpoint string = foundry.outputs.foundryEndpoint

@description('Resource group name for the deployment.')
output resourceGroupName string = resourceGroup().name
