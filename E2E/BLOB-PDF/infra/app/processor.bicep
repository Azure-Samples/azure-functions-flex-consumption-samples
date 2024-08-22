param name string
param location string = resourceGroup().location
param tags object = {}
param applicationInsightsName string = ''
param appServicePlanId string
param runtimeName string
param runtimeVersion string
param serviceName string = 'processor'
param storageAccountName string
param instanceMemoryMB int = 2048
param maximumInstanceCount int = 100
param appSettings object = {}
param virtualNetworkSubnetId string
param deploymentStorageContainerName string

module processor '../core/host/functions-flexconsumption.bicep' = {
  name: '${serviceName}-functions-node-module'
  params: {
    name: name
    location: location
    tags: union(tags, { 'azd-service-name': serviceName })
    applicationInsightsName: applicationInsightsName
    appServicePlanId: appServicePlanId
    runtimeName: runtimeName
    runtimeVersion: runtimeVersion
    storageAccountName: storageAccountName
    instanceMemoryMB: instanceMemoryMB 
    maximumInstanceCount: maximumInstanceCount 
    virtualNetworkSubnetId: virtualNetworkSubnetId
    deploymentStorageContainerName:deploymentStorageContainerName
    appSettings: union(appSettings,
      {
        PDFProcessorSTORAGE__accountName: storageAccountName
      })
  }
}

output SERVICE_PROCESSOR_IDENTITY_PRINCIPAL_ID string = processor.outputs.identityPrincipalId
output SERVICE_PROCESSOR_NAME string = processor.outputs.name
output SERVICE_PROCESSOR_URI string = processor.outputs.uri
