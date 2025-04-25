\
<#
.SYNOPSIS
Azure Functions Migration: Linux Consumption to Flex Consumption Guide

.DESCRIPTION
This script guides you through the process of migrating Azure Function Apps 
from Linux Consumption to Flex Consumption.

.NOTES
Version: 1.0
Date: April 25, 2025
Author: GitHub Copilot
Requires: Azure CLI (az), Az.ResourceGraph module (for faster initial query)
#>

#Requires -Modules Az.Accounts, Az.Functions, Az.Resources, Az.Storage, Az.ResourceGraph # Add modules used

#region Global Variables and Settings
$global:scriptVersion = "1.0 (April 2025)"
$global:migrationDir = ""
$global:functionAppName = ""
$global:resourceGroupName = ""
$global:location = ""
$global:runtimeStack = ""
$global:runtimeName = ""
$global:runtimeVersion = ""
$global:newFunctionAppName = ""
$global:storageAccountName = ""
$global:storageAccountId = ""
$global:principalId = ""
$global:appUrl = ""

# Configuration settings captured from source app
$global:configSettings = @{
    runFromPackage = $null
    http20Enabled = $null
    httpsOnly = $null
    minTlsVersion = $null
    clientCertEnabled = $null
    clientCertMode = $null
    systemAssignedIdentityPrincipalId = $null
    userAssignedIdentities = $null
    basicPublishingCredentialsPolicies = $null
    maximumInstanceCount = $null
    storageMounts = $null
    corsSettings = $null
    accessRestrictions = $null
    scmAccessRestrictions = $null
    hostKeys = $null
    functionKeys = $null
}

# Text formatting (using Write-Host for simplicity in cross-platform scripts)
$global:BOLD = "" # PowerShell console handles bold differently, often default
$global:GREEN = "Green"
$global:BLUE = "Blue"
$global:YELLOW = "Yellow"
$global:RED = "Red"
$global:CYAN = "Cyan"
$global:NC = "Gray" # Reset color

#endregion

#region Helper Functions

function Write-SectionHeader {
    param([string]$Message)
    Write-Host "`n$($global:BOLD)$Message" -ForegroundColor $global:BLUE
    Write-Host "$($global:BOLD)==================================================" -ForegroundColor $global:BLUE
}

function Write-SubsectionHeader {
    param([string]$Message)
    Write-Host "`n$($global:BOLD)$Message" -ForegroundColor $global:CYAN
    Write-Host "$($global:BOLD)--------------------------------------------------" -ForegroundColor $global:CYAN
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor $global:GREEN
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor $global:YELLOW
}

function Write-Error {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor $global:RED
}

function Write-Info {
    param([string]$Message)
    Write-Host "  $Message" -ForegroundColor $global:NC
}

function Write-ProgressMsg {
    param([string]$Message)
    Write-Host "... $Message" -ForegroundColor $global:NC
}

function Pause-Script {
    param([string]$Message = "Press [Enter] to continue...")
    Read-Host -Prompt $Message
}

function Confirm-Action {
    param(
        [string]$Prompt,
        [string]$Default = 'n'
    )
    $validResponses = @('y', 'n')
    $response = ''
    while ($validResponses -notcontains $response) {
        $response = Read-Host -Prompt "$Prompt (y/n) [$Default]"
        if ([string]::IsNullOrWhiteSpace($response)) {
            $response = $Default
        }
    }
    return $response -eq 'y'
}

#endregion

#region Prerequisite Checks

function Check-Prerequisites {
    Write-SectionHeader "STEP 0: CHECKING PREREQUISITES"

    # Check if Azure CLI is installed
    Write-ProgressMsg "Checking for Azure CLI..."
    $azPath = Get-Command az -ErrorAction SilentlyContinue
    if (-not $azPath) {
        Write-Error "Azure CLI (az) is not installed or not in PATH."
        Write-Host "Please install Azure CLI first: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        exit 1
    }
    Write-Success "Azure CLI is installed."

    # Check Azure CLI version
    Write-ProgressMsg "Checking Azure CLI version..."
    try {
        $azVersionOutput = az version --output json | ConvertFrom-Json
        $azCliVersion = $azVersionOutput.'azure-cli'
        Write-Info "Azure CLI version: $azCliVersion"
        if ([version]$azCliVersion -lt [version]'2.71.0') {
            Write-Warning "Azure CLI version $azCliVersion is older than the recommended version (2.71.0+)."
            if (-not (Confirm-Action -Prompt "Would you like to continue anyway?")) {
                Write-Host "Please update Azure CLI and try again. Run: az upgrade"
                exit 1
            }
        } else {
            Write-Success "Azure CLI version is sufficient."
        }
    } catch {
        Write-Warning "Could not determine Azure CLI version. $_"
        if (-not (Confirm-Action -Prompt "Would you like to continue anyway?")) {
            exit 1
        }
    }

    # Check if user is logged in
    Write-ProgressMsg "Checking Azure login status..."
    $accountInfo = az account show --output json --only-show-errors | ConvertFrom-Json -ErrorAction SilentlyContinue
    if (-not $accountInfo) {
        Write-Warning "You are not logged in to Azure CLI."
        Write-Host "Please log in to Azure:"
        az login
        $accountInfo = az account show --output json | ConvertFrom-Json
        if (-not $accountInfo) {
            Write-Error "Login failed or was cancelled."
            exit 1
        }
    }
    Write-Success "You are logged in to Azure CLI."
    Write-Info "Using subscription: $($accountInfo.name) ($($accountInfo.id))"


    # Check for required Az modules (optional, as we primarily use az cli)
    # Check-AzModule -Name "ResourceGraph" -Reason "Required for finding Linux Consumption apps efficiently."
    # Check-AzModule -Name "Functions" -Reason "May be used for specific Function App operations."
    # Check-AzModule -Name "Resources" -Reason "General resource management."
    # Check-AzModule -Name "Storage" -Reason "Storage account operations."

    Write-Success "Prerequisites check completed."
    Pause-Script
}

# Helper to check for Az modules (can be expanded)
function Check-AzModule {
    param(
        [string]$Name,
        [string]$Reason
    )
    Write-ProgressMsg "Checking for Az module: $Name..."
    if (-not (Get-Module -Name $Name -ListAvailable)) {
        Write-Warning "Az module '$Name' is not installed."
        Write-Info "Reason needed: $Reason"
        # Optionally offer to install: Install-Module -Name $Name -Scope CurrentUser -Repository PSGallery -Force
        Write-Warning "Script primarily uses Azure CLI, but this module might be needed for specific edge cases."
    } else {
        Write-Success "Az module '$Name' is available."
    }
}

#endregion

#region Step 1: Assessment

function Select-SourceFunctionApp {
    Write-SectionHeader "STEP 1: ASSESSMENT - Identify Function App"
    Write-Info "Searching for function apps running on Linux Consumption in your current subscription..."

    $subscriptionId = (az account show --query id --output tsv)
    Write-Info "Using subscription ID: $subscriptionId"

    # Query using Azure CLI and Resource Graph extension
    Write-ProgressMsg "Querying Azure Resource Graph for Linux Consumption apps..."
    $query = "resources | where subscriptionId == '$subscriptionId' | where type == 'microsoft.web/sites' | where kind contains 'functionapp' and kind contains 'linux' | where properties.sku == 'Dynamic' | project name, location, resourceGroup, stack=properties.siteProperties.properties.linuxFxVersion"
    $apps = az graph query --graph-query $query --output json | ConvertFrom-Json
    
    if ($apps.count -eq 0) {
        Write-Warning "No Linux Consumption function apps found in subscription '$subscriptionId'."
        Write-Host "Ensure you are in the correct subscription (use 'az account set --subscription ...')."
        exit 1
    }

    Write-Success "Found $($apps.count) Linux Consumption function app(s):"
    $apps | Format-Table -Property name, resourceGroup, location, stack

    # Ask user to select an app
    $selectedApp = $null
    while (-not $selectedApp) {
        $appNameInput = Read-Host -Prompt "Enter the name of the function app to migrate"
        $rgNameInput = Read-Host -Prompt "Enter the resource group of '$appNameInput'"

        # Verify selection
        $selectedApp = $apps | Where-Object { $_.name -eq $appNameInput -and $_.resourceGroup -eq $rgNameInput }
        if (-not $selectedApp) {
            Write-Error "Function app '$appNameInput' in resource group '$rgNameInput' not found in the list above or does not match criteria. Please try again."
        } elseif ($selectedApp -is [array]) {
             Write-Error "Multiple matches found for '$appNameInput' in '$rgNameInput'. This shouldn't happen. Please check the Azure portal."
             $selectedApp = $null # Force re-entry
        }
    }

    $global:functionAppName = $selectedApp.name
    $global:resourceGroupName = $selectedApp.resourceGroup
    $global:location = $selectedApp.location
    $global:runtimeStack = $selectedApp.stack

    Write-Success "Selected Function App:"
    Write-Info "  Name: $($global:functionAppName)"
    Write-Info "  Resource Group: $($global:resourceGroupName)"
    Write-Info "  Location: $($global:location)"
    Write-Info "  Runtime Stack: $($global:runtimeStack)"

    # Extract runtime name and version
    $stackParts = $global:runtimeStack -split '\|'
    if ($stackParts.Length -ge 2) {
        $global:runtimeName = $stackParts[0].ToLower()
        $global:runtimeVersion = $stackParts[1]
    } else {
        Write-Warning "Could not reliably parse runtime name and version from '$($global:runtimeStack)'."
        # Attempt basic split if no pipe
        $global:runtimeName = $global:runtimeStack.ToLower() -replace ':.*',''
        $global:runtimeVersion = $global:runtimeStack -replace '.*:',''
        Write-Warning "Guessed Runtime: $($global:runtimeName), Version: $($global:runtimeVersion). Please verify."
    }

    # Perform compatibility checks
    Verify-RegionCompatibility -Location $global:location
    Verify-RuntimeCompatibility -RuntimeName $global:runtimeName -RuntimeVersion $global:runtimeVersion -Location $global:location
    Verify-DeploymentSlots -FunctionAppName $global:functionAppName -ResourceGroupName $global:resourceGroupName
    Verify-Certificates -FunctionAppName $global:functionAppName -ResourceGroupName $global:resourceGroupName
    Verify-BlobTriggers -FunctionAppName $global:functionAppName -ResourceGroupName $global:resourceGroupName

    Write-Success "Assessment checks completed."
    Pause-Script
}

function Verify-RegionCompatibility {
    param(
        [string]$Location
    )
    Write-SubsectionHeader "1.1 Verifying Region Compatibility"
    Write-ProgressMsg "Checking if Flex Consumption is available in '$Location'..."

    try {
        $flexRegions = az functionapp list-flexconsumption-locations --query "[].name" --output json | ConvertFrom-Json
        if ($flexRegions -contains $Location) {
            Write-Success "Region '$Location' supports Flex Consumption."
        } else {
            Write-Warning "Flex Consumption might not be available in '$Location'."
            Write-Host "Available regions:"
            az functionapp list-flexconsumption-locations --query "sort_by(@, &name)[].{Region:name}" --output table

            if (Confirm-Action -Prompt "Continue migration by choosing a different target region?") {
                 $availableRegionsTable = az functionapp list-flexconsumption-locations --query "sort_by(@, &name)[].{Region:name}" --output table
                 Write-Host $availableRegionsTable
                 $newLocationInput = ""
                 while (-not ($flexRegions -contains $newLocationInput)) {
                    $newLocationInput = Read-Host -Prompt "Enter a new target region from the list above"
                    if (-not ($flexRegions -contains $newLocationInput)) {
                        Write-Error "'$newLocationInput' is not a valid Flex Consumption region from the list."
                    }
                 }
                 $global:location = $newLocationInput # Update global location
                 Write-Success "Targeting Flex Consumption in '$($global:location)' instead."
            } else {
                Write-Error "Migration cannot proceed without a supported region."
                exit 1
            }
        }
    } catch {
        Write-Error "Failed to retrieve Flex Consumption regions. $_"
        Write-Warning "Cannot verify region compatibility automatically."
        if (-not (Confirm-Action -Prompt "Continue anyway?")) { exit 1 }
    }
}

function Verify-RuntimeCompatibility {
    param(
        [string]$RuntimeName,
        [string]$RuntimeVersion,
        [string]$Location
    )
    Write-SubsectionHeader "1.2 Verifying Runtime Compatibility"
    Write-Info "Runtime: $RuntimeName, Version: $RuntimeVersion"

    # Check runtime name support
    switch ($RuntimeName) {
        "dotnet" {
            Write-Error "The 'dotnet' (in-process) runtime is NOT supported in Flex Consumption."
            Write-Warning "You MUST migrate your app code to the '.NET Isolated' model first."
            Write-Host "Guide: https://learn.microsoft.com/en-us/azure/azure-functions/dotnet-isolated-process-guide"
            if (Confirm-Action -Prompt "Has your app code ALREADY been migrated to the .NET Isolated model?") {
                 $global:runtimeName = "dotnet-isolated" # Adjust global runtime name
                 Write-Success "Proceeding with migration assuming code uses the .NET Isolated model."
            } else {
                 Write-Error "Migration stopped. Please migrate your code to .NET Isolated first."
                 exit 1
            }
        }
        "custom" {
            Write-Error "The 'custom' runtime is NOT supported in Flex Consumption."
            Write-Warning "You must migrate your app to a supported runtime (e.g., container app)."
            exit 1
        }
        "dotnet-isolated" { Write-Success "'dotnet-isolated' runtime is supported." }
        "node" { Write-Success "'node' runtime is supported." }
        "python" { Write-Success "'python' runtime is supported." }
        "java" { Write-Success "'java' runtime is supported." }
        "powershell" { Write-Success "'powershell' runtime is supported." }
        default {
            Write-Warning "Unknown runtime '$RuntimeName'. Compatibility cannot be verified."
            if (-not (Confirm-Action -Prompt "Continue anyway?")) { exit 1 }
        }
    }

    # Check runtime version support in the target region (if runtime is known supported)
    if ($RuntimeName -notin ("dotnet", "custom")) {
        Write-ProgressMsg "Checking if $RuntimeName version $RuntimeVersion is supported in $Location..."
        try {
            $supportedVersions = az functionapp list-flexconsumption-runtimes --location $Location --runtime $RuntimeName --query "[].version" --output json --only-show-errors | ConvertFrom-Json
            if (-not $supportedVersions) {
                 Write-Warning "Could not retrieve supported versions for $RuntimeName in $Location."
                 if (-not (Confirm-Action -Prompt "Continue anyway?")) { exit 1 }
            } elseif ($supportedVersions -contains $RuntimeVersion) {
                 Write-Success "$RuntimeName version $RuntimeVersion is supported in $Location."
            } else {
                 Write-Warning "$RuntimeName version $RuntimeVersion might NOT be supported in $Location."
                 Write-Info "Supported versions in $Location: $($supportedVersions -join ', ')"
                 Write-Warning "You may need to update your application code or select a different runtime version during creation."
                 if (-not (Confirm-Action -Prompt "Continue anyway?")) { exit 1 }
            }
        } catch {
             Write-Warning "Failed to check runtime version compatibility. $_"
             if (-not (Confirm-Action -Prompt "Continue anyway?")) { exit 1 }
        }
    }
}

function Verify-DeploymentSlots {
    param(
        [string]$FunctionAppName,
        [string]$ResourceGroupName
    )
    Write-SubsectionHeader "1.3 Verifying Deployment Slots Usage"
    Write-ProgressMsg "Checking for deployment slots..."
    try {
        $slots = az functionapp deployment slot list --name $FunctionAppName --resource-group $ResourceGroupName --query "[].name" --output json --only-show-errors | ConvertFrom-Json
        if ($slots.Count -gt 0) {
            Write-Warning "Deployment slots are NOT supported in Flex Consumption."
            Write-Info "Slots found: $($slots -join ', ')"
            Write-Warning "You must consolidate your deployment strategy (e.g., use environment variables, different apps, or deployment rings)."
            if (-not (Confirm-Action -Prompt "Continue migration without slots?")) {
                Write-Error "Migration stopped due to deployment slot usage."
                exit 1
            }
        } else {
            Write-Success "No deployment slots found. Compatible."
        }
    } catch {
        Write-Warning "Failed to check for deployment slots. $_"
        if (-not (Confirm-Action -Prompt "Continue anyway?")) { exit 1 }
    }
}

function Verify-Certificates {
    param(
        [string]$FunctionAppName,
        [string]$ResourceGroupName
    )
    Write-SubsectionHeader "1.4 Verifying Certificate Usage"
    Write-ProgressMsg "Checking for bound certificates..."
    try {
        # Check for explicitly bound certificates (custom domains)
        $certs = az webapp config ssl list --resource-group $ResourceGroupName --query "[?name=='$FunctionAppName'].thumbprint" --output json --only-show-errors | ConvertFrom-Json
        # Also check App Settings for WEBSITE_LOAD_CERTIFICATES
        $loadCertsSetting = az functionapp config appsettings list --name $FunctionAppName --resource-group $ResourceGroupName --query "[?name=='WEBSITE_LOAD_CERTIFICATES'].value" --output tsv --only-show-errors

        if ($certs.Count -gt 0 -or -not [string]::IsNullOrWhiteSpace($loadCertsSetting)) {
            Write-Warning "Certificates (bound for custom domains or loaded via WEBSITE_LOAD_CERTIFICATES) are NOT directly supported in Flex Consumption."
            if ($certs.Count -gt 0) { Write-Info "Bound certificate thumbprints found: $($certs -join ', ')" }
            if (-not [string]::IsNullOrWhiteSpace($loadCertsSetting)) { Write-Info "WEBSITE_LOAD_CERTIFICATES setting found: $loadCertsSetting" }
            Write-Warning "Consider using Azure Key Vault integration or other methods for managing secrets/certificates."
            if (-not (Confirm-Action -Prompt "Continue migration without direct certificate support?")) {
                Write-Error "Migration stopped due to certificate usage."
                exit 1
            }
        } else {
            Write-Success "No bound certificates or WEBSITE_LOAD_CERTIFICATES setting found. Compatible."
        }
    } catch {
        Write-Warning "Failed to check for certificates. $_"
        if (-not (Confirm-Action -Prompt "Continue anyway?")) { exit 1 }
    }
}

function Verify-BlobTriggers {
    param(
        [string]$FunctionAppName,
        [string]$ResourceGroupName
    )
    Write-SubsectionHeader "1.5 Verifying Blob Trigger Compatibility"
    Write-ProgressMsg "Checking for non-EventGrid blob triggers..."
    $incompatibleTriggerFound = $false
    try {
        $functions = az functionapp function list --name $FunctionAppName --resource-group $ResourceGroupName --query "[].name" --output json --only-show-errors | ConvertFrom-Json
        if (-not $functions) {
            Write-Warning "Could not retrieve functions list or no functions found."
            # Don't exit, allow user to continue if they know it's okay
        } else {
            foreach ($funcName in $functions) {
                $bindings = az functionapp function show --name $FunctionAppName --resource-group $ResourceGroupName --function-name $funcName --query "config.bindings" --output json --only-show-errors | ConvertFrom-Json
                if ($bindings) {
                    $blobTrigger = $bindings | Where-Object { $_.type -eq 'blobTrigger' -and ($_.source -eq $null -or $_.source -ne 'EventGrid') }
                    if ($blobTrigger) {
                        Write-Warning "Function '$funcName' uses a LogsAndContainerScan blob trigger (not EventGrid-based)."
                        $incompatibleTriggerFound = $true
                    }
                }
            }
        }

        if ($incompatibleTriggerFound) {
            Write-Error "Incompatible blob triggers found. These use polling (LogsAndContainerScan) which is NOT supported in Flex Consumption."
            Write-Warning "You MUST update these triggers to use the Event Grid source."
            Write-Host "Guide: https://learn.microsoft.com/en-us/azure/azure-functions/functions-event-grid-blob-trigger"
            if (-not (Confirm-Action -Prompt "Continue migration (assuming triggers will be updated)?")) {
                Write-Error "Migration stopped due to incompatible blob triggers."
                exit 1
            }
        } else {
            Write-Success "No incompatible (LogsAndContainerScan) blob triggers found. Compatible."
        }
    } catch {
        Write-Warning "Failed to check blob triggers. $_"
        if (-not (Confirm-Action -Prompt "Continue anyway?")) { exit 1 }
    }
}

#endregion

#region Step 2: Pre-Migration

function Export-SourceConfiguration {
    Write-SectionHeader "STEP 2: PRE-MIGRATION - Export Configuration"
    Write-Info "Exporting configuration from source app '$($global:functionAppName)'..."

    $global:migrationDir = "flex_migration_$($global:functionAppName)_$(Get-Date -Format 'yyyyMMddHHmmss')"
    try {
        New-Item -ItemType Directory -Path $global:migrationDir -ErrorAction Stop | Out-Null
        Write-Success "Created migration directory: $global:migrationDir"
    } catch {
        Write-Error "Failed to create migration directory '$global:migrationDir'. $_"
        exit 1
    }

    # --- App Settings ---
    Write-SubsectionHeader "2.1 Exporting App Settings..."
    try {
        $appSettingsJson = az functionapp config appsettings list --name $global:functionAppName --resource-group $global:resourceGroupName --output json --only-show-errors
        if ($LASTEXITCODE -ne 0) { throw "az cli failed" }
        $appSettingsJson | Set-Content -Path (Join-Path $global:migrationDir "app_settings.json")
        Write-Success "App settings saved to app_settings.json"

        $appSettings = $appSettingsJson | ConvertFrom-Json
        $global:configSettings.runFromPackage = ($appSettings | Where-Object { $_.name -eq 'WEBSITE_RUN_FROM_PACKAGE' }).value
        if ($global:configSettings.runFromPackage) {
            Write-Info "Source app runs from package: $($global:configSettings.runFromPackage)"
            Write-Warning "Ensure you have access to this package (URL or local file) for deployment later."
        } else {
            Write-Warning "Source app does not use WEBSITE_RUN_FROM_PACKAGE. Ensure you have the application code ready for deployment."
        }
    } catch {
        Write-Error "Failed to export app settings. $_"
        # Decide whether to exit or continue
        if (-not (Confirm-Action -Prompt "Continue without exported app settings?")) { exit 1 }
    }

    # --- General Site Configuration ---
    Write-SubsectionHeader "2.2 Exporting General Configuration..."
    try {
        $siteConfigJson = az functionapp config show --name $global:functionAppName --resource-group $global:resourceGroupName --output json --only-show-errors
         if ($LASTEXITCODE -ne 0) { throw "az cli failed" }
        $siteConfigJson | Set-Content -Path (Join-Path $global:migrationDir "site_config.json")
        Write-Success "General site config saved to site_config.json"

        $siteConfig = $siteConfigJson | ConvertFrom-Json
        $global:configSettings.http20Enabled = $siteConfig.http20Enabled
        $global:configSettings.minTlsVersion = $siteConfig.minTlsVersion
        $global:configSettings.clientCertEnabled = $siteConfig.clientCertEnabled
        $global:configSettings.clientCertMode = $siteConfig.clientCertMode
        # Get httpsOnly separately as it's not in 'config show'
        $global:configSettings.httpsOnly = az functionapp show --name $global:functionAppName --resource-group $global:resourceGroupName --query "httpsOnly" --output tsv --only-show-errors
        if ($LASTEXITCODE -ne 0) { $global:configSettings.httpsOnly = $null; Write-Warning "Could not get HttpsOnly setting." }


        Write-Info "Key Settings Found:"
        Write-Info "  Http20Enabled: $($global:configSettings.http20Enabled)"
        Write-Info "  HttpsOnly: $($global:configSettings.httpsOnly)"
        Write-Info "  MinTlsVersion: $($global:configSettings.minTlsVersion)"
        Write-Info "  ClientCertEnabled: $($global:configSettings.clientCertEnabled)"
        Write-Info "  ClientCertMode: $($global:configSettings.clientCertMode)"

    } catch {
        Write-Error "Failed to export general site configuration. $_"
        if (-not (Confirm-Action -Prompt "Continue without exported site config?")) { exit 1 }
    }

     # --- SCM Basic Auth Publishing Credentials ---
    Write-SubsectionHeader "2.3 Exporting SCM Basic Auth Policy..."
    try {
        $scmPolicy = az resource show --resource-group $global:resourceGroupName --name scm --namespace Microsoft.Web --resource-type basicPublishingCredentialsPolicies --parent sites/$global:functionAppName --output json --only-show-errors | ConvertFrom-Json
        if ($LASTEXITCODE -ne 0) { throw "az cli failed or policy not set" }
        $global:configSettings.basicPublishingCredentialsPolicies = $scmPolicy.properties.allow
        $scmPolicy | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $global:migrationDir "scm_basic_auth_policy.json")
        Write-Success "SCM Basic Auth policy saved to scm_basic_auth_policy.json (Allow: $($global:configSettings.basicPublishingCredentialsPolicies))"
    } catch {
        Write-Warning "Failed to export SCM Basic Auth policy (likely not configured on source). $_"
        $global:configSettings.basicPublishingCredentialsPolicies = $true # Default is true if not set
        Write-Info "Assuming default SCM Basic Auth policy (Allowed)."
    }

    # --- Scale and Concurrency (Max Scale Out) ---
    Write-SubsectionHeader "2.4 Exporting Max Scale Out Limit..."
    try {
        # This setting is often in app settings for Consumption, but check site config too
        $maxScaleOutSetting = ($appSettings | Where-Object { $_.name -eq 'WEBSITE_MAX_DYNAMIC_APPLICATION_SCALE_OUT' }).value
        if ($maxScaleOutSetting) {
             $global:configSettings.maximumInstanceCount = $maxScaleOutSetting
             Write-Success "Found WEBSITE_MAX_DYNAMIC_APPLICATION_SCALE_OUT: $($global:configSettings.maximumInstanceCount)"
             @{ maximumInstanceCount = $global:configSettings.maximumInstanceCount } | ConvertTo-Json | Set-Content -Path (Join-Path $global:migrationDir "scale_settings.json")
        } else {
             Write-Info "No WEBSITE_MAX_DYNAMIC_APPLICATION_SCALE_OUT setting found. Flex default will apply unless overridden."
             $global:configSettings.maximumInstanceCount = $null
        }
    } catch {
         Write-Warning "Failed to check for scale out setting. $_"
         $global:configSettings.maximumInstanceCount = $null
    }

    # --- Storage Mounts ---
    Write-SubsectionHeader "2.5 Exporting Storage Mounts..."
    try {
        $storageMountsJson = az webapp config storage-account list --name $global:functionAppName --resource-group $global:resourceGroupName --output json --only-show-errors
        if ($LASTEXITCODE -ne 0) { throw "az cli failed" }
        $storageMounts = $storageMountsJson | ConvertFrom-Json
        if ($storageMounts.Count -gt 0) {
            $storageMountsJson | Set-Content -Path (Join-Path $global:migrationDir "storage_mounts.json")
            $global:configSettings.storageMounts = $storageMounts # Store the objects
            Write-Success "Storage mounts saved to storage_mounts.json ($($storageMounts.Count) found)"
        } else {
            Write-Info "No storage mounts configured on source app."
            $global:configSettings.storageMounts = $null
        }
    } catch {
        Write-Error "Failed to export storage mounts. $_"
        $global:configSettings.storageMounts = $null
    }

    # --- Custom Domains ---
    Write-SubsectionHeader "2.6 Exporting Custom Domains..."
    try {
        $domainsJson = az functionapp config hostname list --webapp-name $global:functionAppName --resource-group $global:resourceGroupName --output json --only-show-errors
        if ($LASTEXITCODE -ne 0) { throw "az cli failed" }
        $domainsJson | Set-Content -Path (Join-Path $global:migrationDir "custom_domains.json")
        $domains = $domainsJson | ConvertFrom-Json
        $customDomainCount = ($domains | Where-Object { $_.name -notlike "*.azurewebsites.net" }).Count
        if ($customDomainCount -gt 0) {
            Write-Warning "Found $customDomainCount custom domain(s). These require manual reconfiguration and DNS updates post-migration."
        } else {
            Write-Success "No custom domains found."
        }
    } catch {
        Write-Warning "Failed to export custom domains. $_"
    }

    # --- Managed Identities ---
    Write-SubsectionHeader "2.7 Exporting Managed Identity Configuration..."
    try {
        $identityJson = az functionapp identity show --name $global:functionAppName --resource-group $global:resourceGroupName --output json --only-show-errors
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($identityJson) -or $identityJson -eq '{}') {
             Write-Info "No Managed Identity configured on source app."
             $global:configSettings.systemAssignedIdentityPrincipalId = $null
             $global:configSettings.userAssignedIdentities = $null
             '{}' | Set-Content -Path (Join-Path $global:migrationDir "identity_config.json") # Save empty config
        } else {
            $identityJson | Set-Content -Path (Join-Path $global:migrationDir "identity_config.json")
            $identity = $identityJson | ConvertFrom-Json
            $global:configSettings.systemAssignedIdentityPrincipalId = $identity.principalId
            $global:configSettings.userAssignedIdentities = $identity.userAssignedIdentities.PSObject.Properties | ForEach-Object { $_.Name } # Get keys/resource IDs

            if ($global:configSettings.systemAssignedIdentityPrincipalId) {
                Write-Warning "System-Assigned Identity is ENABLED (Principal ID: $($global:configSettings.systemAssignedIdentityPrincipalId))."
                Write-Warning "Role assignments for this identity MUST be manually recreated for the new app's identity."
                # Future enhancement: Try to list role assignments for $identity.principalId
            }
            if ($global:configSettings.userAssignedIdentities) {
                Write-Warning "User-Assigned Identities are associated: $($global:configSettings.userAssignedIdentities -join ', ')"
                Write-Warning "These identities need to be associated with the new app, and their role assignments verified."
            }
             Write-Success "Managed Identity config saved to identity_config.json"
        }
    } catch {
        Write-Warning "Failed to export Managed Identity configuration. $_"
        $global:configSettings.systemAssignedIdentityPrincipalId = $null
        $global:configSettings.userAssignedIdentities = $null
    }

    # --- Built-in Auth (Easy Auth) ---
    Write-SubsectionHeader "2.8 Exporting Built-in Authentication..."
    try {
        $authSettingsJson = az webapp auth show --name $global:functionAppName --resource-group $global:resourceGroupName --output json --only-show-errors
        if ($LASTEXITCODE -ne 0) { throw "az cli failed" }
        $authSettings = $authSettingsJson | ConvertFrom-Json
        if ($authSettings.enabled) {
             $authSettingsJson | Set-Content -Path (Join-Path $global:migrationDir "auth_settings.json")
             Write-Warning "Built-in Authentication (Easy Auth) is ENABLED."
             Write-Warning "This needs to be manually reconfigured on the new Flex Consumption app after creation."
             Write-Info "Auth settings saved to auth_settings.json for reference."
        } else {
             Write-Info "Built-in Authentication is not enabled."
             '{"enabled": false}' | Set-Content -Path (Join-Path $global:migrationDir "auth_settings.json")
        }
    } catch {
         Write-Warning "Failed to check Built-in Authentication settings. $_"
         Write-Warning "Please manually verify and reconfigure if needed on the new app."
    }

    # --- CORS ---
    Write-SubsectionHeader "2.9 Exporting CORS Settings..."
    try {
        # CORS settings are part of site config, but let's save separately for clarity
        $corsOrigins = $siteConfig.cors.allowedOrigins
        if ($corsOrigins -and $corsOrigins.Count -gt 0) {
            @{ allowedOrigins = $corsOrigins } | ConvertTo-Json | Set-Content -Path (Join-Path $global:migrationDir "cors_settings.json")
            $global:configSettings.corsSettings = $corsOrigins
            Write-Success "CORS settings saved to cors_settings.json ($($corsOrigins.Count) origins)"
        } else {
            Write-Info "No CORS origins configured."
            $global:configSettings.corsSettings = $null
            '{}' | Set-Content -Path (Join-Path $global:migrationDir "cors_settings.json")
        }
    } catch {
        Write-Warning "Failed to extract CORS settings from site config. $_"
        $global:configSettings.corsSettings = $null
    }

    # --- Network Access Restrictions ---
    Write-SubsectionHeader "2.10 Exporting Network Access Restrictions..."
    try {
        # Main site rules
        $accessJson = az functionapp config access-restriction show --name $global:functionAppName --resource-group $global:resourceGroupName --output json --only-show-errors
        if ($LASTEXITCODE -ne 0) { throw "az cli failed" }
        $accessJson | Set-Content -Path (Join-Path $global:migrationDir "access_restrictions.json")
        $accessSettings = $accessJson | ConvertFrom-Json
        $global:configSettings.accessRestrictions = $accessSettings # Store full object

        # SCM site rules
        $scmAccessJson = az functionapp config access-restriction show --name $global:functionAppName --resource-group $global:resourceGroupName --scm-site --output json --only-show-errors
        if ($LASTEXITCODE -ne 0) { throw "az cli failed" }
        $scmAccessJson | Set-Content -Path (Join-Path $global:migrationDir "scm_access_restrictions.json")
        $scmAccessSettings = $scmAccessJson | ConvertFrom-Json
        $global:configSettings.scmAccessRestrictions = $scmAccessSettings # Store full object

        $mainRuleCount = $accessSettings.properties.ipSecurityRestrictions.Count + $accessSettings.properties.scmIpSecurityRestrictions.Count # Approx count
        $scmRuleCount = $scmAccessSettings.properties.ipSecurityRestrictions.Count + $scmAccessSettings.properties.scmIpSecurityRestrictions.Count # Approx count

        if ($mainRuleCount -gt 0 -or $scmRuleCount -gt 0) {
             Write-Warning "Network Access Restrictions found (Main: $mainRuleCount, SCM: $scmRuleCount)."
             Write-Warning "These need to be manually reviewed and likely re-applied to the new Flex app."
             Write-Info "Settings saved to access_restrictions.json and scm_access_restrictions.json for reference."
        } else {
             Write-Success "No custom Network Access Restrictions found."
        }
    } catch {
        Write-Warning "Failed to export Network Access Restrictions. $_"
        Write-Warning "Please manually verify and reconfigure if needed on the new app."
        $global:configSettings.accessRestrictions = $null
        $global:configSettings.scmAccessRestrictions = $null
    }

    # --- Function Keys ---
    Write-SubsectionHeader "2.11 Exporting Function Keys..."
    try {
        # Host keys (_master, default)
        $hostKeysJson = az functionapp keys list --name $global:functionAppName --resource-group $global:resourceGroupName --output json --only-show-errors
        if ($LASTEXITCODE -ne 0) { throw "az cli failed" }
        $hostKeysJson | Set-Content -Path (Join-Path $global:migrationDir "host_keys.json")
        $global:configSettings.hostKeys = $hostKeysJson | ConvertFrom-Json
        Write-Success "Host keys saved to host_keys.json"

        # Function-specific keys
        $functionKeys = @{}
        $functions = az functionapp function list --name $global:functionAppName --resource-group $global:resourceGroupName --query "[].name" --output json --only-show-errors | ConvertFrom-Json
        if ($functions) {
            foreach ($funcName in $functions) {
                $keysJson = az functionapp function keys list --name $global:functionAppName --resource-group $global:resourceGroupName --function-name $funcName --output json --only-show-errors
                 if ($LASTEXITCODE -eq 0) {
                    $keys = $keysJson | ConvertFrom-Json
                    if ($keys.PSObject.Properties.Name -contains 'default') { # Check if default key exists
                         $functionKeys[$funcName] = $keys.default
                    }
                 } else {
                     Write-Warning "Could not list keys for function '$funcName'."
                 }
            }
        }
        if ($functionKeys.Count -gt 0) {
            $functionKeys | ConvertTo-Json -Depth 3 | Set-Content -Path (Join-Path $global:migrationDir "function_keys.json")
            $global:configSettings.functionKeys = $functionKeys # Store hashtable
            Write-Warning "Function-specific keys found and saved to function_keys.json."
            Write-Warning "These keys will NOT be automatically recreated. Recreate manually if needed."
        } else {
            Write-Info "No function-specific keys found or could be listed."
            $global:configSettings.functionKeys = $null
        }

    } catch {
        Write-Warning "Failed to export some or all keys. $_"
        Write-Warning "Keys may need to be manually recreated on the new app."
        $global:configSettings.hostKeys = $null
        $global:configSettings.functionKeys = $null
    }

    Write-Success "Pre-migration export completed. Configuration data saved in '$global:migrationDir'."
    Pause-Script
}

#endregion

#region Step 3: Migration

function Create-FlexConsumptionApp {
    Write-SectionHeader "STEP 3: MIGRATION - Create Flex Consumption App"

    # Get new app name
    $appNameAvailable = $false
    while (-not $appNameAvailable) {
        $global:newFunctionAppName = Read-Host -Prompt "Enter a globally unique name for the new Flex Consumption function app"
        if ([string]::IsNullOrWhiteSpace($global:newFunctionAppName)) { continue }
        Write-ProgressMsg "Checking name availability for '$($global:newFunctionAppName)'..."
        try {
            $availability = az functionapp check-name-availability --name $global:newFunctionAppName --output json | ConvertFrom-Json
            if ($availability.nameAvailable) {
                Write-Success "Name '$($global:newFunctionAppName)' is available."
                $appNameAvailable = $true
            } else {
                Write-Error "Name '$($global:newFunctionAppName)' is not available. Reason: $($availability.reason)"
            }
        } catch {
            Write-Error "Failed to check name availability. $_"
            # Allow proceeding with caution
            if (-not (Confirm-Action -Prompt "Could not verify name availability. Continue with '$($global:newFunctionAppName)' anyway?")) {
                 # Loop again
            } else {
                 $appNameAvailable = $true # Assume available if user forces
            }
        }
    }

    # --- Create Storage Account ---
    Write-SubsectionHeader "3.1 Creating New Storage Account..."
    # Generate a unique name (lowercase alphanumeric, max 24 chars)
    $storageNameBase = $global:newFunctionAppName -replace '[^a-zA-Z0-9]', '' | Select-Object -First 20
    $storageSuffix = (Get-Random -Maximum 9999).ToString("0000")
    $global:storageAccountName = "st$($storageNameBase)$($storageSuffix)".ToLower()

    Write-Info "Attempting to create storage account '$($global:storageAccountName)' in '$($global:location)'..."
    try {
        # Create storage account
        az storage account create --name $global:storageAccountName --resource-group $global:resourceGroupName --location $global:location --sku Standard_LRS --allow-blob-public-access false --output none --only-show-errors
        if ($LASTEXITCODE -ne 0) { throw "az cli failed" }
        Write-Success "Storage account '$($global:storageAccountName)' created successfully."

        # Get storage account ID
        $global:storageAccountId = az storage account show --name $global:storageAccountName --resource-group $global:resourceGroupName --query id --output tsv --only-show-errors
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($global:storageAccountId)) {
            throw "Failed to get storage account ID."
        }
         Write-Info "Storage Account ID: $($global:storageAccountId)"

    } catch {
        Write-Error "Failed to create or get storage account '$($global:storageAccountName)'. $_"
        # Check if it already exists
        $existingStorage = az storage account show --name $global:storageAccountName --resource-group $global:resourceGroupName --output json --only-show-errors | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($existingStorage) {
            Write-Warning "Storage account '$($global:storageAccountName)' already exists. Attempting to use it."
            $global:storageAccountId = $existingStorage.id
            if ([string]::IsNullOrWhiteSpace($global:storageAccountId)) {
                 Write-Error "Could not get ID for existing storage account."
                 exit 1
            }
             Write-Info "Using existing Storage Account ID: $($global:storageAccountId)"
        } else {
            exit 1
        }
    }

    # --- Create Flex Consumption App ---
    Write-SubsectionHeader "3.2 Creating Flex Consumption App with Managed Identity..."
    Write-Info "Creating app '$($global:newFunctionAppName)' in '$($global:location)'..."
    Write-Info "Runtime: $($global:runtimeName), Version: $($global:runtimeVersion)"

    # Adjust runtime name if needed (e.g., dotnet -> dotnet-isolated was handled in assessment)
    if ($global:runtimeName -eq 'dotnet') {
        Write-Warning "Runtime was 'dotnet', assuming code is migrated and using 'dotnet-isolated' for creation."
        $createRuntimeName = 'dotnet-isolated'
    } else {
        $createRuntimeName = $global:runtimeName
    }

    try {
        az functionapp create --name $global:newFunctionAppName `
            --resource-group $global:resourceGroupName `
            --flexconsumption-location $global:location `
            --runtime $createRuntimeName `
            --runtime-version $global:runtimeVersion `
            --flex-consumption `
            --assign-identity "[system]" `
            --output none --only-show-errors
        if ($LASTEXITCODE -ne 0) { throw "az cli failed" }
        Write-Success "Flex Consumption function app '$($global:newFunctionAppName)' created successfully."
    } catch {
        Write-Error "Failed to create Flex Consumption function app '$($global:newFunctionAppName)'. $_"
        exit 1
    }

    # --- Get Managed Identity Principal ID ---
    Write-SubsectionHeader "3.2.1 Getting Managed Identity Principal ID..."
    try {
        $global:principalId = az functionapp identity show --name $global:newFunctionAppName --resource-group $global:resourceGroupName --query principalId --output tsv --only-show-errors
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($global:principalId) -or $global:principalId -eq 'null') {
            throw "az cli failed or principalId not found"
        }
        Write-Success "Retrieved Principal ID: $($global:principalId)"
    } catch {
        Write-Error "Failed to retrieve Principal ID for the new app's system-assigned identity. $_"
        Write-Warning "Manual role assignment will be required for AzureWebJobsStorage."
        $global:principalId = $null # Ensure it's null if failed
        Pause-Script "Press [Enter] to continue despite missing Principal ID..."
    }

    # --- Assign Storage Roles ---
    Write-SubsectionHeader "3.2.2 Assigning Storage Roles to Managed Identity..."
    if ($global:principalId) {
        Write-Info "Assigning required storage roles to identity $($global:principalId) on storage account $($global:storageAccountName)..."
        Write-Info "Waiting for identity propagation (15s)..."
        Start-Sleep -Seconds 15

        $rolesToAssign = @(
            @{ Name = "Storage Blob Data Owner"; Assigned = $false },
            @{ Name = "Storage Queue Data Contributor"; Assigned = $false },
            @{ Name = "Storage Table Data Contributor"; Assigned = $false }
        )
        $allRolesAssigned = $true

        foreach ($role in $rolesToAssign) {
            Write-ProgressMsg "  Assigning '$($role.Name)'..."
            try {
                az role assignment create --assignee $global:principalId --role $role.Name --scope $global:storageAccountId --output none --only-show-errors
                if ($LASTEXITCODE -ne 0) { throw "az cli failed" }
                Write-Success "    '$($role.Name)' role assigned."
                $role.Assigned = $true
            } catch {
                Write-Error "    Failed to assign '$($role.Name)' role. $_"
                $allRolesAssigned = $false
            }
        }

        if (-not $allRolesAssigned) {
            Write-Warning "One or more required storage roles could not be assigned automatically."
            Write-Warning "This is required for the function app to access '$($global:storageAccountName)' using Managed Identity."
            Write-Warning "Please assign the following roles manually in the Azure portal (Storage Account -> Access Control (IAM)):"
            $rolesToAssign | Where-Object { -not $_.Assigned } | ForEach-Object { Write-Warning "  - $($_.Name)" }
            Pause-Script "Press [Enter] to continue despite role assignment failure(s)..."
        } else {
            Write-Success "Required storage roles assigned successfully."
        }
    } else {
        Write-Warning "Skipping role assignment because Principal ID could not be retrieved."
        Write-Warning "Manual role assignment is required for AzureWebJobsStorage."
    }

    # --- Configure App Settings ---
    Write-SubsectionHeader "3.3 Configuring App Settings (using Managed Identity for Storage)..."
    $appSettingsFile = Join-Path $global:migrationDir "app_settings.json"
    if (Test-Path $appSettingsFile) {
        Write-Info "Processing settings from $appSettingsFile..."
        $sourceSettings = Get-Content -Path $appSettingsFile | ConvertFrom-Json

        # Filter settings
        $settingsToExclude = @(
            "azurewebjobsstorage", # Handled by identity
            "website_contentazurefileconnectionstring", # Not applicable
            "website_contentshare", # Not applicable
            "website_run_from_package", # Handled during deployment
            "functions_extension_version", # Set explicitly for identity
            "functions_worker_runtime", # Set during creation
            "functions_worker_runtime_version", # Set during creation
            "website_node_default_version", # Legacy
            "website_max_dynamic_application_scale_out", # Handled by scale config
            "applicationinsights_connection_string", # Keep if present? Or recommend new instance? For now, filter out.
            "applicationinsights_instrumentationkey", # Legacy
            # Add others if needed
            "website_use_placeholder_dotnetisolated",
            "website_mount_enabled",
            "enable_oryx_build",
            "functions_max_http_concurrency",
            "functions_worker_process_count",
            "functions_worker_dynamic_concurrency_enabled",
            "scm_do_build_during_deployment",
            "website_contentovervnet",
            "website_dns_server",
            "website_skip_contentshare_validation",
            "website_vnet_route_all"
        )

        $settingsToApply = @{}
        foreach ($setting in $sourceSettings) {
            $lowerName = $setting.name.ToLower()
            $isExcluded = $false
            foreach ($excludePattern in $settingsToExclude) {
                 # Use -like for wildcard matching if needed, simple startswith/equality here
                if ($lowerName -eq $excludePattern -or $lowerName.StartsWith($excludePattern)) {
                    $isExcluded = $true
                    break
                }
            }
            if (-not $isExcluded) {
                $settingsToApply[$setting.name] = $setting.value
            }
        }

        # Apply filtered settings
        if ($settingsToApply.Count -gt 0) {
            Write-ProgressMsg "Applying $($settingsToApply.Count) filtered app settings from source..."
            $settingsArray = $settingsToApply.GetEnumerator() | ForEach-Object { "$($_.Name)=$($_.Value)" }
            try {
                az functionapp config appsettings set --name $global:newFunctionAppName --resource-group $global:resourceGroupName --settings $settingsArray --output none --only-show-errors
                if ($LASTEXITCODE -ne 0) { throw "az cli failed" }
                Write-Success "Filtered app settings applied."
            } catch {
                Write-Warning "Failed to apply some filtered app settings. Review manually. $_"
            }
        } else {
            Write-Info "No compatible app settings found to transfer from source."
        }

        # Apply Identity-based Storage settings
        Write-ProgressMsg "Configuring AzureWebJobsStorage with Managed Identity..."
        $storageBlobUri = "https://$($global:storageAccountName).blob.core.windows.net"
        $storageQueueUri = "https://$($global:storageAccountName).queue.core.windows.net"
        $storageTableUri = "https://$($global:storageAccountName).table.core.windows.net"

        $identitySettingsArray = @(
            "AzureWebJobsStorage__blobServiceUri=$storageBlobUri",
            "AzureWebJobsStorage__queueServiceUri=$storageQueueUri",
            "AzureWebJobsStorage__tableServiceUri=$storageTableUri",
            "FUNCTIONS_EXTENSION_VERSION=~4" # Required for identity connections
        )
        try {
            az functionapp config appsettings set --name $global:newFunctionAppName --resource-group $global:resourceGroupName --settings $identitySettingsArray --output none --only-show-errors
            if ($LASTEXITCODE -ne 0) { throw "az cli failed" }
            Write-Success "AzureWebJobsStorage configured with Managed Identity."
        } catch {
            Write-Error "Failed to configure AzureWebJobsStorage with Managed Identity. $_"
            Write-Warning "The function app might not start correctly. Verify app settings and role assignments."
        }

    } else {
        Write-Warning "App settings file not found ($appSettingsFile). Skipping app settings configuration."
        Write-Warning "Manual app settings configuration is required, including AzureWebJobsStorage with Managed Identity."
    }

    # --- Apply General Configuration ---
    Write-SubsectionHeader "3.4 Applying General Configuration..."
    $siteConfigFile = Join-Path $global:migrationDir "site_config.json"
    if (Test-Path $siteConfigFile) {
        Write-Info "Applying general settings from site_config.json..."
        # Use $global:configSettings which were populated during export
        try {
            # Apply HTTP version
            if ($global:configSettings.http20Enabled -ne $null) {
                Write-ProgressMsg "  Applying Http20Enabled: $($global:configSettings.http20Enabled)..."
                az functionapp config set --name $global:newFunctionAppName --resource-group $global:resourceGroupName --http20-enabled $global:configSettings.http20Enabled --output none --only-show-errors
                if ($LASTEXITCODE -ne 0) { Write-Warning "    Failed to apply Http20Enabled." } else { Write-Success "    Http20Enabled applied."}
            }
            # Apply HTTPS Only
             if ($global:configSettings.httpsOnly -ne $null) {
                Write-ProgressMsg "  Applying HttpsOnly: $($global:configSettings.httpsOnly)..."
                az functionapp update --name $global:newFunctionAppName --resource-group $global:resourceGroupName --set httpsOnly=$global:configSettings.httpsOnly --output none --only-show-errors
                if ($LASTEXITCODE -ne 0) { Write-Warning "    Failed to apply HttpsOnly." } else { Write-Success "    HttpsOnly applied."}
            }
            # Apply Min TLS Version
            if ($global:configSettings.minTlsVersion -ne $null) {
                Write-ProgressMsg "  Applying MinTlsVersion: $($global:configSettings.minTlsVersion)..."
                az functionapp config set --name $global:newFunctionAppName --resource-group $global:resourceGroupName --min-tls-version $global:configSettings.minTlsVersion --output none --only-show-errors
                if ($LASTEXITCODE -ne 0) { Write-Warning "    Failed to apply MinTlsVersion." } else { Write-Success "    MinTlsVersion applied."}
            }
            # Apply Client Cert settings (Note: Client Certs not supported in Flex, but apply setting if true for consistency/awareness)
            if ($global:configSettings.clientCertEnabled -ne $null) {
                 Write-ProgressMsg "  Applying ClientCertEnabled: $($global:configSettings.clientCertEnabled)..."
                 az functionapp update --name $global:newFunctionAppName --resource-group $global:resourceGroupName --set clientCertEnabled=$global:configSettings.clientCertEnabled --output none --only-show-errors
                 if ($LASTEXITCODE -ne 0) { Write-Warning "    Failed to apply ClientCertEnabled." } else { Write-Success "    ClientCertEnabled applied (Note: Flex does not support client cert auth)."}
                 # Don't apply ClientCertMode as it's irrelevant if ClientCertEnabled doesn't work
            }
        } catch {
            Write-Warning "Failed to apply some general configuration settings. $_"
        }
    } else {
        Write-Warning "Site configuration file not found. Skipping general configuration."
    }

    # --- Apply SCM Basic Auth ---
    Write-SubsectionHeader "3.5 Applying SCM Basic Auth Policy..."
    if ($global:configSettings.basicPublishingCredentialsPolicies -ne $null) {
        Write-Info "Applying SCM Basic Auth Publishing Credentials policy (Allow: $($global:configSettings.basicPublishingCredentialsPolicies))..."
        try {
            # Ensure the resource type exists before updating (might take time after app creation)
            # Simple sleep for now, could poll
            Write-ProgressMsg "  Waiting briefly for scm resource..."
            Start-Sleep -Seconds 10
            az resource update --resource-group $global:resourceGroupName --name scm --namespace Microsoft.Web --resource-type basicPublishingCredentialsPolicies --parent sites/$global:newFunctionAppName --set properties.allow=$($global:configSettings.basicPublishingCredentialsPolicies.ToString().ToLower()) --output none --only-show-errors
            if ($LASTEXITCODE -ne 0) { throw "az cli failed" }
            Write-Success "SCM Basic Auth policy applied."
        } catch {
            Write-Warning "Failed to apply SCM Basic Auth Publishing Credentials setting. May need manual configuration. $_"
        }
    } else {
        Write-Info "SCM Basic Auth policy setting not captured from source. Assuming default (Allowed)."
    }

    # --- Apply Scale Settings ---
    Write-SubsectionHeader "3.6 Applying Scale and Concurrency Settings..."
    if ($global:configSettings.maximumInstanceCount -ne $null) {
        $maxScaleOut = $global:configSettings.maximumInstanceCount
        Write-Info "Applying Maximum Instance Count: $maxScaleOut..."
        # Note: Flex Consumption minimum instance count for billing is higher than Consumption's max.
        # The 'maximum-instance-count' parameter here controls the *upper* limit.
        # We apply the captured value, but user should be aware Flex scaling differs.
        Write-Warning "Note: Flex Consumption scaling behavior and billing differ from standard Consumption."
        try {
            az functionapp scale config set --name $global:newFunctionAppName --resource-group $global:resourceGroupName `
                --maximum-instance-count $maxScaleOut --output none --only-show-errors
             if ($LASTEXITCODE -ne 0) { throw "az cli failed" }
             Write-Success "Maximum Instance Count applied."
        } catch {
             Write-Warning "Failed to apply Maximum Instance Count setting. Review manually. $_"
        }
    } else {
        Write-Info "No custom Maximum Scale Out Limit captured from source. Using Flex Consumption defaults."
    }

    # --- Apply Storage Mounts ---
    Write-SubsectionHeader "3.7 Configuring Storage Mounts..."
    if ($global:configSettings.storageMounts) {
        Write-Info "Applying $($global:configSettings.storageMounts.Count) storage mount(s)..."
        foreach ($mount in $global:configSettings.storageMounts) {
            $mountName = $mount.name
            $mountType = $mount.type
            $accountName = $mount.accountName
            $shareName = $mount.shareName
            $accessKey = $mount.accessKey # Might be null
            $mountPath = $mount.mountPath

            Write-Info "  Applying mount: $mountName ($mountType) to $mountPath"
            $cmdArgs = @(
                "webapp", "config", "storage-account", "add",
                "--resource-group", $global:resourceGroupName,
                "--name", $global:newFunctionAppName,
                "--custom-id", $mountName,
                "--storage-type", $mountType,
                "--account-name", $accountName,
                "--share-name", $shareName,
                "--mount-path", $mountPath
            )
            if (-not [string]::IsNullOrWhiteSpace($accessKey) -and $accessKey -ne 'null') {
                $cmdArgs += @("--access-key", $accessKey)
            } else {
                # Flex Consumption *requires* identity for mounts if access key isn't provided.
                # Check if the target storage account is the SAME as the one created for the app.
                # If so, the app's identity *should* have roles. If not, it's complex.
                Write-Warning "    Access key for mount '$mountName' is missing."
                Write-Warning "    Flex Consumption requires using the app's Managed Identity for mounts without access keys."
                Write-Warning "    Ensure the identity '$($global:principalId)' has appropriate roles (e.g., Storage Blob Data Contributor) on storage account '$accountName'."
                # Attempting without access key - relies on identity being configured correctly.
                $cmdArgs += @("--mi-system-assigned") # Explicitly use system identity
            }

            try {
                az $cmdArgs --output none --only-show-errors
                if ($LASTEXITCODE -ne 0) { throw "az cli failed" }
                Write-Success "    Storage mount '$mountName' applied."
            } catch {
                Write-Error "    Failed to apply storage mount '$mountName'. Manual configuration required. $_"
            }
        }
    } else {
        Write-Info "No Storage Mounts were configured on the source app. Skipping."
    }

    # --- Apply CORS Settings ---
    Write-SubsectionHeader "3.8 Configuring CORS Settings..."
    if ($global:configSettings.corsSettings) {
        Write-Info "Applying $($global:configSettings.corsSettings.Count) CORS origin(s)..."
        $corsApplied = $false
        foreach ($origin in $global:configSettings.corsSettings) {
             if (-not [string]::IsNullOrWhiteSpace($origin) -and $origin -ne '*') { # '*' might be default, handle specific origins
                 Write-ProgressMsg "  Adding allowed origin: $origin"
                 try {
                    az functionapp cors add --name $global:newFunctionAppName --resource-group $global:resourceGroupName --allowed-origins $origin --output none --only-show-errors
                    if ($LASTEXITCODE -ne 0) { throw "az cli failed" }
                    $corsApplied = $true
                 } catch {
                     Write-Warning "    Failed to add CORS origin '$origin'. $_"
                 }
             } elseif ($origin -eq '*') {
                 Write-Warning "  Source CORS allowed all origins ('*'). Applying '*' to new app."
                 try {
                     az functionapp cors add --name $global:newFunctionAppName --resource-group $global:resourceGroupName --allowed-origins '*' --output none --only-show-errors
                     if ($LASTEXITCODE -ne 0) { throw "az cli failed" }
                     $corsApplied = $true
                 } catch {
                      Write-Warning "    Failed to add CORS origin '*'. $_"
                 }
             }
        }
        if ($corsApplied) { Write-Success "CORS settings applied." } else { Write-Info "No specific CORS origins to apply."}
    } else {
        Write-Info "No CORS settings found in source configuration. Skipping."
    }

    # --- Network Access Restrictions (Manual Reminder) ---
    Write-SubsectionHeader "3.9 Configuring Network Access Restrictions (Manual Step)..."
    if ($global:configSettings.accessRestrictions -or $global:configSettings.scmAccessRestrictions) {
        Write-Warning "Network Access Restrictions were found on the source app (see exported files)."
        Write-Warning "These restrictions MUST be manually reviewed and re-applied to the new Flex Consumption app '$($global:newFunctionAppName)' if required."
        Write-Warning "Pay attention to both main site and SCM site rules."
        Pause-Script "Press [Enter] after reviewing and manually configuring Network Access Restrictions (if needed)..."
    } else {
        Write-Info "No Network Access Restrictions found on source app. Skipping."
    }

    # --- Built-in Auth (Manual Reminder) ---
    Write-SubsectionHeader "3.10 Configuring Built-in Authentication (Manual Step)..."
    $authSettingsFile = Join-Path $global:migrationDir "auth_settings.json"
    if (Test-Path $authSettingsFile) {
        $authSettings = Get-Content $authSettingsFile | ConvertFrom-Json
        if ($authSettings.enabled) {
            Write-Warning "Built-in Authentication (Easy Auth) was enabled on the source app."
            Write-Warning "This MUST be manually reconfigured on the new Flex Consumption app '$($global:newFunctionAppName)'."
            Write-Info "Refer to 'auth_settings.json' for the previous configuration."
            Pause-Script "Press [Enter] after manually configuring Built-in Authentication (if needed)..."
        } else {
            Write-Info "Built-in Authentication was not enabled on source. Skipping."
        }
    } else {
         Write-Warning "Could not read source auth settings. Please manually check and configure Built-in Auth on the new app if needed."
    }


    # --- Application Code Deployment ---
    Write-SubsectionHeader "3.11 Application Code Deployment..."
    if (Confirm-Action -Prompt "Would you like to deploy your function code now?") {
        $packageUrl = $global:configSettings.runFromPackage
        if ($packageUrl -like 'http*' ) {
            Write-Info "Source app used remote package URL: $packageUrl"
            if (Confirm-Action -Prompt "Deploy using the same package URL?") {
                Deploy-FromUrl -Url $packageUrl
            } elseif (Confirm-Action -Prompt "Download package from URL first, then deploy locally?") {
                Download-AndDeployPackage -Url $packageUrl
            } else {
                Write-Info "Skipping URL deployment. You can provide a local path."
                Deploy-LocalPackage
            }
        } elseif ($packageUrl -eq '1') {
            Write-Info "Source app used WEBSITE_RUN_FROM_PACKAGE=1 (local zip deployment)."
            Write-Warning "The specific package path used previously is unknown."
            Deploy-LocalPackage # Prompt for local path
        } else {
             Write-Info "Source app did not use WEBSITE_RUN_FROM_PACKAGE or value was unrecognized."
             Deploy-LocalPackage # Prompt for local path
        }
    } else {
        Write-Warning "Skipping code deployment. You can deploy later using:"
        Write-Host "az functionapp deployment source config-zip -g $($global:resourceGroupName) -n $($global:newFunctionAppName) --src <path-to-zip-or-url>"
    }

    Write-Success "Flex Consumption function app creation and initial configuration completed."
    Write-Info "New function app name: $global:newFunctionAppName"
    Pause-Script
}

function Deploy-FromUrl {
    param([string]$Url)
    Write-Info "Deploying using fetch deployment from URL: $Url"
    try {
        az functionapp deployment source config-zip -g $global:resourceGroupName -n $global:newFunctionAppName --src $Url --output none --only-show-errors
        if ($LASTEXITCODE -ne 0) { throw "az cli failed" }
        Write-Success "Function app deployed successfully from package URL."
    } catch {
        Write-Error "Failed to deploy function app directly from package URL. $_"
        if (Confirm-Action -Prompt "Try downloading the package and deploying it locally instead?") {
            Download-AndDeployPackage -Url $Url
        } else {
            Write-Warning "Skipping code deployment."
        }
    }
}

function Deploy-LocalPackage {
    param([string]$PackagePath) # Optional path argument

    if ([string]::IsNullOrWhiteSpace($PackagePath)) {
        $PackagePath = Read-Host -Prompt "Enter the path to your function app package (.zip file)"
    }

    if (Test-Path $PackagePath -PathType Leaf) {
        Write-Info "Deploying from local package: $PackagePath"
        try {
            az functionapp deployment source config-zip -g $global:resourceGroupName -n $global:newFunctionAppName --src $PackagePath --output none --only-show-errors
            if ($LASTEXITCODE -ne 0) { throw "az cli failed" }
            Write-Success "Function app deployed successfully from local package."
        } catch {
            Write-Error "Failed to deploy function app from local package '$PackagePath'. $_"
            # Don't automatically retry here, let user run manually if needed
        }
    } else {
        Write-Error "Package file not found or is not a file: $PackagePath"
        if (Confirm-Action -Prompt "Deployment failed. Try entering the path again?") {
            Deploy-LocalPackage # Call recursively without path argument to prompt again
        } else {
            Write-Warning "Skipping code deployment."
        }
    }
}

function Download-AndDeployPackage {
    param([string]$Url)

    $downloadFilename = [System.IO.Path]::GetFileName($Url)
    # Ensure filename ends with .zip if it doesn't have an extension or is weird
     if ([string]::IsNullOrWhiteSpace([System.IO.Path]::GetExtension($downloadFilename))) {
        $downloadFilename += ".zip"
    }
    $downloadPath = Join-Path $global:migrationDir $downloadFilename

    Write-Info "Attempting to download package from $Url to $downloadPath..."
    try {
        # Use Invoke-WebRequest for downloading in PowerShell
        Invoke-WebRequest -Uri $Url -OutFile $downloadPath -UseBasicParsing
        Write-Success "Package downloaded successfully to $downloadPath"
        Deploy-LocalPackage -PackagePath $downloadPath # Deploy the downloaded package
    } catch {
        Write-Error "Failed to download package from $Url. $_"
        Write-Warning "Please check the URL and network connectivity."
        if (Confirm-Action -Prompt "Try providing a local path manually instead?") {
            Deploy-LocalPackage
        } else {
            Write-Warning "Skipping code deployment."
        }
    }
}

#endregion

#region Step 4: Validation

function Validate-Migration {
    Write-SectionHeader "STEP 4: VALIDATION"

    # --- Verify Flex Consumption Plan ---
    Write-SubsectionHeader "4.1 Verifying Flex Consumption Plan..."
    Write-ProgressMsg "Checking SKU for '$($global:newFunctionAppName)'..."
    try {
        $appInfo = az functionapp show --name $global:newFunctionAppName --resource-group $global:resourceGroupName --output json --only-show-errors | ConvertFrom-Json
        if ($LASTEXITCODE -ne 0) { throw "az cli failed" }

        if ($appInfo.sku -eq "Flex") {
            Write-Success "Function app '$($global:newFunctionAppName)' is running on Flex Consumption plan."
            $global:appUrl = "https://$($appInfo.defaultHostName)"
            Write-Info "Function App URL: $($global:appUrl)"
        } else {
            Write-Error "Function app '$($global:newFunctionAppName)' is NOT running on Flex Consumption plan. Current SKU: $($appInfo.sku)"
            exit 1
        }
    } catch {
        Write-Error "Failed to verify function app SKU. $_"
        exit 1
    }

    # --- Check Functionality ---
    Write-SubsectionHeader "4.2 Checking Application Functionality..."
    Write-Info "Waiting for the function app to initialize and warm up..."
    Write-Info "This may take a few minutes, especially after deployment."
    Write-Host "`nYou can monitor the function app logs in a separate terminal using:" -ForegroundColor $global:YELLOW
    Write-Host "az webapp log tail --name $($global:newFunctionAppName) --resource-group $($global:resourceGroupName)"

    # List functions
    Write-ProgressMsg "Checking for functions in the app..."
    Start-Sleep -Seconds 10 # Give it a moment
    try {
        $functions = az functionapp function list --name $global:newFunctionAppName --resource-group $global:resourceGroupName --query "[].name" --output json --only-show-errors | ConvertFrom-Json
        if ($functions.Count -gt 0) {
            Write-Success "Functions found:"
            $functions | ForEach-Object { Write-Info "  - $_" }

            # Check for HTTP triggers to provide test URLs
            foreach ($funcName in $functions) {
                 $bindings = az functionapp function show --name $global:newFunctionAppName --resource-group $global:resourceGroupName --function-name $funcName --query "config.bindings" --output json --only-show-errors | ConvertFrom-Json -ErrorAction SilentlyContinue
                 if ($bindings | Where-Object { $_.type -like '*httpTrigger*' }) {
                     Write-Info "HTTP function '$funcName' test URL: $($global:appUrl)/api/$funcName"
                     # Add note about auth level if possible
                 }
            }
        } else {
            Write-Warning "No functions found or app is still initializing."
        }
    } catch {
        Write-Warning "Could not list functions. App might still be starting or deployment failed. $_"
    }

    # --- Performance and Monitoring ---
    Write-SubsectionHeader "4.3 Performance and Monitoring..."
    try {
        $appInsightsKey = az functionapp config appsettings list --name $global:newFunctionAppName --resource-group $global:resourceGroupName --query "[?name=='APPLICATIONINSIGHTS_CONNECTION_STRING'].value | [0]" --output tsv --only-show-errors
        if (-not [string]::IsNullOrWhiteSpace($appInsightsKey)) {
            Write-Success "Application Insights is configured."
            Write-Info "Monitor performance and logs in the Azure portal."
        } else {
            Write-Warning "Application Insights is not configured."
            Write-Info "Consider adding Application Insights for better monitoring."
        }
    } catch {
         Write-Warning "Could not check Application Insights configuration. $_"
    }

    Write-Info "`nKey Flex Consumption metrics to monitor in Azure Monitor:"
    Write-Info "  - AlwaysReadyFunctionExecutionCount, OnDemandFunctionExecutionCount"
    Write-Info "  - AlwaysReadyFunctionExecutionUnits, OnDemandFunctionExecutionUnits"
    Write-Info "  - AverageMemoryWorkingSet, InstanceCount"

    # --- Manual Validation Confirmation ---
    Write-Host "`nPlease manually test your application thoroughly." -ForegroundColor $global:YELLOW
    Write-Host "Invoke HTTP endpoints, check trigger outputs, verify integrations." -ForegroundColor $global:YELLOW

    if (Confirm-Action -Prompt "Have you tested the application and verified it works as expected?") {
        Write-Success "Migration validation successful!"
    } else {
        Write-Warning "Migration validation incomplete. Additional testing and troubleshooting recommended."
        Write-Info "Troubleshooting tips:"
        Write-Info "1. Check logs: az webapp log tail -g $($global:resourceGroupName) -n $($global:newFunctionAppName)"
        Write-Info "2. Verify App Settings in Azure portal."
        Write-Info "3. Check Deployment Center for deployment status."
        Write-Info "4. Review function trigger/binding configurations."
        if (-not (Confirm-Action -Prompt "Continue to post-migration tasks anyway?")) {
            Write-Error "Stopping migration process as validation failed or is incomplete."
            exit 1
        }
    }
    Pause-Script
}

#endregion

#region Step 5: Post-Migration

function Perform-PostMigrationTasks {
    Write-SectionHeader "STEP 5: POST-MIGRATION TASKS"

    # --- Update DNS / Custom Domains ---
    Write-SubsectionHeader "5.1 Update DNS and Custom Domains (Manual Step)..."
    $customDomainsFile = Join-Path $global:migrationDir "custom_domains.json"
    $customDomainCount = 0
    if (Test-Path $customDomainsFile) {
        try {
            $domains = Get-Content $customDomainsFile | ConvertFrom-Json
            $customDomainCount = ($domains | Where-Object { $_.name -notlike "*.azurewebsites.net" }).Count
        } catch { Write-Warning "Could not read custom domains file." }
    }

    if ($customDomainCount -gt 0) {
        Write-Warning "ACTION REQUIRED: $customDomainCount custom domain(s) were used on the source app."
        Write-Info "1. Add the custom domain(s) to the new app '$($global:newFunctionAppName)' in the Azure portal."
        Write-Info "2. Update your DNS provider's records (CNAME/A) to point to '$($global:newFunctionAppName).azurewebsites.net'."
        Write-Info "3. Verify DNS propagation and test the custom domains."
        Pause-Script "Press [Enter] once you have manually updated DNS and custom domains..."
    } else {
        Write-Info "No custom domains were found on the source app. Skipping."
    }

    # --- Update CI/CD ---
    Write-SubsectionHeader "5.2 Update CI/CD Pipelines (Manual Step)..."
    Write-Warning "ACTION REQUIRED: Update any CI/CD pipelines (Azure DevOps, GitHub Actions, etc.)"
    Write-Info "1. Change the target app name to '$($global:newFunctionAppName)'."
    Write-Info "2. Ensure deployment tasks use appropriate methods for Flex (e.g., config-zip)."
    Write-Info "3. Remove/update settings not applicable to Flex (e.g., WEBSITE_RUN_FROM_PACKAGE)."
    Write-Info "4. If creating infrastructure, ensure Flex Consumption plan is specified."
    Pause-Script "Press [Enter] once you have manually updated CI/CD pipelines..."

    # --- Update IaC ---
    Write-SubsectionHeader "5.3 Update Infrastructure as Code (Manual Step)..."
    Write-Warning "ACTION REQUIRED: Update any Infrastructure as Code (ARM, Bicep, Terraform)."
    Write-Info " - ARM/Bicep: Use 'Microsoft.Web/sites' with kind 'functionapp,linux' and sku 'Flex'."
    Write-Info " - Terraform: Use the 'azurerm_linux_function_app' resource with appropriate plan settings or dedicated Flex resource if available."
    Write-Info "Reference Samples: https://github.com/Azure-Samples/azure-functions-flex-consumption-samples/tree/main/IaC"
    Pause-Script "Press [Enter] once you have manually updated IaC templates..."

    # --- Recreate Function Keys (Manual Reminder) ---
    Write-SubsectionHeader "5.4 Recreate Function Keys (Manual Step)..."
    $functionKeysFile = Join-Path $global:migrationDir "function_keys.json"
    if (Test-Path $functionKeysFile) {
         $keysContent = Get-Content $functionKeysFile
         if ($keysContent -ne '{}' -and -not [string]::IsNullOrWhiteSpace($keysContent)) {
             Write-Warning "ACTION REQUIRED: Function-specific keys were found on the source app (see 'function_keys.json')."
             Write-Warning "These keys were NOT automatically recreated on '$($global:newFunctionAppName)'."
             Write-Warning "Manually recreate any required function keys using the Azure portal or CLI:"
             Write-Host "az functionapp function keys set -g $($global:resourceGroupName) -n $($global:newFunctionAppName) --function-name <FunctionName> --key-name <KeyName> --key-value <KeyValue>"
             Pause-Script "Press [Enter] once you have manually recreated necessary function keys..."
         } else {
             Write-Info "No function-specific keys were found on source. Skipping."
         }
    } else {
         Write-Info "Function keys file not found. Skipping reminder."
    }

    # --- Resource Cleanup ---
    Write-SubsectionHeader "5.5 Resource Cleanup (Optional)..."

    # Delete original app
    if (Confirm-Action -Prompt "Delete the original Linux Consumption function app '$($global:functionAppName)'? WARNING: This is irreversible.") {
        if (Confirm-Action -Prompt "ARE YOU SURE you want to permanently delete '$($global:functionAppName)'? Type 'y' to confirm.") {
            Write-Info "Deleting original function app '$($global:functionAppName)'..."
            try {
                az functionapp delete --name $global:functionAppName --resource-group $global:resourceGroupName --output none --only-show-errors
                if ($LASTEXITCODE -ne 0) { throw "az cli failed" }
                Write-Success "Original function app '$($global:functionAppName)' deleted successfully."
            } catch {
                Write-Error "Failed to delete original function app '$($global:functionAppName)'. Please delete manually. $_"
            }
        } else {
            Write-Info "Deletion of original app cancelled."
        }
    } else {
        Write-Info "Original function app '$($global:functionAppName)' preserved."
    }

    # Delete migration directory
    if (Confirm-Action -Prompt "Delete the temporary migration files in '$($global:migrationDir)'?") {
        Write-Info "Deleting migration directory '$($global:migrationDir)'..."
        try {
            Remove-Item -Path $global:migrationDir -Recurse -Force -ErrorAction Stop
            Write-Success "Migration directory deleted."
        } catch {
            Write-Error "Failed to delete migration directory. Please delete manually. $_"
        }
    } else {
        Write-Info "Migration directory preserved."
    }

    Write-Success "Post-migration tasks completed."
}

#endregion

#region Main Script Execution

function Main {
    Write-Host "`n==================================================" -ForegroundColor $global:BLUE
    Write-Host " AZURE FUNCTIONS: LINUX CONSUMPTION TO FLEX CONSUMPTION MIGRATION" -ForegroundColor $global:BLUE
    Write-Host "==================================================" -ForegroundColor $global:BLUE
    Write-Host "Version: $($global:scriptVersion)`n"

    Write-Host "This script guides you through migrating an Azure Function App from Linux Consumption to Flex Consumption."
    Write-Host "The migration involves creating a NEW Flex Consumption app alongside the original."
    Write-Host "`nProcess Overview:"
    Write-Host "1. ASSESSMENT: Identify app and check compatibility."
    Write-Host "2. PRE-MIGRATION: Export configuration from source app."
    Write-Host "3. MIGRATION: Create new Flex Consumption app and apply configuration."
    Write-Host "4. VALIDATION: Verify the new app is working."
    Write-Host "5. POST-MIGRATION: Manual steps (DNS, CI/CD, IaC, Keys) and optional cleanup."
    Write-Host "`n" -ForegroundColor $global:YELLOW
    Write-Host "⚠ IMPORTANT NOTES:" -ForegroundColor $global:YELLOW
    Write-Host "• Your original function app is NOT modified until optional cleanup in Step 5." -ForegroundColor $global:YELLOW
    Write-Host "• Backup critical data/settings before proceeding." -ForegroundColor $global:YELLOW
    Write-Host "• Some features (Slots, Certificates, Polling Blob Triggers) require manual changes or aren't supported in Flex." -ForegroundColor $global:YELLOW
    Write-Host "• Review exported configuration files in the 'flex_migration_*' directory." -ForegroundColor $global:YELLOW
    Write-Host "• Documentation: https://learn.microsoft.com/en-us/azure/azure-functions/flex-consumption-plan`n" -ForegroundColor $global:YELLOW

    Pause-Script

    try {
        # Execute migration steps
        Check-Prerequisites
        Select-SourceFunctionApp
        Export-SourceConfiguration
        Create-FlexConsumptionApp
        Validate-Migration
        Perform-PostMigrationTasks

        # --- Completion Message ---
        Write-SectionHeader "MIGRATION COMPLETE"
        Write-Host "Azure Function App migration to Flex Consumption appears successful!" -ForegroundColor $global:GREEN
        Write-Host "`nNew Function App Details:"
        Write-Host "  Name: $global:newFunctionAppName"
        Write-Host "  Resource Group: $global:resourceGroupName"
        Write-Host "  URL: $global:appUrl"
        Write-Host "`nPost-migration recommendations:"
        Write-Host "1. Monitor your app using Azure Monitor metrics specific to Flex Consumption."
        Write-Host "2. Review Flex Consumption documentation for cost and performance optimization."
        Write-Host "3. Ensure all necessary role assignments for Managed Identity are correct."
        Write-Host "`nFor more information, visit:"
        Write-Host "https://learn.microsoft.com/en-us/azure/azure-functions/flex-consumption-plan"
        Write-Host "https://learn.microsoft.com/en-us/azure/azure-functions/flex-consumption-how-to"

    } catch {
        Write-Error "An unexpected error occurred during the migration process: $($_.Exception.Message)"
        Write-Error "Script execution halted."
        # Consider adding more specific error handling or logging
    } finally {
         Write-Host "`nMigration script finished."
    }
}

# Run the main function
Main

#endregion

