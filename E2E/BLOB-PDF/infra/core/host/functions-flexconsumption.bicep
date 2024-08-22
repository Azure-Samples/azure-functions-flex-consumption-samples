param name string
param location string = resourceGroup().location
param tags object = {}

// Reference Properties
param applicationInsightsName string = ''
param appServicePlanId string
param storageAccountName string

// Runtime Properties
@allowed([
  'dotnet-isolated', 'node', 'python', 'java', 'powershell', 'custom'
])
param runtimeName string
@allowed(['3.10', '3.11', '7.4', '8.0', '10', '11', '17', '20'])
param runtimeVersion string
param kind string = 'functionapp,linux'

// Microsoft.Web/sites/config
param appSettings object = {}
param instanceMemoryMB int = 2048
param maximumInstanceCount int = 100
param virtualNetworkSubnetId string = ''
param deploymentStorageContainerName string

resource stg 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: storageAccountName
}

resource functions 'Microsoft.Web/sites@2023-12-01' = {
  name: '${name}-functions'
  location: location
  tags: tags
  kind: kind

  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlanId
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: '${stg.properties.primaryEndpoints.blob}${deploymentStorageContainerName}'
          authentication: {
            type: 'SystemAssignedIdentity'
          }
        }
      }
      scaleAndConcurrency: {
        instanceMemoryMB: instanceMemoryMB
        maximumInstanceCount: maximumInstanceCount
      }
      runtime: {
        name: runtimeName
        version: runtimeVersion
      }
    }
    virtualNetworkSubnetId: !empty(virtualNetworkSubnetId) ? virtualNetworkSubnetId : null
  }
  resource configAppSettings 'config' = {
    name: 'appsettings'
    properties: union(appSettings,
      {
        AzureWebJobsStorage__accountName: stg.name
        APPLICATIONINSIGHTS_CONNECTION_STRING: applicationInsights.properties.ConnectionString
      })
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = if (!empty(applicationInsightsName)) {
  name: applicationInsightsName
}

output name string = functions.name
output uri string = 'https://${functions.properties.defaultHostName}'
output identityPrincipalId string = functions.identity.principalId
