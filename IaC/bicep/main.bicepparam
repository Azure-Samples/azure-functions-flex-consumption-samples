using 'main.bicep'

// TODO before deploying using a parameters file: Update the following parameters.
param environmentName = '[A NAME FOR YOUR APP ENVIRONMENT]'
param location = '[AZURE REGION FOR CREATING THE FUNCTION APP]' 

// Optional: Uncomment and modify these parameters as needed
// param resourceGroupName = ''
// param functionPlanName = ''
// param functionAppName = ''
// param storageAccountName = ''
// param logAnalyticsName = ''
// param applicationInsightsName = ''

// Function runtime configuration
// param functionAppRuntime = 'dotnet-isolated'  // Options: 'dotnet-isolated', 'python', 'java', 'node', 'powerShell'
// param functionAppRuntimeVersion = '9.0'       // Depends on runtime choice

// Scaling and performance configuration
// param maximumInstanceCount = 100              // Range: 40-1000
// param instanceMemoryMB = 2048                 // Options: 512, 2048, 4096

// Security and reliability configuration
// param zoneRedundant = false                   // Enable zone redundancy for higher availability


// Optional: Set this to your own user object ID for development/testing scenarios
// This allows you to interact with storage and Application Insights during development
// param principalId = ''
