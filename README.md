# Azure Functions Flex Consumption Samples

This repository contains starters, infrastructure as code, and end to end samples for Azure Functions Flex Consumption. Check out [the Azure documentation to learn more about Azure Functions Flex Consumption](https://aka.ms/flexconsumption). 

## IaC samples Overview

Flex Consumption has made some significant improvements to the control plane compared to other Azure Functions hosting plans. The following foundational samples are available in this repository for creating a Flex Consumption app that you should review and copy if you are automating the creation of your function apps with ARM, Bicep, or Terraform:

- [ARM (Azure Resource Manager)](./IaC/armtemplate/README.md): Contains a sample for deploying Azure Functions using ARM templates.
- [Bicep](./IaC/bicep/README.md): Contains a sample for deploying Azure Functions using Bicep templates.
- [Terraform](./IaC/terraform/README.md): Contains a sample for deploying Azure Functions using Terraform scripts.

## Starter Templates Overview (Code + AZD)

These starters give you the code + IaC (Azure Dev CLI enabled) to build and deploy simple/common scenarios to Flex Consumption.

- [HTTP (.NET 8 Isolated / C#)](./starters/http/dotnet): Contains a sample for building and deploying simple HTTP services that handle GET and POST.

## End to End Samples Overview

The following end to end samples are available in this repository for different Flex Consumption app scenarios:

- [High scale HTTP function app to Event Hubs via VNet](./E2E/HTTP-VNET-EH/README.md): An HTTP function that accepts calls from any source, and then sends the body of those HTTP calls to a secure Event Hubs hub behind a VNet using VNet integration.
- [Service Bus trigger behind a VNet](./E2E/SB-VNET/README.md): A Service Bus queue triggered function that triggers from a VNet restricted service bus via private endpoint. A Virtual Machine in the VNet is used to send messages.