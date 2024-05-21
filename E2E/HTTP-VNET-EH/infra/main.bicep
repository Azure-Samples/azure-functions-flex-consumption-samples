targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

// Optional parameters to override the default azd resource naming conventions. Update the main.parameters.json file to provide values. e.g.,:
// "resourceGroupName": {
//      "value": "myGroupName"
// }
param apiServiceName string = ''
param applicationInsightsDashboardName string = ''
param applicationInsightsName string = ''
param appServicePlanName string = ''
param logAnalyticsName string = ''
param resourceGroupName string = ''
param storageAccountName string = ''
param eventHubName string = ''
param eventHubNamespaceName string = ''
param vNetName string = ''
param ehSubnetName string = ''
param appSubnetName string = ''

@description('Id of the user or app to assign application roles')
param principalId string = ''

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

// The application backend powered by Flex Consumption Function
module api './app/api.bicep' = {
  name: 'api'
  scope: rg
  params: {
    name: !empty(apiServiceName) ? apiServiceName : '${abbrs.webSitesFunctions}api-${resourceToken}'
    serviceName: 'api'
    location: location
    tags: tags
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    appServicePlanId: apiAppServicePlan.outputs.id
    runtimeName: 'dotnet-isolated'
    runtimeVersion: '8.0'
    instanceMemoryMB: 2048
    maximumInstanceCount: 100
    storageAccountName: storage.outputs.name
    appSettings: {
    }
    virtualNetworkSubnetId: serviceVirtualNetwork.outputs.appSubnetID
    eventHubName: eventHubs.outputs.eventHubName
    eventHubFQDN: eventHubs.outputs.namespaceFQDN
  }
}

// Create an App Service Plan to group applications under the same payment plan and SKU
module apiAppServicePlan 'core/host/appserviceplan.bicep' = {
  name: 'apiAppServicePlan'
  scope: rg
  params: {
    name: !empty(appServicePlanName) ? appServicePlanName : '${abbrs.webServerFarms}api${resourceToken}'
    location: location
    tags: tags
    sku: {
      name: 'FC1'
      tier: 'FlexConsumption'
      size: 'FC'
      family: 'FC'
    }
    reserved: true
  }
}

// Backing storage for Azure functions backend API
module storage './core/storage/storage-account.bicep' = {
  name: 'storage'
  scope: rg
  params: {
    name: !empty(storageAccountName) ? storageAccountName : '${abbrs.storageStorageAccounts}${resourceToken}'
    location: location
    tags: tags
    containers: [{name: 'deploymentpackage'}]
  }
}

var storageRoleDefinitionId  = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe' //Storage Blob Data Contributor role

// Allow access from API to storage account using a managed identity and Storage Blob Data Owner role
module storageRoleAssignmentApi 'app/storage-Access.bicep' = {
  name: 'storageRoleAssignmentApi'
  scope: rg
  params: {
    storageAccountName: storage.outputs.name
    roleDefinitionID: storageRoleDefinitionId
    principalIDs: [api.outputs.SERVICE_API_IDENTITY_PRINCIPAL_ID, principalId]
  }
}

// Event Hubs
module eventHubs 'core/message/eventhubs.bicep' = {
  name: 'eventHubs'
  scope: rg
  params: {
    location: location
    tags: tags
    eventHubNamespaceName: !empty(eventHubNamespaceName) ? eventHubNamespaceName : '${abbrs.eventHubNamespaces}${resourceToken}'
    eventHubName: !empty(eventHubName) ? eventHubName : '${abbrs.eventHubNamespacesEventHubs}${resourceToken}'
  }
}

// Azure Event Hubs Data Sender role
var eventHubsSenderRoleDefinitionId  = '2b629674-e913-4c01-ae53-ef4638d8f975'

module eventHubsSenderRoleAssignmentApi 'app/eventhubs-Access.bicep' = {
  name:'eventHubsSenderRoleAssignment'
  scope: rg
  params: {
    eventHubsNamespaceName: eventHubs.outputs.eventHubNamespaceName
    eventHubName: eventHubs.outputs.eventHubName
    roleDefinitionID: eventHubsSenderRoleDefinitionId
    principalIDs: [api.outputs.SERVICE_API_IDENTITY_PRINCIPAL_ID, principalId]
  }
}

// Virtual Network & private endpoint
module serviceVirtualNetwork 'core/networking/vnet.bicep' = {
  name: 'serviceVirtualNetwork'
  scope: rg
  params: {
    location: location
    tags: tags
    vNetName: !empty(vNetName) ? vNetName : '${abbrs.networkVirtualNetworks}${resourceToken}'
    ehSubnetName: !empty(ehSubnetName) ? ehSubnetName : '${abbrs.networkVirtualNetworksSubnets}eh${resourceToken}'  
    appSubnetName: !empty(appSubnetName) ? appSubnetName : '${abbrs.networkVirtualNetworksSubnets}app${resourceToken}'  
  }
}

module servicePrivateEndpoint 'core/networking/privateEndpoint.bicep' = {
  name: 'servicePrivateEndpoint'
  scope: rg
  params: {
    location: location
    tags: tags
    virtualNetworkName: !empty(vNetName) ? vNetName : '${abbrs.networkVirtualNetworks}${resourceToken}'
    subnetName: !empty(ehSubnetName) ? ehSubnetName : '${abbrs.networkVirtualNetworksSubnets}eh${resourceToken}' 
    ehNamespaceId: eventHubs.outputs.namespaceId
  }
}


// Monitor application with Azure Monitor
module monitoring './core/monitor/monitoring.bicep' = {
  name: 'monitoring'
  scope: rg
  params: {
    location: location
    tags: tags
    logAnalyticsName: !empty(logAnalyticsName) ? logAnalyticsName : '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    applicationInsightsName: !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.insightsComponents}${resourceToken}'
    applicationInsightsDashboardName: !empty(applicationInsightsDashboardName) ? applicationInsightsDashboardName : '${abbrs.portalDashboards}${resourceToken}'
  }
}

// App outputs
output APPLICATIONINSIGHTS_CONNECTION_STRING string = monitoring.outputs.applicationInsightsConnectionString
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output SERVICE_API_BASE_URL string = api.outputs.SERVICE_API_URI
output RESOURCE_GROUP string = rg.name
output AZURE_FUNCTION_NAME string = api.outputs.SERVICE_API_NAME
