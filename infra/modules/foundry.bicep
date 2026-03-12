@description('Location for Foundry resources.')
param location string

@description('Prefix used for resource names.')
param resourcePrefix string

@description('Storage account resource ID for Foundry.')
param storageAccountId string

@description('Key Vault resource ID for Foundry.')
param keyVaultId string

@description('Tags applied to resources.')
param tags object

var aiHubName = '${resourcePrefix}-aihub'
var aiProjectName = '${resourcePrefix}-aiproj'
var openAiName = toLower('${resourcePrefix}-openai-${uniqueString(resourceGroup().id)}')

resource aiHub 'Microsoft.MachineLearningServices/workspaces@2024-10-01' = {
  name: aiHubName
  location: location
  kind: 'Hub'
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: 'ServerWhisperer AI Hub'
    storageAccount: storageAccountId
    keyVault: keyVaultId
  }
}

resource aiProject 'Microsoft.MachineLearningServices/workspaces@2024-10-01' = {
  name: aiProjectName
  location: location
  kind: 'Project'
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: 'ServerWhisperer Diagnostics'
    hubResourceId: aiHub.id
  }
}

resource openAiAccount 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: openAiName
  location: location
  kind: 'OpenAI'
  tags: tags
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: openAiName
    publicNetworkAccess: 'Enabled'
  }
}

resource openAiDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = {
  name: '${openAiAccount.name}/gpt-4o-mini'
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4o-mini'
      version: '2024-07-18'
    }
    scaleSettings: {
      scaleType: 'Standard'
    }
  }
}

@description('AI Hub resource ID.')
output aiHubId string = aiHub.id

@description('AI Project resource ID.')
output aiProjectId string = aiProject.id

@description('OpenAI endpoint for Foundry workloads.')
output foundryEndpoint string = openAiAccount.properties.endpoint
