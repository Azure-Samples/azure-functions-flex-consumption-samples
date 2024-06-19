param name string
param location string = resourceGroup().location
param tags object = {}
param applicationInsightsName string = ''
param appServicePlanId string
param appSettings object = {}
param runtimeName string
param runtimeVersion string
param serviceName string = 'api'
param storageAccountName string
param virtualNetworkSubnetId string = ''
param eventHubFQDN string = ''
param eventHubName string = ''
param instanceMemoryMB int = 2048
param maximumInstanceCount int = 100

module api '../core/host/functions-flexconsumption.bicep' = {
  name: '${serviceName}-functions-dotnet-isolated-module'
  params: {
    name: name
    location: location
    tags: union(tags, { 'azd-service-name': serviceName })
    appSettings: union(appSettings,
      {
        EventHubConnection__fullyQualifiedNamespace: eventHubFQDN
        EventHubName: eventHubName
      })
    applicationInsightsName: applicationInsightsName
    appServicePlanId: appServicePlanId
    runtimeName: runtimeName
    runtimeVersion: runtimeVersion
    storageAccountName: storageAccountName
    instanceMemoryMB: instanceMemoryMB //needed for Flex
    maximumInstanceCount: maximumInstanceCount //needed for Flex
    virtualNetworkSubnetId: virtualNetworkSubnetId
  }
}

output SERVICE_API_IDENTITY_PRINCIPAL_ID string = api.outputs.identityPrincipalId
output SERVICE_API_NAME string = api.outputs.name
output SERVICE_API_URI string = api.outputs.uri
