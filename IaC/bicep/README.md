---
description: This Bicep sample deploys the resources to create a function app in Azure Functions that runs in a Flex Consumption plan using Azure Verified Modules (AVM).
page_type: sample
products:
- azure
- azure-resource-manager
urlFragment: bicep-file-deployment
languages:
- bicep
---

# Flex Consumption plan - Bicep sample with Azure Verified Modules | Azure Functions

This bicep sample deploys a function app and other required resources in a Flex Consumption plan using **Azure Verified Modules (AVM)**. This updated template provides enhanced security, standardization, and maintainability compared to custom modules.

## Architecture Overview

## Architecture

The template creates the following resources:

Resource Group
├── Log Analytics Workspace
├── Application Insights (linked to Log Analytics)
├── Storage Account (with blob container for deployments)
├── App Service Plan (Flex Consumption)
├── Function App (Flex Consumption app with system-assigned managed identity)
└── Role Based Access Control Role Assignments

Component descriptions:

| Component | Description | AVM Module Used |
| ---- | ---- | ---- |
| **Function app** | Serverless Flex Consumption app configured with managed identity, Application Insights and Storage Account | `avm/res/web/site` |
| **Function app plan** | Azure Functions app plan for Flex Consumption with zone redundancy support | `avm/res/web/serverfarm` |
| **Application Insights** | Telemetry service for monitoring with Log Analytics integration | `avm/res/insights/component` |
| **Log Analytics Workspace** | Centralized logging and monitoring workspace | `avm/res/operational-insights/workspace` |
| **Storage Account** | Storage for function app deployment packages with enhanced security | `avm/res/storage/storage-account` |
| **System-Assigned Managed Identity** | Secure identity for accessing Azure resources without credentials | Built into Function App |
| **RBAC Role Assignments** | Least-privilege access assignments for managed identity | Custom module |

This template introduces several best practices, including enhanced security through system-assigned managed identity, exclusive use of managed identity for storage access (eliminating shared key authentication), enforcement of TLS 1.2 for secure data in transit, and adherence to the principle of least privilege for permissions. Leveraging Azure Verified Modules (AVM) further ensures standardized, Microsoft-validated components that improve maintainability, documentation, and built-in best practices.

## Requirements

To deploy this Bicep template, you need:

- An active [Azure subscription](https://azure.microsoft.com/free/)
- The latest [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) 
- The latest [Bicep CLI](https://docs.microsoft.com/azure/azure-resource-manager/bicep/install) (or use the built-in Bicep support in Azure CLI)
- Sufficient permissions to deploy resources at the subscription scope (e.g., Owner or Contributor role)
- (Optional) [Azure Functions Core Tools](https://docs.microsoft.com/azure/azure-functions/functions-run-local) for local development and deployment

> **Note:** Ensure you are logged in to Azure CLI and have set the correct subscription before deploying.

## Testing and Validation

Before deploying to production, we recommend thorough testing:

### Quick Validation

For a rapid validation of your template:

```bash
# 1. Validate template (30 seconds)
az deployment sub validate \
  --template-file main.bicep \
  --parameters environmentName=test-env location=eastus2 \
  --location eastus2

# 2. Preview changes (1 minute)
az deployment sub what-if \
  --template-file main.bicep \
  --parameters environmentName=test-env location=eastus2 \
  --location eastus2
```

### 3. Test Deployment

Deploy to a test environment. For example, in East US 2:

```bash
# Test deployment with minimal parameters
az deployment sub create \
  --template-file main.bicep \
  --parameters environmentName=test-env location=eastus2 \
  --location eastus2 \
  --name flexconsumption-test
```

Alternately, deploy to a test environment with user access to Storage and App Insights resources:
```bash
# Test deployment with user access to Storage resources
az deployment sub create \
  --template-file main.bicep \
  --parameters environmentName=test-env location=eastus2 \
  --parameters principalId=$(az ad signed-in-user show --query id -o tsv) \
  --location eastus2 \
  --name flexconsumption-test
```

### Supported Regions

Check current Flex Consumption supported regions:

```bash
az functionapp list-flexconsumption-locations
```

Once deployed you should see the services created on Azure:
![Resources described above in the resource group](resources.png)

You can now use Azure Functions Core Tools, VS Code, or the Azure CLI to create and publish your app code to the function app.
