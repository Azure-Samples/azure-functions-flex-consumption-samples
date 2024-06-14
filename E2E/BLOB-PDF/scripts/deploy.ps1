$output = azd env get-values

foreach ($line in $output) {
    if (!($line)){
      break
    }
      $name = $line.Split('=')[0]
      $value = $line.Split('=')[1].Trim('"')
      Set-Item -Path "env:\$name" -Value $value
}

Write-Host "Environment variables set."

$tools = @("az", "func")

foreach ($tool in $tools) {
  if (!(Get-Command $tool -ErrorAction SilentlyContinue)) {
    Write-Host "Error: $tool command line tool is not available, check pre-requisites in README.md"
    exit 1
  }
}

func azure functionapp publish $env:AZURE_FUNCTION_APP_NAME node

#Get the function blobs_extension key
$blobs_extension=$(az functionapp keys list -n ${AZURE_FUNCTION_APP_NAME} -g ${RESOURCE_GROUP} --query "systemKeys.blobs_extension" -o tsv)

# Build the endpoint URL with the function name and extension key and create the event subscription
$endpointUrl="https://" + $env:AZURE_FUNCTION_APP_NAME + ".azurewebsites.net/runtime/webhooks/blobs?functionName=Host.Functions.PDFProcessor&code=" + $env:blobs_extension
$filter="/blobServices/default/containers/" +$env:UNPROCESSED_PDF_CONTAINER_NAME
az eventgrid system-topic event-subscription create -n "unprocessed-pdf-topic-subscription" -g $env:RESOURCE_GROUP --system-topic-name $env:UNPROCESSED_PDF_SYSTEM_TOPIC_NAME --endpoint-type "webhook" --endpoint "$env:endpointUrl" --included-event-types "Microsoft.Storage.BlobCreated" --subject-begins-with "$env:filter" 

Write-Host "Deployed and created blob event grid subscription successfully."