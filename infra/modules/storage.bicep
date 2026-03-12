@description('Location for storage resources.')
param location string

@description('Prefix used for resource names.')
param resourcePrefix string

@description('Tags applied to resources.')
param tags object

var storageAccountName = toLower('${resourcePrefix}sa${uniqueString(resourceGroup().id)}')

resource storageAccount 'Microsoft.Storage/storageAccounts@2024-01-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    allowSharedKeyAccess: true
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2024-01-01' = {
  name: '${storageAccount.name}/default'
  properties: {
    cors: {
      corsRules: [
        {
          allowedOrigins: [
            '*'
          ]
          allowedMethods: [
            'GET'
            'POST'
            'PUT'
            'OPTIONS'
          ]
          allowedHeaders: [
            '*'
          ]
          exposedHeaders: [
            '*'
          ]
          maxAgeInSeconds: 3600
        }
      ]
    }
  }
}

resource reportsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2024-01-01' = {
  name: '${storageAccount.name}/default/reports'
  properties: {
    publicAccess: 'None'
  }
  dependsOn: [
    blobService
  ]
}

resource diagnosticsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2024-01-01' = {
  name: '${storageAccount.name}/default/diagnostics'
  properties: {
    publicAccess: 'None'
  }
  dependsOn: [
    blobService
  ]
}

resource functionDeployContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2024-01-01' = {
  name: '${storageAccount.name}/default/function-deploy'
  properties: {
    publicAccess: 'None'
  }
  dependsOn: [
    blobService
  ]
}

@description('Storage account name.')
output storageAccountName string = storageAccount.name

@description('Storage account resource ID.')
output storageAccountId string = storageAccount.id
