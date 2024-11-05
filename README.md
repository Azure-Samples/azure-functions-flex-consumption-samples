<!--
---
page_type: sample
languages:
- csharp
- python
- java
- nodejs
- typescript
- json
products:
- azure-functions
- azure
---
-->

# Azure Functions Flex Consumption Samples

This repository contains starters, infrastructure as code, and end to end samples for Azure Functions Flex Consumption. Check out [the Azure documentation to learn more about Azure Functions Flex Consumption](https://aka.ms/flexconsumption). 

## Starter Samples Overview (Code + AZD)

These starters samples give you the code + IaC (Azure Dev CLI enabled) to build and deploy simple/common scenarios to Flex Consumption.

- [HTTP (.NET 8 Isolated / C#)](https://github.com/Azure-Samples/functions-quickstart-dotnet-azd): Contains a sample for building and deploying simple HTTP services that handle GET and POST with C#.
- [HTTP (Python 3.11)](https://github.com/Azure-Samples/functions-quickstart-python-http-azd): Contains a sample for building and deploying simple HTTP services that handle GET and POST with Python.
- [HTTP (JavaScript | Node 20)](https://github.com/Azure-Samples/functions-quickstart-javascript-azd): Contains a sample for building and deploying simple HTTP services that handle GET and POST with JavaScript.
- [HTTP (TypeScript | Node 20)](https://github.com/Azure-Samples/functions-quickstart-typescript-azd): Contains a sample for building and deploying simple HTTP services that handle GET and POST with TypeScript.
- [HTTP (Java 17)](https://github.com/Azure-Samples/azure-functions-java-flex-consumption-azd): Contains a sample for building and deploying simple HTTP services that handle GET and POST with Java.
- [HTTP (PowerShell 7.4)](https://github.com/Azure-Samples/functions-quickstart-powershell-azd): Contains a sample for building and deploying simple HTTP services that handle GET and POST with PowerShell.

## End to End Samples Overview

The following end to end samples are available in this repository for different Flex Consumption app scenarios:

- [High scale HTTP function app to Event Hubs via VNet](https://github.com/Azure-Samples/functions-e2e-http-to-eventhubs): An HTTP function written in .NET that accepts calls from any source, and then sends the body of those HTTP calls to a secure Event Hubs hub behind a VNet using VNet integration.
- [Service Bus trigger behind a VNet](https://github.com/Azure-Samples/functions-e2e-sb-vnet): A Service Bus queue triggered function written in Python that triggers from a VNet restricted service bus via private endpoint. A Virtual Machine in the VNet is used to send messages.
- [PDF to text processor](https://github.com/Azure-Samples/functions-e2e-blob-pdf-to-text): A blob triggered function using Event Grid written in Node that processes PDF documents into text at scale.
- [Order processing workflow with Azure Durable Functions](https://github.com/Azure-Samples/Durable-Functions-Order-Processing): Implement an order processing workflow using Durable Functions and Flex Consumption.
- [SignalR Bidirectional chatroom sample](https://github.com/aspnet/AzureSignalR-samples/tree/main/samples/DotnetIsolated-ClassBased): This is a chatroom walkthrough sample that demonstrates bidirectional message pushing between Azure SignalR Service and Azure Functions in a serverless scenario using the Flex Consumption hosting plan and .NET.

## IaC samples Overview

Flex Consumption has made some significant improvements to the control plane compared to other Azure Functions hosting plans. The following foundational samples are available in this repository for creating a Flex Consumption app that you should review and copy if you are automating the creation of your function apps with ARM, Bicep, or Terraform:

- [ARM (Azure Resource Manager)](./IaC/armtemplate/README.md): Contains a sample for deploying Azure Functions using ARM templates.
- [Bicep](./IaC/bicep/README.md): Contains a sample for deploying Azure Functions using Bicep templates.
- [Terraform](./IaC/terraform/README.md): Contains a sample for deploying Azure Functions using Terraform scripts.

---

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.
