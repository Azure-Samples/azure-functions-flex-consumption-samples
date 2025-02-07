variable "resourceGroupName" {
  description = "The Azure Resource Group name in which all resources in this example should be created."
}

variable "location" {
  description = "The Azure Region in which all resources in this example should be created."
}

variable "applicationInsightsName" {
  description = "Your Application Insights name."
}

variable "logAnalyticsName" {
  description = "Your Log Analytics name."
}

variable "functionAppName" {
  description = "Your Flex Consumption app name."
}

variable "functionPlanName" {
  description = "Your Flex Consumption plan name."
}

variable "storageAccountName" {
  description = "Your storage account name."
}

variable "maximumInstanceCount" {
  default = 100
  description = "The maximum instance count for the app"
}

variable "instanceMemoryMB" {
  default = 2048
  description = "The instance memory for the instances of the app: 2048 or 4096"
}

variable "functionAppRuntime" {
  default = "dotnet-isolated"
  description = "The runtime for your app. One of the following: 'dotnet-isolated', 'python', 'java', 'node', 'powershell'"
}

variable "functionAppRuntimeVersion" {
  default = "9.0"
  description = "The runtime and version for your app. One of the following: '3.10', '3.11', '7.4', '8.0', '10', '11', '17', '20'"
}

