param eventHubName string
param eventHubNamespaceName string
param location string = resourceGroup().location
param tags object = {}

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2023-01-01-preview' = {
  name: eventHubNamespaceName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Standard'
    capacity: 40
  }
  properties: {
    publicNetworkAccess: 'Disabled'
  }
}

resource eventHub 'Microsoft.EventHub/namespaces/eventhubs@2023-01-01-preview' = {
  parent: eventHubNamespace
  name: eventHubName
  properties: {
    retentionDescription: {
      cleanupPolicy: 'Delete'
      retentionTimeInHours: 24
    }
    messageRetentionInDays: 1
    partitionCount: 32
  }
}

resource eventHubSendAccessKey 'Microsoft.EventHub/namespaces/authorizationrules@2023-01-01-preview' = {
  parent: eventHubNamespace
  name: 'SendAccessKey'
  properties: {
    rights: [
      'Send'
    ]
  }
}

output namespaceId string = eventHubNamespace.id
output namespaceFQDN string = '${eventHubNamespace.name}.servicebus.windows.net'
output eventHubNamespaceName string = eventHubNamespace.name
output eventHubName string = eventHub.name
output eventHubSendAccessKeyId string = eventHubSendAccessKey.id
