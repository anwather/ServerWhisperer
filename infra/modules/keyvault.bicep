@description('Location for Key Vault resources.')
param location string

@description('Prefix used for resource names.')
param resourcePrefix string

@description('GitHub Personal Access Token to store as a secret.')
@secure()
param githubToken string

@description('Tags applied to resources.')
param tags object

var keyVaultName = toLower('${resourcePrefix}-kv-${uniqueString(resourceGroup().id)}')

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    publicNetworkAccess: 'Enabled'
    sku: {
      name: 'standard'
      family: 'A'
    }
  }
}

resource githubTokenSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: '${keyVault.name}/GitHubToken'
  properties: {
    value: githubToken
  }
}

@description('Key Vault resource ID.')
output keyVaultId string = keyVault.id

@description('Key Vault name.')
output keyVaultName string = keyVault.name

@description('GitHub token secret URI.')
output githubTokenSecretUri string = githubTokenSecret.properties.secretUriWithVersion
