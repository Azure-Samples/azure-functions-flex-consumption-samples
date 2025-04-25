#!/bin/bash

# Azure Functions Migration: Linux Consumption to Flex Consumption Guide
# This script guides you through the process of migrating Azure Function Apps 
# from Linux Consumption to Flex Consumption
# Updated: April 25, 2025

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
  section_header "ASSESSMENT - Identify a Function App Running on Linux Consumption"
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
  
  section_header "ASSESSMENT - Verify Region Compatibility"
  verify_region_compatibility "$location"
  
  section_header "ASSESSMENT - Verify Runtime Compatibility"
  verify_runtime_compatibility "$runtime_name" "$runtime_version" "$location"
  
  section_header "ASSESSMENT - Verify Deployment Slots Usage"
  verify_deployment_slots "$function_app_name" "$resource_group"
  
  section_header "ASSESSMENT - Verify Use of Certificates"
  verify_certificates "$function_app_name" "$resource_group"
  
  section_header "ASSESSMENT - Verify Use of Blob Trigger"
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
      error_message "The dotnet in-process runtime is not supported in Flex Consumption."
      echo "You need to migrate your app to the dotnet-isolated runtime first."
      echo "Please follow the migration guide before continuing: https://learn.microsoft.com/en-us/azure/azure-functions/migrate-dotnet-to-isolated-model"
      
      read -p "Have you already completed the migration of your app code to dotnet-isolated? (y/n): " already_migrated
      if [[ $already_migrated == "y" ]]; then
        read -p "Please confirm that your app code has been fully migrated to use the .NET isolated model (y/n): " confirm_migration
        if [[ $confirm_migration == "y" ]]; then
          runtime_name="dotnet-isolated"
          success_message "Proceeding with migration using dotnet-isolated runtime."
        else
          error_message "Please complete the migration to dotnet-isolated before continuing."
          echo "Migration process stopped. Run this script again after completing your code migration."
          exit 1
        fi
      else
        error_message "Migration to Flex Consumption requires converting to dotnet-isolated first."
        echo "Migration process stopped. Run this script again after completing your code migration."
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
  section_header "PRE-MIGRATION TASKS - App Settings"
  echo "Collecting app settings configuration for function app '$function_app_name'..."
  
  # Create a directory to store migration info
  migration_dir="flex_migration_${function_app_name}"
  mkdir -p "$migration_dir"
  
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
  
  section_header "PRE-MIGRATION TASKS - App Configuration"
  
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
  
  section_header "PRE-MIGRATION TASKS - Identity Based Role Access"
  
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
  
  section_header "PRE-MIGRATION TASKS - Built-in Authentication, App and Function Keys"
  
  section_header "PRE-MIGRATION TASKS - Networking Access Restrictions"
  
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
  
  section_header "PRE-MIGRATION TASKS - App Code or Zip File"
  
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
    # Use a simpler, potentially more unique name based on the new app name
    storage_account_name="st$(echo $new_function_app_name | tr -dc '[:alnum:]' | tr '[:upper:]' '[:lower:]' | cut -c 1-20)"
  
    print_info "Attempting to create storage account: $storage_account_name in $location..."
    az storage account create --name "$storage_account_name" --resource-group "$resource_group" --location "$location" --sku Standard_LRS --allow-blob-public-access false
  
    if [ $? -ne 0 ]; then
        error_message "Failed to create storage account '$storage_account_name'."
        # Check if it already exists and belongs to the user?
        existing_sku=$(az storage account show --name "$storage_account_name" --resource-group "$resource_group" --query sku.name -o tsv 2>/dev/null)
        if [[ -n "$existing_sku" ]]; then
            print_warning "Storage account '$storage_account_name' already exists. Attempting to use it."
        else
            exit 1
        fi
    else
        success_message "Storage account '$storage_account_name' created successfully."
    fi
  
    # Get storage account ID for role assignment later
    storage_account_id=$(az storage account show --name "$storage_account_name" --resource-group "$resource_group" --query id -o tsv)
    if [[ -z "$storage_account_id" ]]; then
        error_message "Failed to get resource ID for storage account '$storage_account_name'."
        exit 1
    fi
  
    subsection_header "3.2 Creating Flex Consumption function app with Managed Identity..."
  
    echo "Creating Flex Consumption function app '$new_function_app_name' with System-Assigned Managed Identity..."
  
    # Extract runtime info from the runtime stack
    IFS='|' read -ra stack_parts <<< "$runtime_stack"
    runtime_name="${stack_parts[0],,}"  # Convert to lowercase
    runtime_version="${stack_parts[1]}"
    if [[ "$runtime_name" == "dotnet" ]]; then
      runtime_name="dotnet-isolated"
      print_warning "Adjusting runtime to dotnet-isolated as dotnet in-process is not supported."
    fi
  
    # Create app without --storage-account but WITH --assign-identity and using --flexconsumption-location
    az functionapp create --name "$new_function_app_name" \
        --resource-group "$resource_group" \
        --flexconsumption-location "$location" \
        --runtime "$runtime_name" \
        --runtime-version "$runtime_version" \
        --flex-consumption \
        --assign-identity "[system]"
  
    if [ $? -ne 0 ]; then
        error_message "Failed to create Flex Consumption function app '$new_function_app_name'."
        exit 1
    else
        success_message "Flex Consumption function app '$new_function_app_name' created successfully."
    fi
  
    subsection_header "3.2.1 Getting Managed Identity Principal ID..."
    principal_id=$(az functionapp identity show --name "$new_function_app_name" --resource-group "$resource_group" --query principalId -o tsv)
    if [[ -z "$principal_id" || "$principal_id" == "null" ]]; then
        error_message "Failed to retrieve principal ID for the new function app's system-assigned identity."
        print_warning "Manual role assignment will be required for AzureWebJobsStorage."
        # Allow script to continue but AzureWebJobsStorage might not work
    else
        success_message "Retrieved principal ID: $principal_id"
    fi
  
    subsection_header "3.2.2 Assigning Storage Roles to Managed Identity..."
    if [[ -n "$principal_id" && "$principal_id" != "null" ]]; then
        print_info "Assigning required storage roles to identity $principal_id on storage account $storage_account_name..."
        # It might take a moment for the identity to propagate, add a small delay
        print_info "Waiting for identity propagation (15s)..."
        sleep 15

        roles_assigned_successfully=true

        # Assign Storage Blob Data Owner
        print_info "  Assigning 'Storage Blob Data Owner'..."
        az role assignment create --assignee "$principal_id" --role "Storage Blob Data Owner" --scope "$storage_account_id" --output none
        if [[ $? -ne 0 ]]; then
            error_message "    Failed to assign 'Storage Blob Data Owner' role."
            roles_assigned_successfully=false
        else
            success_message "    'Storage Blob Data Owner' role assigned."
        fi

        # Assign Storage Queue Data Contributor
        print_info "  Assigning 'Storage Queue Data Contributor'..."
        az role assignment create --assignee "$principal_id" --role "Storage Queue Data Contributor" --scope "$storage_account_id" --output none
        if [[ $? -ne 0 ]]; then
            error_message "    Failed to assign 'Storage Queue Data Contributor' role."
            roles_assigned_successfully=false
        else
            success_message "    'Storage Queue Data Contributor' role assigned."
        fi

        # Assign Storage Table Data Contributor (Optional but good practice if tables might be used)
        print_info "  Assigning 'Storage Table Data Contributor'..."
        az role assignment create --assignee "$principal_id" --role "Storage Table Data Contributor" --scope "$storage_account_id" --output none
        if [[ $? -ne 0 ]]; then
            error_message "    Failed to assign 'Storage Table Data Contributor' role."
            roles_assigned_successfully=false
            # This might be less critical than blob/queue, so maybe just warn
        else
            success_message "    'Storage Table Data Contributor' role assigned."
        fi

        # Final check and warning
        if ! $roles_assigned_successfully; then
            print_warning "One or more required storage roles could not be assigned automatically."
            print_warning "This is required for the function app to access '$storage_account_name' using Managed Identity."
            print_warning "Please assign the roles manually in the Azure portal (Storage Account -> Access Control (IAM))."
            print_warning "Required roles: Storage Blob Data Owner, Storage Queue Data Contributor, Storage Table Data Contributor."
            read -p "Press [Enter] to continue despite role assignment failure(s)..."
        else
            success_message "Required storage roles assigned successfully."
        fi
    else
        print_warning "Skipping role assignment because principal ID could not be retrieved."
    fi

    subsection_header "3.3 Configuring app settings (using Managed Identity for Storage)..."
  
    echo "Filtering app settings to exclude deprecated settings..."
    app_settings_file="$migration_dir/app_settings.json"
  
    if [ -f "$app_settings_file" ]; then
        if command -v jq &> /dev/null; then
            # Filter out settings as before, ensuring AzureWebJobsStorage is excluded
            filtered_settings=$(cat "$app_settings_file" | jq 'map(select(
              (.name | ascii_downcase | startswith("azurewebjobsstorage") | not) and # Ensure original is excluded
              (.name | ascii_downcase) != "website_use_placeholder_dotnetisolated" and
              (.name | ascii_downcase) != "website_mount_enabled" and
              (.name | ascii_downcase) != "enable_oryx_build" and
              (.name | ascii_downcase) != "functions_extension_version" and # Will set explicitly
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
  
            # Apply filtered settings first
            if [ -n "$filtered_settings" ]; then
                filtered_settings="${filtered_settings//\"/}" # Remove quotes
                print_info "Applying filtered app settings from source app..."
                az functionapp config appsettings set --name "$new_function_app_name" --resource-group "$resource_group" --settings $filtered_settings --output none
                [[ $? -ne 0 ]] && warning_message "Failed to import some app settings. Review manually."
            else
                print_info "No compatible app settings found to transfer from source."
            fi
  
            # Now, explicitly set AzureWebJobsStorage using Managed Identity
            print_info "Configuring AzureWebJobsStorage with Managed Identity..."
            storage_blob_uri="https://${storage_account_name}.blob.core.windows.net"
            storage_queue_uri="https://${storage_account_name}.queue.core.windows.net"
            storage_table_uri="https://${storage_account_name}.table.core.windows.net" # Add table URI

            identity_settings=(
                "AzureWebJobsStorage__blobServiceUri=$storage_blob_uri"
                "AzureWebJobsStorage__queueServiceUri=$storage_queue_uri"
                "AzureWebJobsStorage__tableServiceUri=$storage_table_uri" # Add table URI setting
                "FUNCTIONS_EXTENSION_VERSION=~4" # Required for identity-based connections
            )
  
            az functionapp config appsettings set --name "$new_function_app_name" --resource-group "$resource_group" --settings "${identity_settings[@]}" --output none
  
            if [[ $? -ne 0 ]]; then
                error_message "Failed to configure AzureWebJobsStorage with Managed Identity."
                print_warning "The function app might not start correctly. Verify app settings and role assignments."
            else
                success_message "AzureWebJobsStorage configured with Managed Identity."
            fi
  
        else
            # jq not available - manual configuration needed
            warning_message "jq tool not available. Manual app settings configuration is required."
            print_warning "Please configure required app settings manually."
            print_warning "Ensure AzureWebJobsStorage is configured using Managed Identity for storage account '$storage_account_name':"
            print_warning "  AzureWebJobsStorage__blobServiceUri=https://${storage_account_name}.blob.core.windows.net"
            print_warning "  AzureWebJobsStorage__queueServiceUri=https://${storage_account_name}.queue.core.windows.net"
            print_warning "  AzureWebJobsStorage__tableServiceUri=https://${storage_account_name}.table.core.windows.net"
            print_warning "  FUNCTIONS_EXTENSION_VERSION=~4"
        fi
    else
        warning_message "App settings file not found. Skipping app settings configuration."
        print_warning "Manual app settings configuration is required, including AzureWebJobsStorage with Managed Identity."
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
    
    # Apply SCM Basic Auth Publishing Credentials
    print_info "Applying SCM Basic Auth Publishing Credentials setting (${config_settings["basicPublishingCredentialsPolicies"]})..."
    az resource update --resource-group "$dest_resource_group_name" --name scm --namespace Microsoft.Web --resource-type basicPublishingCredentialsPolicies --parent sites/"$dest_function_app_name" --set properties.allow=${config_settings["basicPublishingCredentialsPolicies"]} --output none
    if [[ $? -ne 0 ]]; then
      print_error "Failed to apply SCM Basic Auth Publishing Credentials setting."
      # Decide if this is critical enough to stop
    fi
    
    subsection_header "3.5 Applying Scale and Concurrency settings..."
    if [[ -n "${config_settings["maximumInstanceCount"]}" ]]; then
      max_scale_out=${config_settings["maximumInstanceCount"]}
      print_info "Applying Maximum Instance Count: $max_scale_out..."
      # Note: Flex Consumption minimum is 40. Adjust if original was lower?
      # For now, apply the captured value directly.
      az functionapp scale config set --name "$dest_function_app_name" --resource-group "$dest_resource_group_name" \
          --maximum-instance-count "$max_scale_out" --output none
      if [[ $? -ne 0 ]]; then
          print_error "Failed to apply Maximum Instance Count setting."
          # Decide if this is critical enough to stop
      else
          print_success "Maximum Instance Count applied."
      fi
    else
      print_info "No custom Maximum Scale Out Limit was set on the source app. Skipping Scale and Concurrency configuration."
    fi
  
    subsection_header "3.6 Configuring Storage Mounts..."
    
    # Apply Storage Mounts (Path Mappings)
    print_progress "Applying Storage Mounts (Path Mappings)..."
    if [[ -n "${config_settings["storageMounts"]}" ]]; then
        print_info "Found saved Storage Mount configuration. Applying..."
        echo "${config_settings["storageMounts"]}" | jq -c '.[]' | while IFS= read -r mount_config; do
            mount_name=$(echo "$mount_config" | jq -r '.name')
            mount_type=$(echo "$mount_config" | jq -r '.type')
            account_name=$(echo "$mount_config" | jq -r '.accountName')
            share_name=$(echo "$mount_config" | jq -r '.shareName')
            access_key=$(echo "$mount_config" | jq -r '.accessKey') # Note: This might be null if using identity
            mount_path=$(echo "$mount_config" | jq -r '.mountPath')
  
            print_info "Applying mount: $mount_name ($mount_type) at $mount_path"
  
            # Construct the command. Handle potential null access key if identity was used (though less common in Consumption)
            cmd=("az" "webapp" "config" "storage-account" "add" \
                 "--resource-group" "$dest_resource_group_name" \
                 "--name" "$dest_function_app_name" \
                 "--custom-id" "$mount_name" \
                 "--storage-type" "$mount_type" \
                 "--account-name" "$account_name" \
                 "--share-name" "$share_name" \
                 "--mount-path" "$mount_path")
  
            if [[ -n "$access_key" && "$access_key" != "null" ]]; then
                 cmd+=("--access-key" "$access_key")
            else
                # If access key is null, maybe prompt user or attempt identity? For now, warn.
                print_warning "Access key for mount '$mount_name' is missing. Manual configuration might be needed if identity wasn't used."
                # Attempting without access key might fail, but let's try
            fi
  
            # Execute the command
            "${cmd[@]}" --output none
            if [[ $? -ne 0 ]]; then
                print_error "Failed to apply storage mount: $mount_name. Manual configuration required."
            else
                print_success "Storage mount '$mount_name' applied."
            fi
        done
    else
        print_info "No Storage Mounts were configured on the source app. Skipping."
    fi
  
    subsection_header "3.7 Configuring CORS settings..."
    
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
    
    subsection_header "3.8 Configuring network access restrictions..."
    
    # Apply network access restrictions
    access_file="$migration_dir/access_restrictions.json"
    if [ -f "$access_file" ] && [ -s "$access_file" ] && [ "$(cat "$access_file")" != "null" ]; then
      echo "Network access restrictions found in the original app."
      warning_message "Network access restrictions need to be reconfigured manually."
      echo "Please use the Azure portal or CLI to apply the same network restrictions to the new function app."
    else
      echo "No network access restrictions found. Skipping network configuration."
    fi
    
    subsection_header "3.9 Application code deployment..."
    
    # Get the run_from_package setting again, as it might have been captured earlier
    run_from_package="${config_settings["runFromPackage"]}"
  
    # Ask if the user wants to deploy code now
    read -p "Would you like to deploy your function code now? (y/n): " deploy_now
  
    if [[ "$deploy_now" == "y" ]]; then
        # Check if the original app was running from package
        if [[ -n "$run_from_package" ]]; then
            if [[ $run_from_package == http* || $run_from_package == https* ]]; then
                print_info "The original app was running from a remote package URL: $run_from_package"
                read -p "Would you like to deploy directly using the same package URL? (y/n): " use_same_package
  
                if [[ "$use_same_package" == "y" ]]; then
                    print_info "Deploying using fetch deployment from URL method..."
                    az functionapp deployment source config-zip -g "$dest_resource_group_name" -n "$dest_function_app_name" --src "$run_from_package"
  
                    if [ $? -eq 0 ]; then
                        success_message "Function app deployed successfully from package URL."
                    else
                        error_message "Failed to deploy function app directly from package URL."
                        read -p "Would you like to try downloading the package and deploying it locally? (y/n): " download_and_deploy
                        if [[ "$download_and_deploy" == "y" ]]; then
                            download_package "$run_from_package"
                        else
                            print_warning "Skipping code deployment."
                        fi
                    fi
                else
                    read -p "Would you like to download the package from the URL to deploy it locally? (y/n): " download_first
                    if [[ "$download_first" == "y" ]]; then
                         download_package "$run_from_package"
                    else
                        print_info "Okay, skipping download. You can provide a local path if you have one."
                        deploy_local_package # Prompt for local path
                    fi
                fi
            elif [[ "$run_from_package" == "1" ]]; then
                # Handle case where WEBSITE_RUN_FROM_PACKAGE=1 (local zip)
                print_info "The original app was configured to run from a package (WEBSITE_RUN_FROM_PACKAGE=1)."
                print_warning "The specific package path used previously is unknown."
                deploy_local_package # Prompt for local path
            else
                 print_warning "Unrecognized WEBSITE_RUN_FROM_PACKAGE value: $run_from_package"
                 deploy_local_package # Prompt for local path
            fi
        else
            # No WEBSITE_RUN_FROM_PACKAGE setting
            print_info "The original app was not configured with WEBSITE_RUN_FROM_PACKAGE."
            deploy_local_package # Prompt for local path
        fi
    else
        print_warning "Skipping code deployment. You can deploy your function code later using 'az functionapp deployment source config-zip'."
    fi
  
    success_message "Flex Consumption function app creation and initial configuration completed."
    print_info "The new function app has been created with name: $dest_function_app_name"
}

# Helper function to deploy from a local package
deploy_local_package() {
    local package_path="$1" # Accept optional path argument

    if [[ -z "$package_path" ]]; then
        read -p "Enter the path to your function app package (.zip file): " package_path
    fi

    if [ -f "$package_path" ]; then
        print_info "Deploying from local package: $package_path"
        az functionapp deployment source config-zip -g "$dest_resource_group_name" -n "$dest_function_app_name" --src "$package_path"

        if [ $? -eq 0 ]; then
            success_message "Function app deployed successfully from local package."
        else
            error_message "Failed to deploy function app from local package."
        fi
    else
        error_message "Package file not found: $package_path"
        # Ask if user wants to try again or skip
        read -p "Deployment failed. Try entering the path again? (y/n): " retry_deploy
        if [[ "$retry_deploy" == "y" ]]; then
            deploy_local_package # Call recursively without path argument to prompt again
        else
            print_warning "Skipping code deployment."
        fi
    fi
}

# Helper function to download package from URL
download_package() {
    local package_url="$1"
    local download_filename="$(basename "$package_url")"
    # Ensure filename ends with .zip if it doesn't have an extension
    if [[ ! "$download_filename" == *.* ]]; then
        download_filename+=".zip"
    fi
    local download_path="$migration_dir/$download_filename"

    print_info "Attempting to download package from $package_url to $download_path..."

    # Use curl to download. Follow redirects (-L), show errors (-f), silent (-s), output to file (-o)
    if curl -LfsS "$package_url" -o "$download_path"; then
        success_message "Package downloaded successfully to $download_path"
        deploy_local_package "$download_path" # Deploy the downloaded package
    else
        error_message "Failed to download package from $package_url."
        print_warning "Please check the URL and network connectivity."
        # Offer to try manual path entry
        read -p "Would you like to try providing a local path manually? (y/n): " try_manual_path
        if [[ "$try_manual_path" == "y" ]]; then
            deploy_local_package
        else
            print_warning "Skipping code deployment."
        fi
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

  subsection_header "4.3: Configure Identity Role Assignments (Manual Reminder)"
  print_progress "Handling Identity Role Assignments..."
  if [[ -n "${config_settings["systemAssignedIdentityPrincipalId"]}" || -n "${config_settings["userAssignedIdentities"]}" ]]; then
      print_warning "ACTION REQUIRED: The source app used Managed Identities."
      if [[ -n "${config_settings["systemAssignedIdentityPrincipalId"]}" ]]; then
          print_warning " - System-Assigned Identity was enabled."
          print_warning "   A new System-Assigned Identity was enabled on '$dest_function_app_name'."
          print_warning "   You MUST manually recreate the necessary Azure Role Assignments for this new identity."
          print_warning "   Original Roles (for reference):" # Consider printing captured roles here if stored
          # Example: echo "${config_settings["systemAssignedRoles"]}" | jq -c '.[] | {role: .roleDefinitionName, scope: .scope}'
      fi
      if [[ -n "${config_settings["userAssignedIdentities"]}" ]]; then
          print_warning " - User-Assigned Identities were associated: ${config_settings["userAssignedIdentities"]}"
          print_warning "   These identities were re-associated with '$dest_function_app_name'."
          print_warning "   Verify that their existing Azure Role Assignments grant the required access."
      fi
      read -p "Press [Enter] once you have manually configured/verified Role Assignments..."
  else
      print_info "Skipping Identity Role Assignment configuration (Managed Identity was not used on source)."
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
  
  subsection_header "5.4 Resource cleanup (optional)..."
  
  # Ask if the user wants to delete the original app
  read -p "Would you like to delete the original function app '$function_app_name'? WARNING: This cannot be undone. (y/n): " delete_original
  
  if [[ $delete_original == "y" ]]; then
    # Double-check with the user
    read -p "Are you ABSOLUTELY SURE you want to delete '$function_app_name'? This is irreversible. Type 'yes' to confirm: " final_confirm
    
    if [[ $final_confirm == "yes" ]]; then
      echo "Deleting the original function app '$function_app_name' in resource group '$resource_group'..."
      az functionapp delete --name "$function_app_name" --resource-group "$resource_group"
      
      if [ $? -ne 0 ]; then
        error_message "Failed to delete the original function app."
      else
        success_message "Original function app deleted successfully."
      fi
    else
      echo "Deletion cancelled."
    fi
  else
    echo "Original function app '$function_app_name' preserved."
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