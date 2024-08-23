targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
@allowed(['australiaeast', 'eastasia', 'eastus', 'eastus2', 'northeurope', 'southcentralus', 'southeastasia', 'swedencentral', 'uksouth', 'westus2', 'eastus2euap'])
@metadata({
  azd: {
    type: 'location'
  }
})
param location string
param skipVnet bool = false
param processorServiceName string = ''
param applicationInsightsDashboardName string = ''
param applicationInsightsName string = ''
param appServicePlanName string = ''
param logAnalyticsName string = ''
param resourceGroupName string = ''
param storageAccountName string = ''
param processedTextContainerName string = 'processed-text'
param unprocessedPdfContainerName string = 'unprocessed-pdf'


@description('Id of the user or app to assign application roles')
param principalId string = ''

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
// Generate a unique function app name if one is not provided.
var appName = !empty(processorServiceName) ? processorServiceName : '${abbrs.webSitesFunctions}${resourceToken}'
// Generate a unique container name that will be used for deployments.
var deploymentStorageContainerName = 'app-package-${take(appName, 32)}-${take(resourceToken, 7)}'
var tags = { 'azd-env-name': environmentName }
param vNetName string = ''

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

// The application backend powered by Flex Consumption Function
module processor 'app/processor.bicep' = {
  name: 'processor'
  scope: rg
  params: {
    name: appName
    serviceName: 'processor'
    location: location
    tags: tags
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    appServicePlanId: processorAppServicePlan.outputs.id
    runtimeName: 'node'
    runtimeVersion: '20'
    storageAccountName: storage.outputs.name
    deploymentStorageContainerName: deploymentStorageContainerName
    virtualNetworkSubnetId: skipVnet ? '' : vnet.outputs.appSubnetID
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
module storage 'core/storage/storage-account.bicep' = {
  name: 'storage'
  scope: rg
  params: {
    name: !empty(storageAccountName) ? storageAccountName : '${abbrs.storageStorageAccounts}${resourceToken}'
    location: location
    tags: tags
    containers: [
      {name: deploymentStorageContainerName}
      {name: processedTextContainerName}
      {name: unprocessedPdfContainerName}
     ]
     networkAcls: skipVnet ? {} : {
        defaultAction: 'Deny'
      }
  }
}

module vnet './app/vnet.bicep' = if (!skipVnet) {
  name: 'vnet'
  scope: rg
  params: {
    location: location
    tags: tags
    vNetName: !empty(vNetName) ? vNetName : '${abbrs.networkVirtualNetworks}${resourceToken}'
  }
}

module servicePrivateEndpoint 'app/storage-PrivateEndpoint.bicep' = if (!skipVnet) {
  name: 'servicePrivateEndpoint'
  scope: rg
  params: {
    location: location
    tags: tags
    virtualNetworkName: !empty(vNetName) ? vNetName : '${abbrs.networkVirtualNetworks}${resourceToken}'
    subnetName: skipVnet ? '' : vnet.outputs.peSubnetName
    resourceName: storage.outputs.name
  }
}

var storageBlobDataOwnerRoleDefinitionId  = 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b' //Storage Blob Data Owner
var storageAccountDataContributorRoleDefinitionId  = '17d1049b-9a84-46fb-8f53-869881c3d3ab' //Storage Account Contributor
var storageQueueDataContributorRoleDefinitionId  = '974c5e8b-45b9-4653-ba55-5f855dd0fb88' //Storage Queue Data Contributor

// Allow access from processor to storage account using a managed identity and Storage Blob Data Owner role
module storageBlobDataOwnerRoleAssignmentprocessor 'app/storage-Access.bicep' = {
  name: 'storageBlobDataOwnerRoleAssignmentprocessor'
  scope: rg
  params: {
    storageAccountName: storage.outputs.name
    roleDefinitionID: storageBlobDataOwnerRoleDefinitionId
    principalIDs: [processor.outputs.SERVICE_PROCESSOR_IDENTITY_PRINCIPAL_ID, principalId]
  }
}
module storageAccountDataContributorRoleAssignmentprocessor 'app/storage-Access.bicep' = {
  name: 'storageAccountDataContributorRoleAssignmentprocessor'
  scope: rg
  params: {
    storageAccountName: storage.outputs.name
    roleDefinitionID: storageAccountDataContributorRoleDefinitionId
    principalIDs: [processor.outputs.SERVICE_PROCESSOR_IDENTITY_PRINCIPAL_ID, principalId]
  }
}
module storageQueueDataContributorRoleAssignmentprocessor 'app/storage-Access.bicep' = {
  name: 'storageQueueDataContributorRoleAssignmentprocessor'
  scope: rg
  params: {
    storageAccountName: storage.outputs.name
    roleDefinitionID: storageQueueDataContributorRoleDefinitionId
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

module eventgripdftopic './app/eventgrid.bicep' = {
  name: 'eventgripdf'
  scope: rg
  params: {
    location: location
    tags: tags
    storageAccountId: storage.outputs.id
  }
}

// App outputs
output APPLICATIONINSIGHTS_CONNECTION_STRING string = monitoring.outputs.applicationInsightsConnectionString
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output SERVICE_processor_BASE_URL string = processor.outputs.SERVICE_PROCESSOR_URI
output RESOURCE_GROUP string = rg.name
output AZURE_FUNCTION_APP_NAME string = processor.outputs.SERVICE_PROCESSOR_NAME
output UNPROCESSED_PDF_CONTAINER_NAME string = unprocessedPdfContainerName
output UNPROCESSED_PDF_SYSTEM_TOPIC_NAME string = eventgripdftopic.outputs.unprocessedPdfSystemTopicName
