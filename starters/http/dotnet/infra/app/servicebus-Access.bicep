param serviceBusNamespaceName string
param roleDefinitionIDs array
param principalID string


resource ServiceBusResource 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' existing = {
  name: serviceBusNamespaceName
}

resource ServiceBusRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = [for roleDefinitionID in roleDefinitionIDs: {
  name: guid(ServiceBusResource.id, principalID, roleDefinitionID)
  scope: ServiceBusResource
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionID)
    principalId: principalID
  }
}]
