targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

param processorServiceName string = ''
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
resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

// The application backend powered by Flex Consumption Function
module processor './app/processor.bicep' = {
  name: 'processor'
  scope: rg
  params: {
    name: !empty(processorServiceName) ? processorServiceName : '${abbrs.webSitesFunctions}processor-${resourceToken}'
    serviceName: 'processor'
    location: location
    tags: tags
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    appServicePlanId: processorAppServicePlan.outputs.id
    runtimeName: 'node'
    runtimeVersion: '20'
    instanceMemoryMB: 2048
    maximumInstanceCount: 100
    storageAccountName: storage.outputs.name
    appSettings: {
    }
  }
}

// Create an App Service Plan to group applications under the same payment plan and SKU
module processorAppServicePlan 'core/host/appserviceplan.bicep' = {
  name: 'processorAppServicePlan'
  scope: rg
  params: {
    name: !empty(appServicePlanName) ? appServicePlanName : '${abbrs.webServerFarms}processor${resourceToken}'
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

// Backing storage for Azure functions backend processor
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

// Allow access from processor to storage account using a managed identity and Storage Blob Data Owner role
module storageRoleAssignmentprocessor 'app/storage-Access.bicep' = {
  name: 'storageRoleAssignmentprocessor'
  scope: rg
  params: {
    storageAccountName: storage.outputs.name
    roleDefinitionID: storageRoleDefinitionId
    principalIDs: [processor.outputs.SERVICE_PROCESSOR_IDENTITY_PRINCIPAL_ID, principalId]
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
output SERVICE_processor_BASE_URL string = processor.outputs.SERVICE_PROCESSOR_URI
output RESOURCE_GROUP string = rg.name
output AZURE_FUNCTION_NAME string = processor.outputs.SERVICE_PROCESSOR_NAME
