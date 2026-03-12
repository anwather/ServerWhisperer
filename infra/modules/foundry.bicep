@description('Location for Foundry resources.')
param location string

@description('Prefix used for resource names.')
param resourcePrefix string

@description('Tags applied to resources.')
param tags object

var accountName = toLower('${resourcePrefix}-foundry-${uniqueString(resourceGroup().id)}')
var projectName = '${resourcePrefix}-project'

resource aiAccount 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: accountName
  location: location
  kind: 'AIServices'
  tags: tags
  sku: {
    name: 'S0'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    customSubDomainName: accountName
    publicNetworkAccess: 'Enabled'
  }
}

resource aiProject 'Microsoft.CognitiveServices/accounts/projects@2024-10-01' = {
  name: projectName
  parent: aiAccount
  properties: {
    friendlyName: 'ServerWhisperer Diagnostics'
  }
}

resource modelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = {
  name: 'gpt-4o-mini'
  parent: aiAccount
  sku: {
    name: 'GlobalStandard'
    capacity: 10
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4o-mini'
      version: '2024-07-18'
    }
  }
  dependsOn: [
    aiProject
  ]
}

@description('Foundry account resource ID.')
output accountId string = aiAccount.id

@description('Foundry project resource ID.')
output projectId string = aiProject.id

@description('Foundry project endpoint for Agents API.')
output foundryEndpoint string = 'https://${aiAccount.name}.services.ai.azure.com/api/projects/${aiProject.name}'

@description('Foundry account principal ID for RBAC.')
output accountPrincipalId string = aiAccount.identity.principalId
