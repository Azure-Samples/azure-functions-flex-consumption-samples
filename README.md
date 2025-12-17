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

This repository contains links to quickstart samples, end to end samples, and infrastructure as code examples for Azure Functions Flex Consumption. Check out [the Azure documentation to learn more about Azure Functions Flex Consumption](https://aka.ms/flexconsumption).

## Starter Samples Overview (Code + AZD)

These starters samples give you the code + IaC (Azure Dev CLI enabled) to build and deploy simple/common scenarios to Flex Consumption.

### HTTP Trigger Quickstarts

Simple HTTP services that handle GET and POST requests, with code and Azure Developer CLI (AZD) templates for easy deployment:

- [.NET Isolated / C#](https://github.com/Azure-Samples/functions-quickstart-dotnet-azd)
- [Python](https://github.com/Azure-Samples/functions-quickstart-python-http-azd)
- [JavaScript](https://github.com/Azure-Samples/functions-quickstart-javascript-azd)
- [TypeScript](https://github.com/Azure-Samples/functions-quickstart-typescript-azd)
- [Java](https://github.com/Azure-Samples/azure-functions-java-flex-consumption-azd)
- [PowerShell](https://github.com/Azure-Samples/functions-quickstart-powershell-azd)

### Azure Blob Storage Trigger (Event Grid) Quickstarts

Quickstarts for building Azure Blob Storage triggered function apps using Event Grid in Flex Consumption.

- [.NET Isolated / C#](https://github.com/Azure-Samples/functions-quickstart-dotnet-azd-eventgrid-blob)
- [Python](https://github.com/Azure-Samples/functions-quickstart-python-azd-eventgrid-blob)
- [TypeScript](https://github.com/Azure-Samples/functions-quickstart-typescript-azd-eventgrid-blob)
- [JavaScript](https://github.com/Azure-Samples/functions-quickstart-javascript-azd-eventgrid-blob)
- [Java](https://github.com/Azure-Samples/functions-quickstart-java-azd-eventgrid-blob)
- [PowerShell](https://github.com/Azure-Samples/functions-quickstart-powershell-azd-eventgrid-blob)

### Timer Trigger Quickstarts

Quickstarts for building timer triggered function apps in Flex Consumption.

- [.NET Isolated / C#](https://github.com/Azure-Samples/functions-quickstart-dotnet-azd-timer)

### Azure Cosmos DB Trigger Quickstarts

Quickstarts for building Azure Cosmos DB triggered function apps in Flex Consumption.

- [.NET Isolated / C#](https://github.com/Azure-Samples/functions-quickstart-dotnet-azd-cosmosdb)
- [Python](https://github.com/Azure-Samples/functions-quickstart-python-azd-cosmosdb)
- [TypeScript](https://github.com/Azure-Samples/functions-quickstart-typescript-azd-cosmosdb)

### Azure SQL Trigger Quickstarts

Quickstarts for building Azure SQL triggered function apps in Flex Consumption.

- [.NET Isolated / C#](https://github.com/Azure-Samples/functions-quickstart-dotnet-azd-sql)
- [Python](https://github.com/Azure-Samples/functions-quickstart-python-azd-sql)
- [TypeScript](https://github.com/Azure-Samples/functions-quickstart-typescript-azd-sql)

### Azure Service Bus Quickstarts

Quickstarts for building Azure Service Bus triggered function apps in Flex Consumption.

- [.NET Isolated / C#](https://github.com/Azure-Samples/functions-quickstart-dotnet-azd-service-bus)
- [Python](https://github.com/Azure-Samples/functions-quickstart-python-azd-service-bus)
- [TypeScript](https://github.com/Azure-Samples/functions-quickstart-typescript-azd-service-bus)
- [Java](https://github.com/Azure-Samples/functions-quickstart-java-azd-service-bus)

### Durable Functions Quickstarts

Quickstarts for running Durable Functions function apps in Flex Consumption.

- [.NET Isolated / C#](https://github.com/Azure-Samples/durable-functions-quickstart-dotnet-azd)

### Remote MCP with the Azure Functions MCP extensions

Quickstarts to easily build and deploy a custom remote MCP server to the cloud using Azure functions.

- [.NET Isolated / C#](https://github.com/Azure-Samples/remote-mcp-functions-dotnet)
- [Python](https://github.com/Azure-Samples/remote-mcp-functions-python)
- [TypeScript](https://github.com/Azure-Samples/remote-mcp-functions-typescript)
- [Java](https://github.com/Azure-Samples/remote-mcp-functions-java)

### Remote MCP servers with the official Anthropic MCP SDKs

Quickstarts for remote hosting of MCP servers built with the official Anthropic MCP SDKs on Azure Functions Flex Consumption.

- [.NET Isolated / C#](https://github.com/Azure-Samples/mcp-sdk-functions-hosting-dotnet)
- [Python](https://github.com/Azure-Samples/mcp-sdk-functions-hosting-python)
- [TypeScript](https://github.com/Azure-Samples/mcp-sdk-functions-hosting-node)
- [Java](https://github.com/Azure-Samples/mcp-sdk-functions-hosting-java)

## End to End Samples Overview

The following end to end samples are available in this repository for different Flex Consumption app scenarios:

- [High scale HTTP function app to Event Hubs via VNet](https://github.com/Azure-Samples/functions-e2e-http-to-eventhubs): An HTTP function written in .NET that accepts calls from any source, and then sends the body of those HTTP calls to a secure Event Hubs hub behind a VNet using VNet integration.
- [High Scale stream processing of vehicle telemetry using Event Hubs](https://github.com/Azure-Samples/Stream-processing-with-Azure-Functions): This demo showcases a real-time event processing solution using Azure Event Hubs and Azure Functions with Flex Consumption plan.
- [Service Bus trigger behind a VNet](https://github.com/Azure-Samples/functions-e2e-sb-vnet): A Service Bus queue triggered function written in Python that triggers from a VNet restricted service bus via private endpoint. A Virtual Machine in the VNet is used to send messages.
- [PDF to text processor](https://github.com/Azure-Samples/functions-e2e-blob-pdf-to-text): A blob triggered function using Event Grid written in Node that processes PDF documents into text at scale.
- [Order processing workflow with Azure Durable Functions](https://github.com/Azure-Samples/Durable-Functions-Order-Processing): Implement an order processing workflow using Durable Functions and Flex Consumption.
- [SignalR Bidirectional chatroom sample](https://github.com/aspnet/AzureSignalR-samples/tree/main/samples/DotnetIsolated-ClassBased): This is a chatroom walkthrough sample that demonstrates bidirectional message pushing between Azure SignalR Service and Azure Functions in a serverless scenario using the Flex Consumption hosting plan and .NET.

## IaC samples Overview

Flex Consumption has made some significant improvements to the control plane compared to other Azure Functions hosting plans. The following foundational samples are available in this repository for creating a Flex Consumption app that you should review and copy if you are automating the creation of your function apps with ARM, Bicep, or Terraform:

- [ARM (Azure Resource Manager)](./IaC/armtemplate/README.md): Contains a sample for deploying Azure Functions using ARM templates.
- [Bicep](./IaC/bicep/README.md): Contains a sample for deploying Azure Functions using Bicep templates.
- [Terraform AzAPI Provider](./IaC/terraformazapi/README.md): Contains a sample for deploying Azure Functions using Terraform scripts using the AzAPI provider.
- [Terraform AzureRM Provider](./IaC/terraformazurerm/README.md): Contains samples for deploying Azure Functions using Terraform scripts using the AzureRM provider.

---

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.
