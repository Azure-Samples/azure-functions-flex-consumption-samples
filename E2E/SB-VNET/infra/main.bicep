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

@secure()
@description('A password for the admin login of the virtual machine')
param vmAdminPassword string

param processorServiceName string = ''
param processorUserAssignedIdentityName string = ''
param applicationInsightsName string = ''
param appServicePlanName string = ''
param logAnalyticsName string = ''
param resourceGroupName string = ''
param storageAccountName string = ''
param serviceBusQueueName string = ''
param serviceBusNamespaceName string = ''
param vNetName string = ''

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

// User assigned managed identity to be used by the Function App to reach storage and service bus
module processorUserAssignedIdentity './core/identity/userAssignedIdentity.bicep' = {
  name: 'processorUserAssignedIdentity'
  scope: rg
  params: {
    location: location
    tags: tags
    identityName: !empty(processorUserAssignedIdentityName) ? processorUserAssignedIdentityName : '${abbrs.managedIdentityUserAssignedIdentities}processor-${resourceToken}'
  }
}

// The application backend
module processor './app/processor.bicep' = {
  name: 'processor'
  scope: rg
  params: {
    name: !empty(processorServiceName) ? processorServiceName : '${abbrs.webSitesFunctions}processor-${resourceToken}'
    location: location
    tags: tags
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    appServicePlanId: appServicePlan.outputs.id
    runtimeName: 'python'
    runtimeVersion: '3.10'
    storageAccountName: storage.outputs.name
    identityId: processorUserAssignedIdentity.outputs.identityId
    identityClientId: processorUserAssignedIdentity.outputs.identityClientId
    appSettings: {
    }
    virtualNetworkSubnetId: serviceVirtualNetwork.outputs.appSubnetID
    serviceBusQueueName: serviceBus.outputs.serviceBusQueueName
    serviceBusNamespaceFQDN: serviceBus.outputs.serviceBusNamespaceFQDN
  }
}

// Backing storage for Azure functions processor
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

var storageRoleDefinitionId  = 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b' //Storage Blob Data Owner role

// Allow access from processor to storage account using a managed identity
module storageRoleAssignmentApi 'app/storage-Access.bicep' = {
  name: 'storageRoleAssignmentPRocessor'
  scope: rg
  params: {
    storageAccountName: storage.outputs.name
    roleDefinitionID: storageRoleDefinitionId
    principalID: processorUserAssignedIdentity.outputs.identityPrincipalId
  }
}

module appServicePlan './core/host/appserviceplan.bicep' = {
  name: 'appserviceplan'
  scope: rg
  params: {
    name: !empty(appServicePlanName) ? appServicePlanName : '${abbrs.webServerFarms}${resourceToken}'
    location: location
    tags: tags
    sku: {
      name: 'FC1'
      tier: 'FlexConsumption'
    }
  }
}

// Service Bus
module serviceBus 'core/message/servicebus.bicep' = {
  name: 'serviceBus'
  scope: rg
  params: {
    location: location
    tags: tags
    serviceBusNamespaceName: !empty(serviceBusNamespaceName) ? serviceBusNamespaceName : '${abbrs.serviceBusNamespaces}${resourceToken}'
    serviceBusQueueName : !empty(serviceBusQueueName) ? serviceBusQueueName : '${abbrs.serviceBusNamespacesQueues}${resourceToken}'
  }
}

var ServiceBusRoleDefinitionIds  = ['090c5cfd-751d-490a-894a-3ce6f1109419', '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0'] //Azure Service Bus Data Owner and Data Receiver roles

// Allow access from processor to Service Bus using a managed identity and Azure Service Bus Data Owner and Data Receiver roles
module ServiceBusDataOwnerRoleAssignment 'app/servicebus-Access.bicep' = {
  name: 'ServiceBusDataOwnerRoleAssignment'
  scope: rg
  params: {
    serviceBusNamespaceName: serviceBus.outputs.serviceBusNamespace
    roleDefinitionIDs: ServiceBusRoleDefinitionIds
    principalID: processorUserAssignedIdentity.outputs.identityPrincipalId
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
  }
}

module bastion 'core/networking/bastion.bicep' = {
  name: 'bastion'
  scope: rg
  params: {
    location: location
    tags: tags
    bastionSubnetId: serviceVirtualNetwork.outputs.bastionSubnetID
  }
}

module vm 'core/compute/vm.bicep' = {
  name: 'vm'
  scope: rg
  params: {
    adminpassword: vmAdminPassword
    location: location
    VMsubnetId: serviceVirtualNetwork.outputs.vmSubnetID
  }
}

module servicePrivateEndpoint 'core/networking/privateEndpoint.bicep' = {
  name: 'servicePrivateEndpoint'
  scope: rg
  params: {
    location: location
    tags: tags
    virtualNetworkName: !empty(vNetName) ? vNetName : '${abbrs.networkVirtualNetworks}${resourceToken}'
    subnetName: serviceVirtualNetwork.outputs.sbSubnetName
    sbNamespaceId: serviceBus.outputs.namespaceId
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
  }
}

// App outputs
output APPLICATIONINSIGHTS_CONNECTION_STRING string = monitoring.outputs.applicationInsightsConnectionString
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output SERVICE_PROCESSOR_NAME string = processor.outputs.SERVICE_PROCESSOR_NAME
output AZURE_FUNCTION_NAME string = processor.outputs.SERVICE_PROCESSOR_NAME
