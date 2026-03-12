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

resource reportsIndex 'Microsoft.Search/searchServices/indexes@2023-11-01' = {
  name: '${searchService.name}/${indexName}'
  properties: {
    fields: [
      {
        name: 'id'
        type: 'Edm.String'
        key: true
        searchable: false
        filterable: true
        sortable: false
        facetable: false
      }
      {
        name: 'timestamp'
        type: 'Edm.DateTimeOffset'
        searchable: false
        filterable: true
        sortable: true
        facetable: false
      }
      {
        name: 'serverName'
        type: 'Edm.String'
        searchable: true
        filterable: true
        sortable: true
        facetable: true
      }
      {
        name: 'alertType'
        type: 'Edm.String'
        searchable: true
        filterable: true
        sortable: true
        facetable: true
      }
      {
        name: 'severity'
        type: 'Edm.String'
        searchable: true
        filterable: true
        sortable: true
        facetable: true
      }
      {
        name: 'rootCause'
        type: 'Edm.String'
        searchable: true
        filterable: false
        sortable: false
        facetable: false
      }
      {
        name: 'fullReport'
        type: 'Edm.String'
        searchable: true
        filterable: false
        sortable: false
        facetable: false
      }
      {
        name: 'embedding'
        type: 'Collection(Edm.Single)'
        searchable: false
        filterable: false
        sortable: false
        facetable: false
        vectorSearchDimensions: 1536
        vectorSearchConfiguration: 'default'
      }
    ]
    vectorSearch: {
      algorithmConfigurations: [
        {
          name: 'default'
          kind: 'hnsw'
          hnswParameters: {
            m: 4
            efConstruction: 400
            efSearch: 500
            metric: 'cosine'
          }
        }
      ]
    }
  }
}

@description('Search service name.')
output searchServiceName string = searchService.name

@description('Search index name.')
output searchIndexName string = indexName
