@description('Location for Event Grid resources.')
param location string

@description('Prefix used for resource names.')
param resourcePrefix string

@description('Webhook URL for Event Grid subscription.')
param functionWebhookUrl string

@description('Tags applied to resources.')
param tags object

resource systemTopic 'Microsoft.EventGrid/systemTopics@2024-06-01' = {
  name: '${resourcePrefix}-alerts-topic'
  location: location
  tags: tags
  properties: {
    source: resourceGroup().id
    topicType: 'Microsoft.Resources.ResourceGroups'
  }
}

resource subscription 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2024-06-01' = {
  name: '${systemTopic.name}/alerts-to-function'
  properties: {
    destination: {
      endpointType: 'WebHook'
      properties: {
        endpointUrl: functionWebhookUrl
      }
    }
    filter: {
      isSubjectCaseSensitive: false
    }
    eventDeliverySchema: 'EventGridSchema'
  }
}
