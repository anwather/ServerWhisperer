@description('Location for Function App resources.')
param location string

@description('Prefix used for resource names.')
param resourcePrefix string

@description('Storage account name for the Function App.')
param storageAccountName string

@description('Storage account resource ID for role assignments.')
param storageAccountId string

@description('Foundry endpoint for the AI Hub/Project.')
param foundryEndpoint string

@description('Foundry agent ID placeholder.')
param foundryAgentId string

@description('Key Vault secret URI for the Teams webhook.')
param teamsWebhookSecretUri string

@description('Tags applied to resources.')
param tags object

var planName = '${resourcePrefix}-func-plan'
var functionAppName = '${resourcePrefix}-func-${uniqueString(resourceGroup().id)}'

resource plan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: planName
  location: location
  tags: tags
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  kind: 'functionapp'
  properties: {
    reserved: false
  }
}

resource functionApp 'Microsoft.Web/sites@2024-04-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp'
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage__accountName'
          value: storageAccountName
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'PowerShell'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME_VERSION'
          value: '7.4'
        }
        {
          name: 'FoundryEndpoint'
          value: foundryEndpoint
        }
        {
          name: 'FoundryAgentId'
          value: foundryAgentId
        }
        {
          name: 'TeamsWebhookUrl'
          value: '@Microsoft.KeyVault(SecretUri=${teamsWebhookSecretUri})'
        }
      ]
    }
  }
}

// Role assignments for Function App managed identity on storage account
resource storageBlobDataOwner 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccountId, functionApp.id, 'storage-blob-data-owner')
  scope: storageAccountRef
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b')
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource storageQueueDataContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccountId, functionApp.id, 'storage-queue-data-contributor')
  scope: storageAccountRef
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '974c5e8b-45b9-4653-ba55-5f855dd0fb88')
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource storageTableDataContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccountId, functionApp.id, 'storage-table-data-contributor')
  scope: storageAccountRef
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3')
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource storageAccountRef 'Microsoft.Storage/storageAccounts@2024-01-01' existing = {
  name: storageAccountName
}

@description('Function App name.')
output functionAppName string = functionApp.name

@description('Default hostname for the Function App.')
output functionDefaultHostName string = functionApp.properties.defaultHostName

@description('Principal ID of the Function App managed identity.')
output functionPrincipalId string = functionApp.identity.principalId
