targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@metadata({
  azd: {
    type: 'location'
  }
})
param location string

param resourceGroupName string = ''
param functionPlanName string = ''
param functionAppName string = ''
param storageAccountName string = ''
param logAnalyticsName string = ''
param applicationInsightsName string = ''

@allowed(['dotnet-isolated','python','java', 'node', 'powerShell'])
param functionAppRuntime string = 'python'

@allowed(['3.10','3.11', '3.12', '7.4', '8.0', '9.0', '10', '11', '17', '20', '21', '22'])
param functionAppRuntimeVersion string = '3.11'

@minValue(40)
@maxValue(1000)
param maximumInstanceCount int = 100

@allowed([512,2048,4096])
param instanceMemoryMB int = 2048

param zoneRedundant bool = false

@description('Id of the user running this template, to be used for testing and debugging for access to Azure resources. This is not required in production. Leave empty if not needed.')
param principalId string = ''

var abbrs = loadJsonContent('./abbreviations.json')
// Generate a unique token to be used in naming resources.
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
// Generate a unique function app name if one is not provided.
var functionAppName_resolved = !empty(functionAppName) ? functionAppName : '${abbrs.webSitesFunctions}${resourceToken}'
// Generate a unique container name that will be used for deployments.
var deploymentStorageContainerName = 'app-package-${take(functionAppName_resolved, 32)}-${take(resourceToken, 7)}'
// tags that should be applied to all resources.
var tags = {
  // Tag all resources with the environment name.
  'azd-env-name': environmentName
}

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  location: location
  tags: tags
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
}

// Monitor application with Azure Monitor - Log Analytics and Application Insights
module logAnalytics 'br/public:avm/res/operational-insights/workspace:0.11.1' = {
  name: '${uniqueString(deployment().name, location)}-loganalytics'
  scope: rg
  params: {
    name: !empty(logAnalyticsName) ? logAnalyticsName : '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    location: location
    tags: tags
    dataRetention: 30
  }
}

module applicationInsights 'br/public:avm/res/insights/component:0.6.0' = {
  name: '${uniqueString(deployment().name, location)}-appinsights'
  scope: rg
  params: {
    name: !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.insightsComponents}${resourceToken}'
    location: location
    tags: tags
    workspaceResourceId: logAnalytics.outputs.resourceId
    disableLocalAuth: true
  }
}

// Backing storage for Azure Functions
module storage 'br/public:avm/res/storage/storage-account:0.25.0' = {
  name: 'storage'
  scope: rg
  params: {
    name: !empty(storageAccountName) ? storageAccountName : '${abbrs.storageStorageAccounts}${resourceToken}'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false // Disable local authentication methods as per policy
    dnsEndpointType: 'Standard'
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
    blobServices: {
      containers: [{name: deploymentStorageContainerName}]
    }
    tableServices:{}
    queueServices: {}
    minimumTlsVersion: 'TLS1_2'  // Enforcing TLS 1.2 for better security
    location: location
    tags: tags
  }
}

// Create an App Service Plan to group applications under the same payment plan and SKU
module appServicePlan 'br/public:avm/res/web/serverfarm:0.1.1' = {
  name: 'appserviceplan'
  scope: rg
  params: {
    name: !empty(functionPlanName) ? functionPlanName : '${abbrs.webServerFarms}${resourceToken}'
    sku: {
      name: 'FC1'
      tier: 'FlexConsumption'
    }
    reserved: true
    location: location
    tags: tags
    zoneRedundant: zoneRedundant
  }
}

// Azure Functions Flex Consumption
module functionApp 'br/public:avm/res/web/site:0.16.0' = {
  name: 'functionapp'
  scope: rg
  params: {
    kind: 'functionapp,linux'
    name: functionAppName_resolved
    location: location
    tags: union(tags, { 'azd-service-name': 'api' })
    serverFarmResourceId: appServicePlan.outputs.resourceId
    managedIdentities: {
      systemAssigned: true
    }
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: '${storage.outputs.primaryBlobEndpoint}${deploymentStorageContainerName}'
          authentication: {
            type: 'SystemAssignedIdentity'
          }
        }
      }
      scaleAndConcurrency: {
        maximumInstanceCount: maximumInstanceCount
        instanceMemoryMB: instanceMemoryMB
      }
      runtime: { 
        name: functionAppRuntime
        version: functionAppRuntimeVersion
      }
    }
    siteConfig: {
      alwaysOn: false
    }
    configs: [{
      name: 'appsettings'
      properties:{
        // Only include required credential settings unconditionally
        AzureWebJobsStorage__credential: 'managedidentity'
        AzureWebJobsStorage__blobServiceUri: 'https://${storage.outputs.name}.blob.${environment().suffixes.storage}'
        AzureWebJobsStorage__queueServiceUri: 'https://${storage.outputs.name}.queue.${environment().suffixes.storage}'
        AzureWebJobsStorage__tableServiceUri: 'https://${storage.outputs.name}.table.${environment().suffixes.storage}'

        // Application Insights settings are always included
        APPLICATIONINSIGHTS_CONNECTION_STRING: applicationInsights.outputs.connectionString
        APPLICATIONINSIGHTS_AUTHENTICATION_STRING: 'Authorization=AAD'
    }
    }]
  }
}

// Consolidated Role Assignments
module rbacAssignments 'rbac.bicep' = {
  name: 'rbacAssignments'
  scope: rg
  params: {
    storageAccountName: storage.outputs.name
    appInsightsName: applicationInsights.outputs.name
    managedIdentityPrincipalId: functionApp.outputs.?systemAssignedMIPrincipalId ?? ''
    userIdentityPrincipalId: principalId
    allowUserIdentityPrincipal: !empty(principalId)
  }
}

// Outputs
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_FUNCTION_NAME string = functionApp.outputs.name
output APPLICATIONINSIGHTS_CONNECTION_STRING string = applicationInsights.outputs.connectionString
