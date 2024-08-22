param name string
param location string = resourceGroup().location
param tags object = {}
param applicationInsightsName string = ''
param appServicePlanId string
param appSettings object = {}
param runtimeName string 
param runtimeVersion string 
param serviceName string = 'processor'
param storageAccountName string
param virtualNetworkSubnetId string = ''
param serviceBusQueueName string = ''
param serviceBusNamespaceFQDN string = ''
param instanceMemoryMB int = 2048
param maximumInstanceCount int = 100
param identityId string = ''
param identityClientId string = ''
param deploymentStorageContainerName string

module processor '../core/host/functions-flexconsumption.bicep' = {
  name: '${serviceName}-functions-python-module'
  params: {
    name: name
    location: location
    tags: union(tags, { 'azd-service-name': serviceName })
    identityType: 'UserAssigned'
    identityId: identityId
    appSettings: union(appSettings,
      {
        ServiceBusConnection__fullyQualifiedNamespace: serviceBusNamespaceFQDN
        ServiceBusConnection__clientId : identityClientId
        ServiceBusConnection__credential : 'managedidentity'
        AzureWebJobsStorage__clientId : identityClientId
        ServiceBusQueueName: serviceBusQueueName
      })
    applicationInsightsName: applicationInsightsName
    appServicePlanId: appServicePlanId
    runtimeName: runtimeName
    runtimeVersion: runtimeVersion
    storageAccountName: storageAccountName
    virtualNetworkSubnetId: virtualNetworkSubnetId
    instanceMemoryMB: instanceMemoryMB 
    maximumInstanceCount: maximumInstanceCount
    deploymentStorageContainerName: deploymentStorageContainerName
  }
}

output SERVICE_PROCESSOR_NAME string = processor.outputs.name
output SERVICE_API_IDENTITY_PRINCIPAL_ID string = processor.outputs.identityPrincipalId
