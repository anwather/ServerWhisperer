@description('Location for search resources.')
param location string

@description('Prefix used for resource names.')
param resourcePrefix string

@description('Tags applied to resources.')
param tags object

var searchServiceName = toLower('${resourcePrefix}-search-${uniqueString(resourceGroup().id)}')
var indexName = 'investigation-reports'

resource searchService 'Microsoft.Search/searchServices@2023-11-01' = {
  name: searchServiceName
  location: location
  tags: tags
  sku: {
    name: 'free'
  }
  properties: {
    replicaCount: 1
    partitionCount: 1
    hostingMode: 'default'
    publicNetworkAccess: 'enabled'
  }
}

// Index created post-deploy via create-foundry-agent.ps1 (ARM index API doesn't support free tier vector search)

@description('Search service name.')
output searchServiceName string = searchService.name

@description('Search index name.')
output searchIndexName string = indexName
