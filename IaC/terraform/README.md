---
description: This Terraform sample deploys the resources to create a function app in Azure Functions that runs in a Flex Consumption plan.
page_type: sample
products:
- azure
- azure-resource-manager
urlFragment: terraform-based-deployment
languages:
- terraform
---

# Flex Consumption plan - Terraform sample | Azure Functions

This Terraform sample deploys deploys a function app and other required resources in a Flex Consumption plan. When used in an Terraform-based deployment, this Terraform file is used to creates these Azure components:

| Component | Description |
| ---- | ---- |
| **Function app** | This is the serverless Flex Consumption app where you can deploy your functions code. The function app is configured with Application Insights and Storage Account.|
| **Function app plan** | The Azure Functions app plan associated with your Flex Consumption app. For Flex Consumption there is only one app allowed per plan, but the plan is still required.|
| **Application Insights** | This is the telemetry service associated with the Flex Consumption app for you to monitor live applications, detect performance anomalies, review telemetry logs, and to understand your app behavior.|
| **Log Analytics Workspace** | This is the workspace used by Application Insights for the app telemetry.|
| **Storage Account** | This is the Microsoft Azure storage account that [Azure Functions requires](https://learn.microsoft.com/azure/azure-functions/storage-considerations) when you create a function app instance. A blob container called `deploymentpackage` is also created in this storage account to be configured as the location for when you deploy to this Flex Consumption app.|

## How to deploy it?

Use these steps to deploy using the Terraform file.

### 1. Modify the parameters file

Create a copy and modify the parameters file `variables.tfvars` to specify the values for the parameters. The parameters file contains the following parameters that you must specify values for before you can deploy the app:

| Parameter | Description |
| ---- | ---- |
| **resourceGroupName** | the name of the resource group to be created for your app.|
| **location** | the location where the assets will be created. You can find the supported regions with the `az functionapp list-flexconsumption-locations` command of the Azure CLI.|
| **applicationInsightsName** | a unique name for the Application Insights instance.|
| **logAnalyticsName** | a unique name for the Log Analytics Workspace.|
| **functionAppName** | a unique name for the Flex Consumption app instance.|
| **functionPlanName** | a unique name for the Flex Consumption app plan.|
| **storageAccountName** | a unique name for the storage account.|
| **functionAppRuntime** | The runtime of the Flex Consumption app that you plan to deploy. One of the following values: `dotnet-isolated`, `python`, `java`, `node`, `powershell`.|
| **functionAppRuntimeVersion** | The runtime and version of the Flex Consumption app that you plan to deploy One of the following values: `3.10`, `3.11`, `7.4`, `8.0`, `10`, `11`, `17`, `20`.|

Here is an example `variables.tfvars` that you can modify:

```terraform
resourceGroupName = "fcthitf"
location = "eastasia"
applicationInsightsName = "fcthitfai"
functionAppName = "fcthitfapp"
functionPlanName = "fcthitfplan"
logAnalyticsName = "fcthitflog"
storageAccountName = "fcthitfstor"
functionAppRuntime = "dotnet-isolated"
functionAppRuntimeVersion = "8.0"
```

### 2. Deploy the Terraform file

Before you can deploy this app, you need a way to deploy Terraform files. For example, you can use the [Terraform CLI](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli).

For example, if you created a `variablescopy.tfvars` file with your parameter values, you can deploy the app by running the following command:

```bash
terraform init -upgrade
terraform plan -var-file="variablescopy.tfvars" -out main.tfplan
terraform apply main.tfplan
```

Once deployed you should see the services created on Azure:
![Resources described above in the resource group](resources.png)
