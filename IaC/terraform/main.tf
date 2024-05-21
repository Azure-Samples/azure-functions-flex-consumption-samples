terraform {
    required_providers {
      azurerm = {
        source = "hashicorp/azurerm"
      }
      azapi = {
        source = "Azure/azapi"
      }
    }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  location = var.location
  name     = var.resourceGroupName
}

resource "azapi_resource" "serverFarm" {
  type = "Microsoft.Web/serverfarms@2023-12-01"
  schema_validation_enabled = false
  location = var.location
  name = var.functionPlanName
  parent_id = azurerm_resource_group.rg.id
  body = jsonencode({
      kind = "functionapp",
      sku = {
        tier = "FlexConsumption",
        name = "FC1"
      },
      properties = {
        reserved = true
      }
  })
}

resource "azurerm_storage_account" "storageAccount" {
  name                     = var.storageAccountName
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "storageContainer" {
  name                  = "deploymentpackage"
  storage_account_name  = azurerm_storage_account.storageAccount.name
  container_access_type = "private"
}

resource "azurerm_log_analytics_workspace" "logAnalyticsWorkspace" {
  name                = var.logAnalyticsName
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_application_insights" "appInsights" {
  name                = var.applicationInsightsName
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  application_type    = "web"
  workspace_id = azurerm_log_analytics_workspace.logAnalyticsWorkspace.id
}

locals {
  blobStorageAndContainer = "${azurerm_storage_account.storageAccount.primary_blob_endpoint}deploymentpackage"
}

resource "azapi_resource" "functionApps" {
  type = "Microsoft.Web/sites@2023-12-01"
  schema_validation_enabled = false
  location = var.location
  name = var.functionAppName
  parent_id = azurerm_resource_group.rg.id
  body = jsonencode({
    kind = "functionapp,linux",
    identity = {
      type: "SystemAssigned"
    }
    properties = {
      serverFarmId = azapi_resource.serverFarm.id,
        functionAppConfig = {
          deployment = {
            storage = {
              type = "blobContainer",
              value = local.blobStorageAndContainer,
              authentication = {
                type = "SystemAssignedIdentity"
              }
            }
          },
          scaleAndConcurrency = {
            maximumInstanceCount = var.maximumInstanceCount,
            instanceMemoryMB = var.instanceMemoryMB
          },
          runtime = { 
            name = var.functionAppRuntime, 
            version = var.functionAppRuntimeVersion
          }
        },
        siteConfig = {
          appSettings = [
            {
              name = "AzureWebJobsStorage__accountName",
              value = azurerm_storage_account.storageAccount.name
            },
            {
              name = "APPLICATIONINSIGHTS_CONNECTION_STRING",
              value = azurerm_application_insights.appInsights.connection_string
            }
          ]
        }
      }
  })
  depends_on = [ azapi_resource.serverFarm, azurerm_application_insights.appInsights, azurerm_storage_account.storageAccount ]
}

data "azurerm_linux_function_app" "fn_wrapper" {
    name = azapi_resource.functionApps.name
    resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_role_assignment" "storage_roleassignment" {
  scope = azurerm_storage_account.storageAccount.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id = data.azurerm_linux_function_app.fn_wrapper.identity.0.principal_id
}