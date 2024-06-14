param location string = resourceGroup().location
param tags object = {}
param storageAccountId string

resource unprocessedPdfSystemTopic 'Microsoft.EventGrid/systemTopics@2024-06-01-preview' = {
  name: 'unprocessed-pdf-topic'
  location: location
  tags: tags
  properties: {
    source: storageAccountId
    topicType: 'Microsoft.Storage.StorageAccounts'
  }
}

// The actual event grid subscription will be created in the post deployment script as it needs the function to be deployed first

// resource unprocessedPdfSystemTopicSubscription 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2024-06-01-preview' = {
//   parent: unprocessedPdfSystemTopic
//   name: 'unprocessed-pdf-topic-subscription'
//   properties: {
//     destination: {
//       endpointType: 'WebHook'
//       properties: {
//         //Will be set on post-deployment script once the function is created and the blobs extension code is available
//         //endpointUrl: 'https://${function_app_blob_event_grid_name}.azurewebsites.net/runtime/webhooks/blobs?functionName=Host.Functions.Trigger_BlobEventGrid&code=${blobs_extension}'
//       }
//     }
//     filter: {
//       includedEventTypes: [
//         'Microsoft.Storage.BlobCreated'
//       ]
//       subjectBeginsWith: '/blobServices/default/containers/${unprocessedPdfContainerName}/'
//     }
//   }
// }

output unprocessedPdfSystemTopicId string = unprocessedPdfSystemTopic.id
output unprocessedPdfSystemTopicName string = unprocessedPdfSystemTopic.name 
