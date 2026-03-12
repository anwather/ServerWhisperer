@description('Location for Key Vault resources.')
param location string

@description('Prefix used for resource names.')
param resourcePrefix string

@description('Teams webhook URL to store as a secret.')
@secure()
param teamsWebhookUrl string

@description('Tags applied to resources.')
param tags object

var keyVaultName = toLower('${resourcePrefix}-kv-${uniqueString(resourceGroup().id)}')

resource keyVault 'Microsoft.KeyVault/vaults@2024-01-01' = {
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

resource teamsSecret 'Microsoft.KeyVault/vaults/secrets@2024-01-01' = {
  name: '${keyVault.name}/TeamsWebhookUrl'
  properties: {
    value: teamsWebhookUrl
  }
}

@description('Key Vault resource ID.')
output keyVaultId string = keyVault.id

@description('Key Vault name.')
output keyVaultName string = keyVault.name

@description('Teams webhook secret URI.')
output teamsWebhookSecretUri string = teamsSecret.properties.secretUriWithVersion
