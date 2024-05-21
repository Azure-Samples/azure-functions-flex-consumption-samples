# Flex Consumption app - ARM sample

This ARM sample deploys a Flex Consumption app. This ARM file is used to create the following Azure components:

* **Function app**: This is the serverless Flex Consumption app where you can deploy your functions code. The function app is configured with Application Insights and Storage Account.

* **Function app plan**: The Azure Functions app plan associated with your Flex Consumption app. For Flex Consumption there is only one app allowed per plan, but the plan is still required.

* **Application Insights**: This is the telemetry service associated with the Flex Consumption app for you to monitor live applications, detect performance anomalies, review telemetry logs, and to understand your app behavior.

* **Log Analytics Workspace**: This is the workspace used by Application Insights for the app telemetry.

* **Storage Account**: This is the Microsoft Azure storage account that [Azure Functions requires](https://learn.microsoft.com/en-us/azure/azure-functions/storage-considerations) when you create a function app instance.


## How to deploy it?

### Modify the parameters file

Create a copy and modify the parameters file `azuredeploy.parameters.json` to specify the values for the parameters. The parameters file contains the following parameters that you must specify values for before you can deploy the app:
* **location** - the location where the assets will be created. 
* **functionPlanName** - a unique name for the Flex Consumption app plan
* **functionAppName** - a unique name for the Flex Consumption app instance
* **functionAppRuntime** - the runtime to be used for your Flex Consumption app.
* **functionAppRuntimeVersion** - The runtime version to be used for your Flex Consumption app
* **storageAccountName** - a unique name for the storage account
* **logAnalyticsName** - a unique name for the Log Analytics Workspace
* **applicationInsightsName** - a unique name for the Application Insights instance

Here is an example parameters file for creating a .NET Isolated 8.0 app that you can modify:
```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "location": {
      "value": "eastasia"
    },
    "functionPlanName": {
      "value": "fcthiarmplan"
    },
    "functionAppName": {
      "value": "fcthiarmapp"
    },
    "functionAppRuntime": {
      "value": "dotnet-isolated"
    },
    "functionAppRuntimeVersion": {
      "value": "8.0"
    },
    "storageAccountName": {
      "value": "fcthiarmstor"
    },
    "logAnalyticsName": {
      "value": "fcthiarmlog"
    },
    "applicationInsightsName": {
      "value": "fcthiarmai"
    }
  }
}
```

### Deploy the ARM file

Before you can deploy this app, you need to create a resource group and have a way to deploy ARM files. For example, you can use the [Azure Portal](https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/deploy-portal#deploy-resources-from-custom-template), the [Azure CLI](https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/deploy-cli), or [PowerShell](https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/deploy-powershell). 

For example, if you created an `azuredeploycopy.parameters.json` with the above example, you can create a resource group and deploy the app by running the following AZ CLI commands:
```bash
az group create --location eastus --resource-group fcarm
az deployment group create --resource-group fcarm --template-file azuredeploy.json --parameters azuredeploycopy.parameters.json
```

Once deployed you should see the services created on Azure:
![Resources described above in the resource group](resources.png)

You can now use Azure Functions Core Tools, VS Code, or the Azure CLI to create and publish your app code to the function app. 
