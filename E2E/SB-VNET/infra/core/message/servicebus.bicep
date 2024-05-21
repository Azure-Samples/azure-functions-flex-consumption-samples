param serviceBusQueueName string
param serviceBusNamespaceName string
param location string = resourceGroup().location
param tags object = {}

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = {
  name: serviceBusNamespaceName
  location: location
  tags: tags
  sku: {
    name: 'Premium'    
  }
  properties: {
    publicNetworkAccess: 'Disabled'
  }
}

resource serviceBusQueue  'Microsoft.ServiceBus/namespaces/queues@2022-01-01-preview' = {
  parent: serviceBusNamespace
  name: serviceBusQueueName
}

resource serviceBusManageAccessKey 'Microsoft.ServiceBus/namespaces/AuthorizationRules@2022-10-01-preview' existing = {
  parent: serviceBusNamespace
  name: 'RootManageSharedAccessKey'
}

output namespaceId string = serviceBusNamespace.id
output serviceBusQueueName string = serviceBusQueue.name
output serviceBusNamespaceFQDN string = '${serviceBusNamespace.name}.servicebus.windows.net'
output serviceBusManageAccessKeyId string = serviceBusManageAccessKey.id
output serviceBusNamespace string = serviceBusNamespace.name
