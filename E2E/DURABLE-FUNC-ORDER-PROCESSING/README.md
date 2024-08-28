---
description: This end-to-end sample shows how implement an order processing workflow using Durable Functions. 
page_type: sample
products:
- azure-functions
- azure
urlFragment: durable-func-order-processing
languages:
- csharp
- bicep
- azdeveloper
---

# Flex Consumption plan - Order processing workflow | Azure Durable Functions

Durable Functions helps you easily orchestrate stateful logic with *imperative* code, making it an execellent solution for workflow scenarios, as well as stateful patterns like fan-out/fan-in and workloads that require long-running operations or need to wait arbitrarily long for external events. 

This sample shows how to implement an order processing workflow with Durable Functions in C# (running in the isolated model) and can easily be deployed to a function app in Azure. 

> [!IMPORTANT]
> This sample creates several resources. Make sure to delete the resource group after testing to minimize charges!

## Run in your local environment

The project is designed to run on your local computer, provided you have met the [required prerequisites](#prerequisites). You can run the project locally in these environments:

+ [Using Azure Functions Core Tools (CLI)](#using-azure-functions-core-tools-cli)
+ [Using Visual Studio](#using-visual-studio)
+ [Using Visual Studio Code](#using-visual-studio-code)

### Prerequisites

+ [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0) 
+ [Azure Functions Core Tools](https://learn.microsoft.com/azure/azure-functions/functions-run-local?tabs=v4%2Cmacos%2Ccsharp%2Cportal%2Cbash#install-the-azure-functions-core-tools)
+ Start Azurite storage emulator. See [this page](https://learn.microsoft.com/azure/storage/common/storage-use-azurite) for how to configure and start the Azurite emulator for Local Storage.
+ Create a file named `local.settings.json` in **http** directory and add the following:

  ```json
  {
    "IsEncrypted": false,
    "Values": {
      "AzureWebJobsStorage": "UseDevelopmentStorage=true",
      "FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated"
    }
  }
  ```

### Using Azure Functions Core Tools (CLI)

1) Open a new terminal and do the following:

```bash
cd DURABLE-FUNC-ORDER-PROCESSING
func start
```

2) This sample uses an HTTP trigger to start an orchestration, so open a browser and go to http://localhost:7071/api/OrderProcessingOrchestration_HttpStart.


3) To check the status of the orchestration instance started, go to the `statusQueryGetUri`. Your orchestration instance should show status "Running". After a few seconds, refresh to see that the orchestration is "Completed" and the output "Processed: true" meaning the order was processed. 

### Using Visual Studio

1) Open `starter.sln` using Visual Studio 2022 or later.
2) Press Run/F5 to run in the debugger
3) Use same approach above to start an orchestration instance and check its status. 

### Using Visual Studio Code

1) Open this folder in a new terminal
2) Open VS Code by entering `code .` in the terminal
3) Add a **.vscode** folder by running *"Azure Functions: Initialize project for use with VS Code"* in the Command Pallete
4) Press Run/Debug (F5) to run in the debugger
5) Use same approach above to start an orchestration instance and check its status. 


## Provision the solution on Azure

To set up this sample, follow these steps:

1. Clone this repository to your local machine.
2. in the root folder use the [Azure Developer CLI (azd)](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd?tabs=winget-windows%2Cbrew-mac%2Cscript-linux&pivots=os-windows) to provision a new resource group with the environment name you provide and all the resources for the sample.

```bash
azd up
```

Note that `azd deploy` and Visual Studio does not yet work to publish Flex Consumption apps. Please use Azure Functions Core Tools, Az CLI or VS Code alternatives instead to deploy your app zip to these Flex resources.


## Inspect the solution (optional)

1. Once the deployment is done, inspect the new resource group. The Flex Consumption function app and plan, storage, and App Insightshave been created and configured:


## Test the solution



## Clean up resources

When you no longer need the resources created in this sample, run the following command to delete the Azure resources:

```bash
azd down
```