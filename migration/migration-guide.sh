#!/bin/bash

# Azure Functions Migration: Linux Consumption to Flex Consumption Guide
# This script guides you through the process of migrating Azure Function Apps 
# from Linux Consumption to Flex Consumption
# Updated: April 2025

# Text formatting
BOLD="\033[1m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
NC="\033[0m" # No Color

# Function to display section headers
section_header() {
  echo -e "\n${BOLD}${BLUE}$1${NC}\n"
}

# Function to display subsection headers
subsection_header() {
  echo -e "\n${BOLD}${CYAN}$1${NC}"
}

# Function to display success messages
success_message() {
  echo -e "${GREEN}✓ $1${NC}"
}

# Function to display warning messages
warning_message() {
  echo -e "${YELLOW}⚠ $1${NC}"
}

# Function to display error messages
error_message() {
  echo -e "${RED}✗ $1${NC}"
}

# Function to pause execution and wait for user input
pause() {
  read -p "Press [Enter] to continue..."
}

# Function to check prerequisites
check_prerequisites() {
  section_header "Checking prerequisites..."
  
  # Check if Azure CLI is installed
  if ! command -v az &> /dev/null; then
    error_message "Azure CLI is not installed."
    echo "Please install Azure CLI first: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
  else
    success_message "Azure CLI is installed."
  fi
  
  # Check Azure CLI version (recommend 2.71.0 or later)
  az_version=$(az version --query '"azure-cli"' -o tsv)
  echo "Azure CLI version: $az_version"
  if [ "$(printf '%s\n' "2.71.0" "$az_version" | sort -V | head -n1)" != "2.71.0" ]; then
    warning_message "Azure CLI version $az_version is older than the recommended version (2.71.0+)."
    read -p "Would you like to continue anyway? (y/n): " continue_with_old_version
    if [[ $continue_with_old_version != "y" ]]; then
      echo "Please update Azure CLI and try again. Run: 'az upgrade'"
      exit 1
    fi
  else
    success_message "Azure CLI version is sufficient."
  fi
  
  # Check if user is logged in
  if ! az account show &> /dev/null; then
    warning_message "You are not logged in to Azure CLI."
    echo "Please log in to Azure:"
    az login
  else
    success_message "You are logged in to Azure CLI."
    # Show current subscription info
    subscription_name=$(az account show --query name -o tsv)
    echo "Using subscription: $subscription_name"
  fi
  
  # Check if required extensions are installed
  check_required_extension "resource-graph" "This extension is required for finding Linux Consumption apps in your subscription."
  
  # Check if jq is installed (helpful for JSON processing)
  if ! command -v jq &> /dev/null; then
    warning_message "jq tool is not installed. This tool is recommended for processing JSON output."
    echo "On macOS, install with: brew install jq"
    echo "On Ubuntu/Debian, install with: sudo apt-get install jq"
    read -p "Would you like to continue without jq? (y/n): " continue_without_jq
    if [[ $continue_without_jq != "y" ]]; then
      exit 1
    fi
  else
    success_message "jq tool is installed."
  fi
}

# Function to check if an Azure CLI extension is installed and install if needed
check_required_extension() {
  extension_name=$1
  reason=$2
  
  if ! az extension show --name $extension_name &> /dev/null; then
    warning_message "Azure CLI $extension_name extension is not installed."
    echo "Reason needed: $reason"
    read -p "Would you like to install it now? (y/n): " install_extension
    if [[ $install_extension == "y" ]]; then
      az extension add --name $extension_name
      success_message "Azure CLI $extension_name extension installed successfully."
    else
      error_message "The $extension_name extension is required for this migration script."
      exit 1
    fi
  else
    success_message "Azure CLI $extension_name extension is installed."
  fi
}

# Function to list Linux Consumption function apps
list_linux_consumption_apps() {
  section_header "STEP 1: ASSESSMENT - Identifying Function Apps on Linux Consumption"
  echo "Searching for function apps running on Linux Consumption in your current subscription..."
  
  subscription_id=$(az account show --query id -o tsv)
  
  echo "Using subscription ID: $subscription_id"
  
  # Query to find Linux Consumption function apps
  echo "Querying for Linux Consumption function apps..."
  az graph query -q "resources | where subscriptionId == '$subscription_id' | where type == 'microsoft.web/sites' | where ['kind'] == 'functionapp,linux' | where properties.sku == 'Dynamic' | extend siteProperties=todynamic(properties.siteProperties.properties) | mv-expand siteProperties | where siteProperties.name=='LinuxFxVersion' | project name, location, resourceGroup, stack=tostring(siteProperties.value)" --query data -o table
  
  # Store the count of apps
  app_count=$(az graph query -q "resources | where subscriptionId == '$subscription_id' | where type == 'microsoft.web/sites' | where ['kind'] == 'functionapp,linux' | where properties.sku == 'Dynamic' | count" --query data[0].count -o tsv)
  
  if [ "$app_count" -eq 0 ]; then
    warning_message "No Linux Consumption function apps found in this subscription."
    exit 0
  else
    success_message "Found $app_count Linux Consumption function app(s)."
  fi
  
  # Ask user to select an app for migration
  read -p "Enter the name of the function app you want to migrate: " function_app_name
  read -p "Enter the resource group of the function app: " resource_group
  
  # Verify the function app exists
  if ! az functionapp show --name "$function_app_name" --resource-group "$resource_group" &> /dev/null; then
    error_message "Function app '$function_app_name' not found in resource group '$resource_group'."
    exit 1
  else
    success_message "Function app '$function_app_name' found in resource group '$resource_group'."
  fi
  
  # Get app location and runtime
  location=$(az functionapp show --name "$function_app_name" --resource-group "$resource_group" --query location -o tsv)
  runtime_stack=$(az functionapp config show --name "$function_app_name" --resource-group "$resource_group" --query linuxFxVersion -o tsv)
  
  echo "Function app details:"
  echo "  Name: $function_app_name"
  echo "  Resource Group: $resource_group"
  echo "  Location: $location"
  echo "  Runtime Stack: $runtime_stack"
  
  # Extract runtime info from the runtime stack
  IFS='|' read -ra stack_parts <<< "$runtime_stack"
  runtime_name="${stack_parts[0],,}"  # Convert to lowercase
  runtime_version="${stack_parts[1]}"
  
  # Verify region compatibility
  verify_region_compatibility "$location"
  
  # Verify runtime compatibility
  verify_runtime_compatibility "$runtime_name" "$runtime_version" "$location"
  
  # Check for deployment slots
  verify_deployment_slots "$function_app_name" "$resource_group"
  
  # Check for certificates
  verify_certificates "$function_app_name" "$resource_group"
  
  # Check for LogsAndContainerScan blob triggers
  verify_blob_triggers "$function_app_name" "$resource_group"
}

# Function to verify region compatibility
verify_region_compatibility() {
  local location=$1
  
  subsection_header "Verifying region compatibility..."
  
  echo "Checking if Flex Consumption is available in the $location region..."
  
  # Get list of regions where Flex Consumption is available
  flex_regions=$(az functionapp list-flexconsumption-locations --query "[].name" -o tsv)
  
  # Check if the function app's region is supported
  if echo "$flex_regions" | grep -q "$location"; then
    success_message "The $location region supports Flex Consumption."
  else
    warning_message "Flex Consumption might not be available in the $location region."
    echo "Here are the regions where Flex Consumption is currently available:"
    az functionapp list-flexconsumption-locations --query "sort_by(@, &name)[].{Region:name}" -o table
    
    read -p "Would you like to continue with the migration and choose a different region? (y/n): " continue_region
    if [[ $continue_region != "y" ]]; then
      error_message "Migration cannot proceed without a supported region."
      exit 1
    fi
    
    echo "Available regions for Flex Consumption:"
    az functionapp list-flexconsumption-locations --query "sort_by(@, &name)[].{Region:name}" -o table
    
    read -p "Enter a new target region from the list above: " new_location
    location=$new_location
    echo "Targeting Flex Consumption in the $location region instead."
  fi
}

# Function to verify runtime compatibility
verify_runtime_compatibility() {
  local runtime_name=$1
  local runtime_version=$2
  local location=$3
  
  subsection_header "Verifying runtime compatibility..."
  
  echo "Runtime: $runtime_name, Version: $runtime_version"
  
  # Check if runtime is supported in Flex Consumption
  case "$runtime_name" in
    "dotnet")
      warning_message "The dotnet in-process runtime is not supported in Flex Consumption."
      echo "You will need to migrate your app to dotnet-isolated runtime first."
      read -p "Do you want to continue with migration, switching to dotnet-isolated? (y/n): " continue_dotnet
      if [[ $continue_dotnet == "y" ]]; then
        runtime_name="dotnet-isolated"
        echo "Will migrate as dotnet-isolated. You'll need to update your application code accordingly."
      else
        error_message "Migration cannot proceed with unsupported runtime."
        echo "Please migrate your app to dotnet-isolated first: https://learn.microsoft.com/en-us/azure/azure-functions/migrate-dotnet-to-isolated-model"
        exit 1
      fi
      ;;
    "custom")
      error_message "The custom runtime is not supported in Flex Consumption."
      echo "You will need to migrate your app to a supported runtime before continuing."
      exit 1
      ;;
    "dotnet-isolated"|"node"|"python"|"java"|"powershell")
      success_message "The $runtime_name runtime is supported in Flex Consumption."
      ;;
    *)
      warning_message "Unknown runtime: $runtime_name. Compatibility with Flex Consumption cannot be verified."
      read -p "Do you want to continue with the migration anyway? (y/n): " continue_unknown_runtime
      if [[ $continue_unknown_runtime != "y" ]]; then
        exit 1
      fi
      ;;
  esac
  
  # Check if the runtime version is supported in the location
  if [[ "$runtime_name" != "custom" && "$runtime_name" != "dotnet" ]]; then
    echo "Checking if $runtime_name version $runtime_version is supported in $location..."
    supported_versions=$(az functionapp list-flexconsumption-runtimes --location "$location" --runtime "$runtime_name" --query "[].{version:version}" -o tsv 2>/dev/null)
    
    if [ -z "$supported_versions" ]; then
      warning_message "Unable to retrieve supported versions for $runtime_name in $location."
      read -p "Do you want to continue with the migration anyway? (y/n): " continue_version_check
      if [[ $continue_version_check != "y" ]]; then
        exit 1
      fi
    else
      echo "Supported $runtime_name versions in $location: $supported_versions"
      
      version_supported=false
      for version in $supported_versions; do
        if [[ "$version" == "$runtime_version" ]]; then
          version_supported=true
          break
        fi
      done
      
      if $version_supported; then
        success_message "$runtime_name version $runtime_version is supported in $location for Flex Consumption."
      else
        warning_message "$runtime_name version $runtime_version might not be supported in $location for Flex Consumption."
        echo "You might need to upgrade your runtime version before or during migration."
        
        read -p "Do you want to continue with the migration anyway? (y/n): " continue_unsupported_version
        if [[ $continue_unsupported_version != "y" ]]; then
          exit 1
        fi
      fi
    fi
  fi
}

# Function to verify deployment slots
verify_deployment_slots() {
  local function_app_name=$1
  local resource_group=$2
  
  subsection_header "Checking for deployment slots..."
  
  slots=$(az functionapp deployment slot list --name "$function_app_name" --resource-group "$resource_group" --query "[].name" -o tsv 2>/dev/null)
  
  if [ -n "$slots" ]; then
    warning_message "This function app has deployment slots. Deployment slots are not supported in Flex Consumption."
    echo "Slots found: $slots"
    echo "You will need to consolidate your deployment strategy without using slots."
    read -p "Do you want to continue with the migration? (y/n): " continue_with_slots
    if [[ $continue_with_slots != "y" ]]; then
      echo "Migration cancelled."
      exit 0
    fi
  else
    success_message "No deployment slots found. Compatible with Flex Consumption."
  fi
}

# Function to verify certificates
verify_certificates() {
  local function_app_name=$1
  local resource_group=$2
  
  subsection_header "Checking for certificates..."
  
  certificates=$(az webapp config ssl list --resource-group "$resource_group" --query "[?name=='$function_app_name']" -o json 2>/dev/null)
  if [[ $certificates != "[]" && $certificates != "" ]]; then
    warning_message "This function app has associated certificates. Certificates are not supported in Flex Consumption."
    echo "You will need to consider alternative certificate management strategies."
    read -p "Do you want to continue with the migration? (y/n): " continue_with_certs
    if [[ $continue_with_certs != "y" ]]; then
      echo "Migration cancelled."
      exit 0
    fi
  else
    success_message "No certificates found. Compatible with Flex Consumption."
  fi
}

# Function to verify blob triggers
verify_blob_triggers() {
  local function_app_name=$1
  local resource_group=$2
  
  subsection_header "Checking for LogsAndContainerScan blob triggers..."
  
  # List all functions in the app
  functions=$(az functionapp function list --name "$function_app_name" --resource-group "$resource_group" --query "[].name" -o tsv 2>/dev/null)
  
  if [ -z "$functions" ]; then
    warning_message "Unable to retrieve functions list or no functions found."
    read -p "Do you want to continue with the migration? (y/n): " continue_no_functions
    if [[ $continue_no_functions != "y" ]]; then
      echo "Migration cancelled."
      exit 0
    fi
  else
    has_blob_trigger=false
    
    for func in $functions; do
      # Check if this function has a blob trigger without EventGrid source
      blob_trigger=$(az functionapp function show --name "$function_app_name" --resource-group "$resource_group" --function-name "$func" --query "config.bindings[?type=='blobTrigger' && (source==null || source!='EventGrid')]" -o json 2>/dev/null)
      
      if [[ $blob_trigger != "[]" && $blob_trigger != "" ]]; then
        has_blob_trigger=true
        warning_message "Function '$func' uses a LogsAndContainerScan blob trigger, which is not supported in Flex Consumption."
      fi
    done
    
    if $has_blob_trigger; then
      echo "Some functions are using the older LogsAndContainerScan blob trigger, which is not supported in Flex Consumption."
      echo "You will need to update these blob triggers to use the Event Grid-based implementation."
      echo "Documentation: https://learn.microsoft.com/en-us/azure/azure-functions/functions-event-grid-blob-trigger"
      
      read -p "Do you want to continue with the migration? (y/n): " continue_with_blob_triggers
      if [[ $continue_with_blob_triggers != "y" ]]; then
        echo "Migration cancelled."
        exit 0
      fi
    else
      success_message "No incompatible blob triggers found. Compatible with Flex Consumption."
    fi
  fi
}

# Function to export app settings and configurations
export_app_settings() {
  section_header "STEP 2: PRE-MIGRATION TASKS"
  echo "Collecting settings and configuration for function app '$function_app_name'..."
  
  # Create a directory to store migration info
  migration_dir="flex_migration_${function_app_name}"
  mkdir -p "$migration_dir"
  
  subsection_header "2.1 Exporting app settings..."
  
  # Retrieve and store app settings
  echo "Retrieving app settings..."
  app_settings=$(az functionapp config appsettings list --name "$function_app_name" --resource-group "$resource_group" -o json)
  
  if [ $? -eq 0 ]; then
    # Save app settings to file
    echo "$app_settings" > "$migration_dir/app_settings.json"
    success_message "App settings retrieved and saved to $migration_dir/app_settings.json"
    
    # Check if the app runs from package
    if command -v jq &> /dev/null; then
      run_from_package=$(echo "$app_settings" | jq -r '.[] | select(.name=="WEBSITE_RUN_FROM_PACKAGE") | .value')
    else
      run_from_package=$(echo "$app_settings" | grep -o '"name":"WEBSITE_RUN_FROM_PACKAGE","value":"[^"]*"' | sed 's/"name":"WEBSITE_RUN_FROM_PACKAGE","value":"//;s/"$//')
    fi
    
    if [ -n "$run_from_package" ]; then
      echo "Function app is running from package: $run_from_package"
      echo "Make note of this package URL - you'll need it when creating the new function app."
    else
      warning_message "Function app is not running from a package. You'll need to ensure you have the function app code for deployment."
    fi
  else
    error_message "Failed to retrieve app settings."
    exit 1
  fi
  
  subsection_header "2.2 Exporting app configuration..."
  
  # Retrieve general site configuration
  echo "Retrieving general site configuration..."
  site_config=$(az functionapp config show --name "$function_app_name" --resource-group "$resource_group" -o json)
  
  if [ $? -eq 0 ]; then
    # Save site config to file
    echo "$site_config" > "$migration_dir/site_config.json"
    success_message "Site configuration retrieved and saved to $migration_dir/site_config.json"
    
    # Extract key configuration settings
    if command -v jq &> /dev/null; then
      http20_enabled=$(echo "$site_config" | jq -r '.http20Enabled')
      https_only=$(az functionapp show --name "$function_app_name" --resource-group "$resource_group" --query httpsOnly -o tsv)
      min_tls_version=$(echo "$site_config" | jq -r '.minTlsVersion')
      client_cert_enabled=$(echo "$site_config" | jq -r '.clientCertEnabled')
    else
      http20_enabled=$(echo "$site_config" | grep -o '"http20Enabled":[^,}]*' | sed 's/"http20Enabled"://')
      https_only=$(az functionapp show --name "$function_app_name" --resource-group "$resource_group" --query httpsOnly -o tsv)
      min_tls_version=$(echo "$site_config" | grep -o '"minTlsVersion":"[^"]*"' | sed 's/"minTlsVersion":"//;s/"$//')
      client_cert_enabled=$(echo "$site_config" | grep -o '"clientCertEnabled":[^,}]*' | sed 's/"clientCertEnabled"://')
    fi
    
    echo "Important configuration settings:"
    echo "  HTTP 2.0 Enabled: $http20_enabled"
    echo "  HTTPS Only: $https_only"
    echo "  Minimum TLS Version: $min_tls_version"
    echo "  Client Certificates Enabled: $client_cert_enabled"
  else
    error_message "Failed to retrieve site configuration."
    exit 1
  fi
  
  subsection_header "2.3 Checking for custom domains..."
  
  # Check for custom domains
  custom_domains=$(az functionapp config hostname list --webapp-name "$function_app_name" --resource-group "$resource_group" -o json)
  
  if [ $? -eq 0 ]; then
    # Save custom domains to file
    echo "$custom_domains" > "$migration_dir/custom_domains.json"
    
    # Count non-default domains
    if command -v jq &> /dev/null; then
      domain_count=$(echo "$custom_domains" | jq -r '[.[] | select(.name | contains(".azurewebsites.net") | not)] | length')
    else
      domain_count=$(echo "$custom_domains" | grep -v ".azurewebsites.net" | grep -c "name")
    fi
    
    if [ "$domain_count" -gt 0 ]; then
      echo "Custom domains found: $domain_count"
      warning_message "Custom domains will need to be reconfigured on the new function app."
    else
      success_message "No custom domains found."
    fi
  else
    warning_message "Failed to retrieve custom domains."
  fi
  
  subsection_header "2.4 Checking for CORS settings..."
  
  # Check for CORS settings
  cors_settings=$(az functionapp cors show --name "$function_app_name" --resource-group "$resource_group" -o json)
  
  if [ $? -eq 0 ]; then
    # Save CORS settings to file
    echo "$cors_settings" > "$migration_dir/cors_settings.json"
    
    if command -v jq &> /dev/null; then
      allowed_origins=$(echo "$cors_settings" | jq -r '.allowedOrigins | length')
    else
      allowed_origins=$(echo "$cors_settings" | grep -c "allowedOrigins")
    fi
    
    if [ "$allowed_origins" -gt 0 ]; then
      echo "CORS settings found: $allowed_origins allowed origins"
      echo "These will need to be reconfigured on the new function app."
    else
      success_message "No CORS settings found."
    fi
  else
    warning_message "Failed to retrieve CORS settings."
  fi
  
  subsection_header "2.5 Checking identity configuration..."
  
  # Check for managed identities
  identity_config=$(az functionapp identity show --name "$function_app_name" --resource-group "$resource_group" -o json 2>/dev/null)
  
  # Save identity config to file (even if empty)
  echo "$identity_config" > "$migration_dir/identity_config.json"
  
  if [[ "$identity_config" != "" && "$identity_config" != "null" ]]; then
    if command -v jq &> /dev/null; then
      system_assigned=$(echo "$identity_config" | jq -r 'if .principalId then "enabled" else "disabled" end')
      user_assigned_count=$(echo "$identity_config" | jq -r 'if .userAssignedIdentities then (.userAssignedIdentities | length) else 0 end')
    else
      if echo "$identity_config" | grep -q "principalId"; then
        system_assigned="enabled"
      else
        system_assigned="disabled"
      fi
      user_assigned_count=$(echo "$identity_config" | grep -c "userAssignedIdentities")
    fi
    
    echo "Identity configuration:"
    echo "  System-assigned identity: $system_assigned"
    echo "  User-assigned identities: $user_assigned_count"
    
    if [[ "$system_assigned" == "enabled" ]]; then
      warning_message "System-assigned identity is enabled. Role assignments will need to be recreated for the new function app."
      # If we had more time, we would list role assignments here
    fi
    
    if [[ "$user_assigned_count" -gt 0 ]]; then
      warning_message "User-assigned identities are attached. These will need to be reattached to the new function app."
    fi
  else
    success_message "No managed identities found."
  fi
  
  subsection_header "2.6 Checking network access restrictions..."
  
  # Check for network access restrictions
  access_restrictions=$(az functionapp config access-restriction show --name "$function_app_name" --resource-group "$resource_group" -o json)
  
  if [ $? -eq 0 ]; then
    # Save access restrictions to file
    echo "$access_restrictions" > "$migration_dir/access_restrictions.json"
    
    if command -v jq &> /dev/null; then
      restriction_count=$(echo "$access_restrictions" | jq -r '.main.rules | length')
    else
      restriction_count=$(echo "$access_restrictions" | grep -c "\"name\":")
    fi
    
    if [ "$restriction_count" -gt 1 ]; then  # More than just the default rule
      echo "Network access restrictions found: $restriction_count rules"
      echo "These will need to be reconfigured on the new function app."
    else
      success_message "No custom network access restrictions found."
    fi
  else
    warning_message "Failed to retrieve network access restrictions."
  fi
  
  subsection_header "2.7 Checking for app and function keys..."
  
  # Check for host keys
  host_keys=$(az functionapp keys list --name "$function_app_name" --resource-group "$resource_group" -o json 2>/dev/null)
  
  if [ $? -eq 0 ]; then
    # Save host keys to file
    echo "$host_keys" > "$migration_dir/host_keys.json"
    
    if command -v jq &> /dev/null; then
      host_key_count=$(echo "$host_keys" | jq -r '.functionKeys | length')
    else
      host_key_count=$(echo "$host_keys" | grep -c "\"name\":")
    fi
    
    if [ "$host_key_count" -gt 0 ]; then
      echo "Function app keys found: $host_key_count keys"
      echo "These will need to be recreated on the new function app if needed."
    else
      success_message "No custom app keys found."
    fi
  else
    warning_message "Failed to retrieve app keys."
  fi
  
  success_message "Pre-migration tasks completed. Configuration data saved to the '$migration_dir' directory."
  echo "You can review this information before continuing with the migration."
  pause
}

# Function to create a new Flex Consumption function app
create_flex_consumption_app() {
  section_header "STEP 3: MIGRATION - Create Flex Consumption Function App"
  
  read -p "Enter a name for the new Flex Consumption function app (must be globally unique): " new_function_app_name
  
  # Check if app name is available
  name_available=$(az functionapp check-name-availability --name "$new_function_app_name" --query nameAvailable -o tsv)
  
  if [ "$name_available" != "true" ]; then
    error_message "The function app name '$new_function_app_name' is not available. Please choose a different name."
    create_flex_consumption_app  # Recursive call to try again
    return
  fi
  
  subsection_header "3.1 Creating a new storage account..."
  
  echo "Creating a new storage account for the function app..."
  storage_account_name="${new_function_app_name//-/}sa"
  storage_account_name=$(echo "$storage_account_name" | tr '[:upper:]' '[:lower:]' | cut -c 1-24)
  
  az storage account create --name "$storage_account_name" --resource-group "$resource_group" --location "$location" --sku Standard_LRS
  
  if [ $? -ne 0 ]; then
    error_message "Failed to create storage account."
    exit 1
  else
    success_message "Storage account '$storage_account_name' created successfully."
  fi
  
  # Get storage account connection string
  storage_connection_string=$(az storage account show-connection-string --name "$storage_account_name" --resource-group "$resource_group" --query connectionString -o tsv)
  
  subsection_header "3.2 Creating Flex Consumption function app..."
  
  echo "Creating Flex Consumption function app '$new_function_app_name'..."
  
  # Extract runtime info from the runtime stack
  IFS='|' read -ra stack_parts <<< "$runtime_stack"
  runtime_name="${stack_parts[0],,}"  # Convert to lowercase
  runtime_version="${stack_parts[1]}"
  
  if [[ "$runtime_name" == "dotnet" ]]; then
    runtime_name="dotnet-isolated"
    echo "Converting from dotnet to dotnet-isolated for Flex Consumption compatibility."
  fi
  
  az functionapp create --name "$new_function_app_name" \
      --resource-group "$resource_group" \
      --storage-account "$storage_account_name" \
      --runtime "$runtime_name" \
      --runtime-version "$runtime_version" \
      --consumption-plan-location "$location" \
      --flex-consumption \
      --functions-version 4
  
  if [ $? -ne 0 ]; then
    error_message "Failed to create Flex Consumption function app."
    exit 1
  else
    success_message "Flex Consumption function app '$new_function_app_name' created successfully."
  fi
  
  subsection_header "3.3 Configuring app settings..."
  
  echo "Filtering app settings to exclude deprecated settings..."
  
  # Prepare file path for app settings
  app_settings_file="$migration_dir/app_settings.json"
  
  if [ -f "$app_settings_file" ]; then
    # Filter out settings that don't apply to Flex Consumption or are automatically created
    if command -v jq &> /dev/null; then
      filtered_settings=$(cat "$app_settings_file" | jq 'map(select(
        (.name | ascii_downcase) != "website_use_placeholder_dotnetisolated" and
        (.name | ascii_downcase | startswith("azurewebjobsstorage") | not) and
        (.name | ascii_downcase) != "website_mount_enabled" and
        (.name | ascii_downcase) != "enable_oryx_build" and
        (.name | ascii_downcase) != "functions_extension_version" and
        (.name | ascii_downcase) != "functions_worker_runtime" and
        (.name | ascii_downcase) != "functions_worker_runtime_version" and
        (.name | ascii_downcase) != "functions_max_http_concurrency" and
        (.name | ascii_downcase) != "functions_worker_process_count" and
        (.name | ascii_downcase) != "functions_worker_dynamic_concurrency_enabled" and
        (.name | ascii_downcase) != "scm_do_build_during_deployment" and
        (.name | ascii_downcase) != "website_contentazurefileconnectionstring" and
        (.name | ascii_downcase) != "website_contentovervnet" and
        (.name | ascii_downcase) != "website_contentshare" and
        (.name | ascii_downcase) != "website_dns_server" and
        (.name | ascii_downcase) != "website_max_dynamic_application_scale_out" and
        (.name | ascii_downcase) != "website_node_default_version" and
        (.name | ascii_downcase) != "website_run_from_package" and
        (.name | ascii_downcase) != "website_skip_contentshare_validation" and
        (.name | ascii_downcase) != "website_vnet_route_all" and
        (.name | ascii_downcase) != "applicationinsights_connection_string"
      )) | map("\(.name)=\(.value)") | join(" ")')
      
      # Apply filtered settings
      if [ -n "$filtered_settings" ]; then
        # Remove quotes from the settings string
        filtered_settings="${filtered_settings//\"}"
        
        echo "Applying filtered app settings to the new function app..."
        az functionapp config appsettings set --name "$new_function_app_name" --resource-group "$resource_group" --settings $filtered_settings
        
        if [ $? -ne 0 ]; then
          warning_message "Failed to import all app settings. You may need to set some app settings manually."
        else
          success_message "App settings imported successfully."
        fi
      else
        warning_message "No compatible app settings found to transfer."
      fi
    else
      warning_message "jq tool not available. Manual app settings configuration is recommended."
      echo "Please review the app settings in $app_settings_file and apply them manually to the new function app."
    fi
  else
    warning_message "App settings file not found. Skipping app settings configuration."
  fi
  
  subsection_header "3.4 Applying general configuration..."
  
  # Apply general configuration settings from site_config.json
  site_config_file="$migration_dir/site_config.json"
  if [ -f "$site_config_file" ]; then
    echo "Applying general configuration settings..."
    
    # Extract key configuration settings
    if command -v jq &> /dev/null; then
      http20_enabled=$(cat "$site_config_file" | jq -r '.http20Enabled')
      https_only=$(az functionapp show --name "$function_app_name" --resource-group "$resource_group" --query httpsOnly -o tsv)
      min_tls_version=$(cat "$site_config_file" | jq -r '.minTlsVersion')
      client_cert_enabled=$(cat "$site_config_file" | jq -r '.clientCertEnabled')
      client_cert_mode=$(cat "$site_config_file" | jq -r '.clientCertMode')
    else
      # Fallback if jq is not available
      http20_enabled=$(grep -o '"http20Enabled":[^,}]*' "$site_config_file" | sed 's/"http20Enabled"://')
      https_only=$(az functionapp show --name "$function_app_name" --resource-group "$resource_group" --query httpsOnly -o tsv)
      min_tls_version=$(grep -o '"minTlsVersion":"[^"]*"' "$site_config_file" | sed 's/"minTlsVersion":"//;s/"$//')
      client_cert_enabled=$(grep -o '"clientCertEnabled":[^,}]*' "$site_config_file" | sed 's/"clientCertEnabled"://')
      client_cert_mode=$(grep -o '"clientCertMode":"[^"]*"' "$site_config_file" | sed 's/"clientCertMode":"//;s/"$//')
    fi
    
    # Apply HTTP version setting
    if [ -n "$http20_enabled" ] && [ "$http20_enabled" != "null" ]; then
      az functionapp config set --name "$new_function_app_name" --resource-group "$resource_group" --http20-enabled "$http20_enabled"
      if [ $? -eq 0 ]; then
        success_message "HTTP 2.0 setting applied: $http20_enabled"
      fi
    fi
    
    # Apply HTTPS Only setting
    if [ -n "$https_only" ] && [ "$https_only" != "null" ]; then
      az functionapp update --name "$new_function_app_name" --resource-group "$resource_group" --set httpsOnly="$https_only"
      if [ $? -eq 0 ]; then
        success_message "HTTPS Only setting applied: $https_only"
      fi
    fi
    
    # Apply minimum TLS version
    if [ -n "$min_tls_version" ] && [ "$min_tls_version" != "null" ]; then
      az functionapp config set --name "$new_function_app_name" --resource-group "$resource_group" --min-tls-version "$min_tls_version"
      if [ $? -eq 0 ]; then
        success_message "Minimum TLS version applied: $min_tls_version"
      fi
    fi
    
    # Apply client certificate settings
    if [ -n "$client_cert_enabled" ] && [ "$client_cert_enabled" != "null" ]; then
      az functionapp update --name "$new_function_app_name" --resource-group "$resource_group" --set clientCertEnabled="$client_cert_enabled"
      if [ $? -eq 0 ]; then
        success_message "Client certificate setting applied: $client_cert_enabled"
      fi
      
      # Apply client certificate mode if enabled
      if [ "$client_cert_enabled" = "true" ] && [ -n "$client_cert_mode" ] && [ "$client_cert_mode" != "null" ]; then
        az functionapp update --name "$new_function_app_name" --resource-group "$resource_group" --set clientCertMode="$client_cert_mode"
        if [ $? -eq 0 ]; then
          success_message "Client certificate mode applied: $client_cert_mode"
        fi
      fi
    fi
  else
    warning_message "Site configuration file not found. Skipping general configuration."
  fi
  
  subsection_header "3.5 Configuring identity..."
  
  # Configure identity
  identity_config_file="$migration_dir/identity_config.json"
  if [ -f "$identity_config_file" ] && [ -s "$identity_config_file" ] && [ "$(cat "$identity_config_file")" != "null" ]; then
    echo "Checking identity configuration..."
    
    # Check if system-assigned identity was enabled on the original app
    if command -v jq &> /dev/null; then
      system_assigned=$(cat "$identity_config_file" | jq -r 'if .principalId then "true" else "false" end')
    else
      if grep -q "principalId" "$identity_config_file"; then
        system_assigned="true"
      else
        system_assigned="false"
      fi
    fi
    
    if [ "$system_assigned" = "true" ]; then
      echo "Enabling system-assigned identity for the new function app..."
      az functionapp identity assign --name "$new_function_app_name" --resource-group "$resource_group"
      if [ $? -eq 0 ]; then
        success_message "System-assigned identity enabled."
        warning_message "Role assignments for the system-assigned identity need to be reconfigured manually."
        echo "Please check the original function app's role assignments and recreate them for the new app."
      fi
    fi
    
    # Check for user-assigned identities
    if command -v jq &> /dev/null && [ -n "$(cat "$identity_config_file" | jq -r '.userAssignedIdentities | keys[]?')" ]; then
      echo "User-assigned identities were found on the original app."
      echo "These need to be reassigned to the new function app manually."
      warning_message "Please use the Azure portal or CLI to assign the same user-assigned identities to the new function app."
    fi
  else
    echo "No identity configuration found for the original function app. Skipping identity setup."
  fi
  
  subsection_header "3.6 Configuring CORS settings..."
  
  # Apply CORS settings
  cors_file="$migration_dir/cors_settings.json"
  if [ -f "$cors_file" ] && [ -s "$cors_file" ] && [ "$(cat "$cors_file")" != "null" ]; then
    echo "Applying CORS settings..."
    
    if command -v jq &> /dev/null; then
      allowed_origins=$(cat "$cors_file" | jq -r '.allowedOrigins[]?' 2>/dev/null)
      
      if [ -n "$allowed_origins" ]; then
        for origin in $allowed_origins; do
          if [ "$origin" != "null" ] && [ "$origin" != "" ]; then
            echo "Adding allowed origin: $origin"
            az functionapp cors add --name "$new_function_app_name" --resource-group "$resource_group" --allowed-origins "$origin"
          fi
        done
        success_message "CORS settings applied."
      fi
    else
      warning_message "jq tool not available. Please configure CORS settings manually."
    fi
  else
    echo "No CORS settings found. Skipping CORS configuration."
  fi
  
  subsection_header "3.7 Configuring network access restrictions..."
  
  # Apply network access restrictions
  access_file="$migration_dir/access_restrictions.json"
  if [ -f "$access_file" ] && [ -s "$access_file" ] && [ "$(cat "$access_file")" != "null" ]; then
    echo "Network access restrictions found in the original app."
    warning_message "Network access restrictions need to be reconfigured manually."
    echo "Please use the Azure portal or CLI to apply the same network restrictions to the new function app."
  else
    echo "No network access restrictions found. Skipping network configuration."
  fi
  
  subsection_header "3.8 Application code deployment..."
  
  # Ask if the user wants to deploy code now
  read -p "Would you like to deploy your function code now? (y/n): " deploy_now
  
  if [[ $deploy_now == "y" ]]; then
    # Check if the original app was running from package
    if [ -n "$run_from_package" ]; then
      if [[ $run_from_package == http* || $run_from_package == https* ]]; then
        echo "The original app was running from a remote package URL: $run_from_package"
        read -p "Would you like to use the same package URL? (y/n): " use_same_package
        
        if [[ $use_same_package == "y" ]]; then
          echo "Deploying from package URL: $run_from_package"
          
          # For Flex Consumption, we need a different approach than WEBSITE_RUN_FROM_PACKAGE
          echo "Deploying using fetch deployment from URL method..."
          az functionapp deployment source config-zip -g "$resource_group" -n "$new_function_app_name" --src "$run_from_package"
          
          if [ $? -eq 0 ]; then
            success_message "Function app deployed successfully from package URL."
          else
            error_message "Failed to deploy function app from package URL."
            echo "You might need to download the package and deploy it locally."
          fi
        else
          echo "Skipping deployment from the same package."
          deploy_local_package
        fi
      else
        # Handle case where WEBSITE_RUN_FROM_PACKAGE=1 (local zip)
        echo "The original app was running from a local package."
        deploy_local_package
      fi
    else
      # No WEBSITE_RUN_FROM_PACKAGE setting
      echo "The original app was not configured with WEBSITE_RUN_FROM_PACKAGE."
      deploy_local_package
    fi
  else
    echo "Skipping code deployment. You can deploy your function code later."
  fi
  
  success_message "Flex Consumption function app creation and configuration completed."
  echo "The new function app has been created with name: $new_function_app_name"
}

# Helper function to deploy from a local package
deploy_local_package() {
  read -p "Enter the path to your function app package (.zip file): " package_path
  
  if [ -f "$package_path" ]; then
    echo "Deploying from local package: $package_path"
    az functionapp deployment source config-zip -g "$resource_group" -n "$new_function_app_name" --src "$package_path"
    
    if [ $? -eq 0 ]; then
      success_message "Function app deployed successfully from local package."
    else
      error_message "Failed to deploy function app from local package."
    fi
  else
    error_message "Package file not found: $package_path"
  fi
}

# Function to validate the migration
validate_migration() {
  section_header "STEP 4: VALIDATION"
  
  subsection_header "4.1 Verifying Flex Consumption configuration..."
  
  echo "Verifying the new function app is running on Flex Consumption plan..."
  
  # Check if the function app exists
  app_exists=$(az functionapp show --name "$new_function_app_name" --resource-group "$resource_group" --query "name" -o tsv 2>/dev/null)
  
  if [ -z "$app_exists" ]; then
    error_message "Function app '$new_function_app_name' not found."
    exit 1
  fi
  
  # Check the app's SKU
  sku=$(az functionapp show --name "$new_function_app_name" --resource-group "$resource_group" --query "sku" -o tsv)
  
  if [ "$sku" == "Flex" ]; then
    success_message "Function app '$new_function_app_name' is running on Flex Consumption plan."
    
    # Get the function app URL
    app_url=$(az functionapp show --name "$new_function_app_name" --resource-group "$resource_group" --query "defaultHostName" -o tsv)
    
    echo "Function app URL: https://$app_url"
  else
    error_message "Function app '$new_function_app_name' is not running on Flex Consumption plan."
    echo "Current SKU: $sku"
    exit 1
  fi
  
  subsection_header "4.2 Checking application functionality..."
  
  # Check if the function app is ready
  echo "Waiting for the function app to be ready for testing..."
  echo "This may take a few minutes..."
  
  # Print command to view logs
  echo -e "\nYou can monitor the function app logs using:"
  echo "  az functionapp log tail --name \"$new_function_app_name\" --resource-group \"$resource_group\""
  
  # List functions in the app
  echo -e "\nChecking for functions in the app..."
  functions=$(az functionapp function list --name "$new_function_app_name" --resource-group "$resource_group" --query "[].name" -o tsv 2>/dev/null)
  
  if [ -z "$functions" ]; then
    warning_message "No functions found or functions are still initializing in the new app."
    echo "This might be normal if deployment is still in progress."
  else
    echo "Functions found in the app:"
    for func in $functions; do
      echo "  - $func"
    done
    
    # Check for HTTP functions to provide testing URLs
    for func in $functions; do
      binding_type=$(az functionapp function show --name "$new_function_app_name" --resource-group "$resource_group" --function-name "$func" --query "config.bindings[0].type" -o tsv 2>/dev/null)
      
      if [[ $binding_type == *"Trigger"* && $binding_type == *"Http"* ]]; then
        echo -e "\nHTTP function detected: $func"
        echo "You can test this function at: https://$app_url/api/$func"
      fi
    done
  fi
  
  subsection_header "4.3 Performance and monitoring..."
  
  # Display App Insights link if available
  app_insights_key=$(az functionapp config appsettings list --name "$new_function_app_name" --resource-group "$resource_group" --query "[?name=='APPLICATIONINSIGHTS_CONNECTION_STRING'].value" -o tsv)
  
  if [ -n "$app_insights_key" ]; then
    echo "Application Insights is configured for this function app."
    echo "Monitor your function performance in the Azure portal."
  else
    warning_message "Application Insights is not configured for this function app."
    echo "Consider setting up Application Insights for better monitoring capabilities."
  fi
  
  # Show Flex Consumption specific metrics to monitor
  echo -e "\nKey metrics to monitor for your Flex Consumption app:"
  echo "  - AlwaysReadyFunctionExecutionCount"
  echo "  - OnDemandFunctionExecutionCount"
  echo "  - AlwaysReadyFunctionExecutionUnits"
  echo "  - OnDemandFunctionExecutionUnits"
  echo "  - AverageMemoryWorkingSet"
  echo "  - InstanceCount"
  
  echo -e "\nYou can monitor these metrics using:"
  echo "az monitor metrics list --resource <ResourceId> --metric <MetricName>"
  
  read -p "Have you tested the application and verified it works as expected? (y/n): " app_works_ok
  
  if [[ $app_works_ok == "y" ]]; then
    success_message "Migration validation successful!"
  else
    warning_message "Migration validation incomplete. Additional testing recommended."
    
    # Provide troubleshooting guidance
    echo -e "\nTroubleshooting tips:"
    echo "1. Check function app logs for errors:"
    echo "   az functionapp log tail --name \"$new_function_app_name\" --resource-group \"$resource_group\""
    echo "2. Verify app settings are correctly configured"
    echo "3. Check if the application code deployment completed successfully"
    echo "4. Review any binding configurations"
    
    read -p "Do you want to continue with post-migration tasks anyway? (y/n): " continue_anyway
    if [[ $continue_anyway != "y" ]]; then
      echo "Stopping the migration process. Please resolve the issues before continuing."
      exit 1
    fi
  fi
}

# Function to complete post-migration tasks
post_migration_tasks() {
  section_header "STEP 5: POST-MIGRATION TASKS"
  
  subsection_header "5.1 Update DNS and custom domains..."
  
  echo "If you used custom domains with your original function app, you'll need to update the DNS configuration."
  
  # Check for custom domains from the previously saved file
  custom_domains_file="$migration_dir/custom_domains.json"
  if [ -f "$custom_domains_file" ] && [ -s "$custom_domains_file" ] && [ "$(cat "$custom_domains_file")" != "null" ]; then
    if command -v jq &> /dev/null; then
      custom_domain_count=$(cat "$custom_domains_file" | jq -r '[.[] | select(.name | contains(".azurewebsites.net") | not)] | length')
    else
      custom_domain_count=$(grep -v ".azurewebsites.net" "$custom_domains_file" | grep -c "name")
    fi
    
    if [ "$custom_domain_count" -gt 0 ]; then
      echo "Your original function app had $custom_domain_count custom domain(s)."
      echo "Steps to update custom domains:"
      echo "1. Add custom domains to the new function app in the Azure portal"
      echo "2. Update DNS records to point to the new function app"
      echo "3. Verify DNS propagation and test the custom domains"
      
      read -p "Have you updated your custom domains? (y/n/skip): " domains_updated
      if [[ $domains_updated == "y" ]]; then
        success_message "Custom domains have been updated."
      elif [[ $domains_updated == "n" ]]; then
        warning_message "Please update your custom domains after completing this script."
      fi
    else
      echo "No custom domains found for the original function app."
    fi
  else
    echo "No custom domain information available. Skipping custom domain update."
  fi
  
  subsection_header "5.2 Update CI/CD pipelines..."
  
  echo "If you have CI/CD pipelines targeting your original function app, you need to update them."
  echo "Common CI/CD systems to check:"
  echo "- Azure DevOps pipelines"
  echo "- GitHub Actions workflows"
  echo "- Jenkins jobs"
  echo "- Any other automated deployment processes"
  
  echo -e "\nKeypoints for updating pipelines for Flex Consumption:"
  echo "1. Change the target function app name to: $new_function_app_name"
  echo "2. Update or remove WEBSITE_RUN_FROM_PACKAGE settings (not used in Flex Consumption)"
  echo "3. Add the '--flex-consumption' flag to any 'az functionapp create' commands"
  echo "4. Update Azure Resource Manager (ARM) templates to use the Flex Consumption model"
  
  read -p "Have you updated your CI/CD pipelines? (y/n/skip): " pipelines_updated
  if [[ $pipelines_updated == "y" ]]; then
    success_message "CI/CD pipelines have been updated."
  elif [[ $pipelines_updated == "n" ]]; then
    warning_message "Please update your CI/CD pipelines after completing this script."
  fi
  
  subsection_header "5.3 Update Infrastructure as Code..."
  
  echo "If you're using Infrastructure as Code (IaC) to manage your Azure resources, update your templates:"
  echo "- For ARM templates: Update functionAppConfig section for Flex Consumption"
  echo "- For Bicep: Update functionAppConfig for Flex Consumption"
  echo "- For Terraform: Use the new azurerm_function_app_flex resource type"
  
  echo -e "\nRecommended resources for IaC with Flex Consumption:"
  echo "- ARM/Bicep: https://github.com/Azure-Samples/azure-functions-flex-consumption-samples/tree/main/IaC/bicep"
  echo "- Terraform: https://github.com/Azure-Samples/azure-functions-flex-consumption-samples/tree/main/IaC/terraform"
  
  read -p "Have you updated your Infrastructure as Code templates? (y/n/skip): " iac_updated
  if [[ $iac_updated == "y" ]]; then
    success_message "Infrastructure as Code templates have been updated."
  elif [[ $iac_updated == "n" ]]; then
    warning_message "Please update your Infrastructure as Code templates after completing this script."
  fi
  
  subsection_header "5.4 App name management..."
  
  # Ask if the user wants to swap app names
  read -p "Would you like to swap the function app names? This will rename the original app and give its name to the new app. (y/n): " swap_names
  
  if [[ $swap_names == "y" ]]; then
    temp_name="${function_app_name}-old"
    
    echo "Renaming the original function app to '$temp_name'..."
    az resource move --ids $(az functionapp show -g "$resource_group" -n "$function_app_name" --query id -o tsv) --destination-name "$temp_name"
    
    if [ $? -ne 0 ]; then
      error_message "Failed to rename the original function app."
      echo "You can rename it manually in the Azure portal."
    else
      success_message "Original function app renamed to '$temp_name'."
      
      echo "Renaming the new function app to '$function_app_name'..."
      az resource move --ids $(az functionapp show -g "$resource_group" -n "$new_function_app_name" --query id -o tsv) --destination-name "$function_app_name"
      
      if [ $? -ne 0 ]; then
        error_message "Failed to rename the new function app."
        echo "You can rename it manually in the Azure portal."
      else
        success_message "New function app renamed to '$function_app_name'."
        new_function_app_name="$function_app_name"
      fi
    fi
  fi
  
  subsection_header "5.5 Resource cleanup (optional)..."
  
  # Ask if the user wants to delete the original app
  read -p "Would you like to delete the original function app? WARNING: This cannot be undone. (y/n): " delete_original
  
  if [[ $delete_original == "y" ]]; then
    original_name=$([[ $swap_names == "y" ]] && echo "$temp_name" || echo "$function_app_name")
    
    # Double-check with the user
    read -p "Are you ABSOLUTELY SURE you want to delete $original_name? This is irreversible. Type 'yes' to confirm: " final_confirm
    
    if [[ $final_confirm == "yes" ]]; then
      echo "Deleting the original function app '$original_name'..."
      az functionapp delete --name "$original_name" --resource-group "$resource_group"
      
      if [ $? -ne 0 ]; then
        error_message "Failed to delete the original function app."
      else
        success_message "Original function app deleted successfully."
      fi
    else
      echo "Deletion cancelled."
    fi
  else
    echo "Original function app preserved."
  fi
  
  # Cleanup migration directory (optional)
  read -p "Would you like to delete the temporary migration files in '$migration_dir'? (y/n): " delete_migration_dir
  
  if [[ $delete_migration_dir == "y" ]]; then
    rm -rf "$migration_dir"
    echo "Migration directory deleted."
  fi
  
  section_header "MIGRATION COMPLETE"
  echo "Your Azure Function App has been successfully migrated from Linux Consumption to Flex Consumption!"
  echo ""
  echo "New function app details:"
  echo "  Name: $new_function_app_name"
  echo "  Resource Group: $resource_group"
  echo "  URL: https://$(az functionapp show --name "$new_function_app_name" --resource-group "$resource_group" --query "defaultHostName" -o tsv)"
  echo ""
  echo "Post-migration recommendations:"
  echo "1. Monitor your function app using Azure Monitor metrics specific to Flex Consumption"
  echo "2. Review the Flex Consumption documentation for optimization guidance"
  echo "3. Consider implementing identity-based connections for enhanced security"
  echo ""
  echo "For more information on Flex Consumption, visit:"
  echo "https://learn.microsoft.com/en-us/azure/azure-functions/flex-consumption-plan"
}

# Main function
main() {
  echo -e "\n${BOLD}=================================================${NC}"
  echo -e "${BOLD}  AZURE FUNCTIONS: LINUX CONSUMPTION TO FLEX CONSUMPTION MIGRATION${NC}"
  echo -e "${BOLD}=================================================${NC}\n"
  
  echo "This script will guide you through the process of migrating an Azure Function App from Linux Consumption to Flex Consumption."
  echo "Version: 1.0 (April 2025)"
  echo -e "\nThe migration process consists of the following steps:\n"
  echo "1. ASSESSMENT: Identify function apps and verify compatibility"
  echo "2. PRE-MIGRATION: Export settings and prepare for migration"
  echo "3. MIGRATION: Create a new Flex Consumption function app"
  echo "4. VALIDATION: Verify the new function app works as expected"
  echo "5. POST-MIGRATION: Update DNS, CI/CD, and clean up resources"
  echo -e "\n"
  
  echo -e "${YELLOW}⚠ IMPORTANT NOTES:${NC}"
  echo "• This script creates a new Flex Consumption function app alongside your existing app"
  echo "• Your original function app will not be modified until the post-migration phase"
  echo "• Backup any critical configuration or custom settings before proceeding"
  echo "• Some features like deployment slots and certificates are not supported in Flex Consumption"
  echo -e "• For detailed documentation, visit: https://learn.microsoft.com/en-us/azure/azure-functions/flex-consumption-plan\n"
  
  read -p "Press Enter to continue or Ctrl+C to exit..."
  
  # Run the migration steps
  check_prerequisites
  list_linux_consumption_apps
  export_app_settings
  create_flex_consumption_app
  validate_migration
  post_migration_tasks
  
  echo -e "\n${BOLD}Migration script completed.${NC}"
  echo "For more information about optimizing your Flex Consumption app, visit:"
  echo "https://learn.microsoft.com/en-us/azure/azure-functions/flex-consumption-how-to"
}

# Run the main function
main