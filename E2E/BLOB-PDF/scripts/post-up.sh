commands=("az")

for cmd in "${commands[@]}"; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: $cmd command is not available, check pre-requisites in README.md"
    exit 1
  fi
done

#Get the function blobs_extension key
blobs_extension=$(az functionapp keys list -n ${AZURE_FUNCTION_APP_NAME} -g ${RESOURCE_GROUP} --query "systemKeys.blobs_extension" -o tsv)

# Build the endpoint URL with the function name and extension key and create the event subscription
endpointUrl="https://${AZURE_FUNCTION_APP_NAME}.azurewebsites.net/runtime/webhooks/blobs?functionName=Host.Functions.PDFProcessor&code=${blobs_extension}"
filter="/blobServices/default/containers/${UNPROCESSED_PDF_CONTAINER_NAME}"

az eventgrid system-topic event-subscription create -n "unprocessed-pdf-topic-subscription" -g "${RESOURCE_GROUP}" --system-topic-name "${UNPROCESSED_PDF_SYSTEM_TOPIC_NAME}" --endpoint-type "webhook" --endpoint "$endpointUrl" --included-event-types "Microsoft.Storage.BlobCreated" --subject-begins-with "$filter" 

echo "Created blob event grid subscription successfully."