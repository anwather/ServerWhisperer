@description('Location for Function App resources.')
param location string

@description('Prefix used for resource names.')
param resourcePrefix string

@description('Storage connection string for the Function App.')
@secure()
param storageConnectionString string

@description('Foundry endpoint for the AI Hub/Project.')
param foundryEndpoint string

@description('Foundry agent ID placeholder.')
param foundryAgentId string

@description('Key Vault secret URI for the Teams webhook.')
param teamsWebhookSecretUri string

@description('Tags applied to resources.')
param tags object

var planName = '${resourcePrefix}-func-plan'
var functionAppName = '${resourcePrefix}-func'

resource plan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: planName
  location: location
  tags: tags
  sku: {
    name: 'FC1'
    tier: 'FlexConsumption'
    size: 'FC1'
    family: 'FC'
    capacity: 1
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
          name: 'AzureWebJobsStorage'
          value: storageConnectionString
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: storageConnectionString
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(functionAppName)
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

@description('Function App name.')
output functionAppName string = functionApp.name

@description('Default hostname for the Function App.')
output functionDefaultHostName string = functionApp.properties.defaultHostName

@description('Principal ID of the Function App managed identity.')
output functionPrincipalId string = functionApp.identity.principalId
