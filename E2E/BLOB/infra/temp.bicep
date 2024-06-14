param sites_func_nzthipdfprocessor_name string = 'func-nzthipdfprocessor'
param components_funcnzthipdfprocessor_name string = 'funcnzthipdfprocessor'
param storageAccounts_nzthipdfprocessor_name string = 'nzthipdfprocessor'
param systemTopics_unprocessed_pdf_topic_name string = 'unprocessed-pdf-topic'
param serverfarms_FLEX_func_nzthipdfprocessor_d0ed_name string = 'FLEX-func-nzthipdfprocessor-d0ed'
param smartdetectoralertrules_failure_anomalies_funcnzthipdfprocessor_name string = 'failure anomalies - funcnzthipdfprocessor'
param actiongroups_application_insights_smart_detection_externalid string = '/subscriptions/2bcd95b1-1835-4d41-92ac-60c9c434ffd0/resourceGroups/rg-2024builddemo/providers/microsoft.insights/actiongroups/application insights smart detection'
param workspaces_DefaultWorkspace_2bcd95b1_1835_4d41_92ac_60c9c434ffd0_EUS_externalid string = '/subscriptions/2bcd95b1-1835-4d41-92ac-60c9c434ffd0/resourceGroups/DefaultResourceGroup-EUS/providers/Microsoft.OperationalInsights/workspaces/DefaultWorkspace-2bcd95b1-1835-4d41-92ac-60c9c434ffd0-EUS'
param userAssignedIdentities_ThiagoTestUserAssignedIdentity_externalid string = '/subscriptions/2bcd95b1-1835-4d41-92ac-60c9c434ffd0/resourceGroups/rg-eg-blob/providers/Microsoft.ManagedIdentity/userAssignedIdentities/ThiagoTestUserAssignedIdentity'

resource components_funcnzthipdfprocessor_name_resource 'microsoft.insights/components@2020-02-02' = {
  name: components_funcnzthipdfprocessor_name
  location: 'eastus'
  kind: 'web'
  properties: {
    Application_Type: 'web'
    RetentionInDays: 90
    WorkspaceResourceId: workspaces_DefaultWorkspace_2bcd95b1_1835_4d41_92ac_60c9c434ffd0_EUS_externalid
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource storageAccounts_nzthipdfprocessor_name_resource 'Microsoft.Storage/storageAccounts@2023-04-01' = {
  name: storageAccounts_nzthipdfprocessor_name
  location: 'eastus'
  sku: {
    name: 'Standard_LRS'
    tier: 'Standard'
  }
  kind: 'StorageV2'
  properties: {
    defaultToOAuthAuthentication: true
    allowCrossTenantReplication: false
    minimumTlsVersion: 'TLS1_0'
    allowBlobPublicAccess: false
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Allow'
    }
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    accessTier: 'Hot'
  }
}

resource serverfarms_FLEX_func_nzthipdfprocessor_d0ed_name_resource 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: serverfarms_FLEX_func_nzthipdfprocessor_d0ed_name
  location: 'East US'
  sku: {
    name: 'FC1'
    tier: 'FlexConsumption'
    size: 'FC1'
    family: 'FC'
    capacity: 0
  }
  kind: 'functionapp'
  properties: {
    perSiteScaling: false
    elasticScaleEnabled: false
    maximumElasticWorkerCount: 1
    isSpot: false
    reserved: true
    isXenon: false
    hyperV: false
    targetWorkerCount: 0
    targetWorkerSizeId: 0
    zoneRedundant: false
  }
}

resource smartdetectoralertrules_failure_anomalies_funcnzthipdfprocessor_name_resource 'microsoft.alertsmanagement/smartdetectoralertrules@2021-04-01' = {
  name: smartdetectoralertrules_failure_anomalies_funcnzthipdfprocessor_name
  location: 'global'
  properties: {
    description: 'Failure Anomalies notifies you of an unusual rise in the rate of failed HTTP requests or dependency calls.'
    state: 'Enabled'
    severity: 'Sev3'
    frequency: 'PT1M'
    detector: {
      id: 'FailureAnomaliesDetector'
    }
    scope: [
      components_funcnzthipdfprocessor_name_resource.id
    ]
    actionGroups: {
      groupIds: [
        actiongroups_application_insights_smart_detection_externalid
      ]
    }
  }
}

resource systemTopics_unprocessed_pdf_topic_name_resource 'Microsoft.EventGrid/systemTopics@2024-06-01-preview' = {
  name: systemTopics_unprocessed_pdf_topic_name
  location: 'eastus'
  properties: {
    source: storageAccounts_nzthipdfprocessor_name_resource.id
    topicType: 'Microsoft.Storage.StorageAccounts'
  }
}

resource systemTopics_unprocessed_pdf_topic_name_PDFProcessorEventSubscription 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2024-06-01-preview' = {
  parent: systemTopics_unprocessed_pdf_topic_name_resource
  name: 'PDFProcessorEventSubscription'
  properties: {
    destination: {
      properties: {
        maxEventsPerBatch: 1
        preferredBatchSizeInKilobytes: 64
      }
      endpointType: 'WebHook'
    }
    filter: {
      includedEventTypes: [
        'Microsoft.Storage.BlobCreated'
      ]
      enableAdvancedFilteringOnArrays: true
    }
    labels: []
    eventDeliverySchema: 'EventGridSchema'
    retryPolicy: {
      maxDeliveryAttempts: 30
      eventTimeToLiveInMinutes: 1440
    }
  }
}

resource components_funcnzthipdfprocessor_name_degradationindependencyduration 'microsoft.insights/components/ProactiveDetectionConfigs@2018-05-01-preview' = {
  parent: components_funcnzthipdfprocessor_name_resource
  name: 'degradationindependencyduration'
  location: 'eastus'
  properties: {
    RuleDefinitions: {
      Name: 'degradationindependencyduration'
      DisplayName: 'Degradation in dependency duration'
      Description: 'Smart Detection rules notify you of performance anomaly issues.'
      HelpUrl: 'https://docs.microsoft.com/en-us/azure/application-insights/app-insights-proactive-performance-diagnostics'
      IsHidden: false
      IsEnabledByDefault: true
      IsInPreview: false
      SupportsEmailNotifications: true
    }
    Enabled: true
    SendEmailsToSubscriptionOwners: true
    CustomEmails: []
  }
}

resource components_funcnzthipdfprocessor_name_degradationinserverresponsetime 'microsoft.insights/components/ProactiveDetectionConfigs@2018-05-01-preview' = {
  parent: components_funcnzthipdfprocessor_name_resource
  name: 'degradationinserverresponsetime'
  location: 'eastus'
  properties: {
    RuleDefinitions: {
      Name: 'degradationinserverresponsetime'
      DisplayName: 'Degradation in server response time'
      Description: 'Smart Detection rules notify you of performance anomaly issues.'
      HelpUrl: 'https://docs.microsoft.com/en-us/azure/application-insights/app-insights-proactive-performance-diagnostics'
      IsHidden: false
      IsEnabledByDefault: true
      IsInPreview: false
      SupportsEmailNotifications: true
    }
    Enabled: true
    SendEmailsToSubscriptionOwners: true
    CustomEmails: []
  }
}

resource components_funcnzthipdfprocessor_name_digestMailConfiguration 'microsoft.insights/components/ProactiveDetectionConfigs@2018-05-01-preview' = {
  parent: components_funcnzthipdfprocessor_name_resource
  name: 'digestMailConfiguration'
  location: 'eastus'
  properties: {
    RuleDefinitions: {
      Name: 'digestMailConfiguration'
      DisplayName: 'Digest Mail Configuration'
      Description: 'This rule describes the digest mail preferences'
      HelpUrl: 'www.homail.com'
      IsHidden: true
      IsEnabledByDefault: true
      IsInPreview: false
      SupportsEmailNotifications: true
    }
    Enabled: true
    SendEmailsToSubscriptionOwners: true
    CustomEmails: []
  }
}

resource components_funcnzthipdfprocessor_name_extension_billingdatavolumedailyspikeextension 'microsoft.insights/components/ProactiveDetectionConfigs@2018-05-01-preview' = {
  parent: components_funcnzthipdfprocessor_name_resource
  name: 'extension_billingdatavolumedailyspikeextension'
  location: 'eastus'
  properties: {
    RuleDefinitions: {
      Name: 'extension_billingdatavolumedailyspikeextension'
      DisplayName: 'Abnormal rise in daily data volume (preview)'
      Description: 'This detection rule automatically analyzes the billing data generated by your application, and can warn you about an unusual increase in your application\'s billing costs'
      HelpUrl: 'https://github.com/Microsoft/ApplicationInsights-Home/tree/master/SmartDetection/billing-data-volume-daily-spike.md'
      IsHidden: false
      IsEnabledByDefault: true
      IsInPreview: true
      SupportsEmailNotifications: false
    }
    Enabled: true
    SendEmailsToSubscriptionOwners: true
    CustomEmails: []
  }
}

resource components_funcnzthipdfprocessor_name_extension_canaryextension 'microsoft.insights/components/ProactiveDetectionConfigs@2018-05-01-preview' = {
  parent: components_funcnzthipdfprocessor_name_resource
  name: 'extension_canaryextension'
  location: 'eastus'
  properties: {
    RuleDefinitions: {
      Name: 'extension_canaryextension'
      DisplayName: 'Canary extension'
      Description: 'Canary extension'
      HelpUrl: 'https://github.com/Microsoft/ApplicationInsights-Home/blob/master/SmartDetection/'
      IsHidden: true
      IsEnabledByDefault: true
      IsInPreview: true
      SupportsEmailNotifications: false
    }
    Enabled: true
    SendEmailsToSubscriptionOwners: true
    CustomEmails: []
  }
}

resource components_funcnzthipdfprocessor_name_extension_exceptionchangeextension 'microsoft.insights/components/ProactiveDetectionConfigs@2018-05-01-preview' = {
  parent: components_funcnzthipdfprocessor_name_resource
  name: 'extension_exceptionchangeextension'
  location: 'eastus'
  properties: {
    RuleDefinitions: {
      Name: 'extension_exceptionchangeextension'
      DisplayName: 'Abnormal rise in exception volume (preview)'
      Description: 'This detection rule automatically analyzes the exceptions thrown in your application, and can warn you about unusual patterns in your exception telemetry.'
      HelpUrl: 'https://github.com/Microsoft/ApplicationInsights-Home/blob/master/SmartDetection/abnormal-rise-in-exception-volume.md'
      IsHidden: false
      IsEnabledByDefault: true
      IsInPreview: true
      SupportsEmailNotifications: false
    }
    Enabled: true
    SendEmailsToSubscriptionOwners: true
    CustomEmails: []
  }
}

resource components_funcnzthipdfprocessor_name_extension_memoryleakextension 'microsoft.insights/components/ProactiveDetectionConfigs@2018-05-01-preview' = {
  parent: components_funcnzthipdfprocessor_name_resource
  name: 'extension_memoryleakextension'
  location: 'eastus'
  properties: {
    RuleDefinitions: {
      Name: 'extension_memoryleakextension'
      DisplayName: 'Potential memory leak detected (preview)'
      Description: 'This detection rule automatically analyzes the memory consumption of each process in your application, and can warn you about potential memory leaks or increased memory consumption.'
      HelpUrl: 'https://github.com/Microsoft/ApplicationInsights-Home/tree/master/SmartDetection/memory-leak.md'
      IsHidden: false
      IsEnabledByDefault: true
      IsInPreview: true
      SupportsEmailNotifications: false
    }
    Enabled: true
    SendEmailsToSubscriptionOwners: true
    CustomEmails: []
  }
}

resource components_funcnzthipdfprocessor_name_extension_securityextensionspackage 'microsoft.insights/components/ProactiveDetectionConfigs@2018-05-01-preview' = {
  parent: components_funcnzthipdfprocessor_name_resource
  name: 'extension_securityextensionspackage'
  location: 'eastus'
  properties: {
    RuleDefinitions: {
      Name: 'extension_securityextensionspackage'
      DisplayName: 'Potential security issue detected (preview)'
      Description: 'This detection rule automatically analyzes the telemetry generated by your application and detects potential security issues.'
      HelpUrl: 'https://github.com/Microsoft/ApplicationInsights-Home/blob/master/SmartDetection/application-security-detection-pack.md'
      IsHidden: false
      IsEnabledByDefault: true
      IsInPreview: true
      SupportsEmailNotifications: false
    }
    Enabled: true
    SendEmailsToSubscriptionOwners: true
    CustomEmails: []
  }
}

resource components_funcnzthipdfprocessor_name_extension_traceseveritydetector 'microsoft.insights/components/ProactiveDetectionConfigs@2018-05-01-preview' = {
  parent: components_funcnzthipdfprocessor_name_resource
  name: 'extension_traceseveritydetector'
  location: 'eastus'
  properties: {
    RuleDefinitions: {
      Name: 'extension_traceseveritydetector'
      DisplayName: 'Degradation in trace severity ratio (preview)'
      Description: 'This detection rule automatically analyzes the trace logs emitted from your application, and can warn you about unusual patterns in the severity of your trace telemetry.'
      HelpUrl: 'https://github.com/Microsoft/ApplicationInsights-Home/blob/master/SmartDetection/degradation-in-trace-severity-ratio.md'
      IsHidden: false
      IsEnabledByDefault: true
      IsInPreview: true
      SupportsEmailNotifications: false
    }
    Enabled: true
    SendEmailsToSubscriptionOwners: true
    CustomEmails: []
  }
}

resource components_funcnzthipdfprocessor_name_longdependencyduration 'microsoft.insights/components/ProactiveDetectionConfigs@2018-05-01-preview' = {
  parent: components_funcnzthipdfprocessor_name_resource
  name: 'longdependencyduration'
  location: 'eastus'
  properties: {
    RuleDefinitions: {
      Name: 'longdependencyduration'
      DisplayName: 'Long dependency duration'
      Description: 'Smart Detection rules notify you of performance anomaly issues.'
      HelpUrl: 'https://docs.microsoft.com/en-us/azure/application-insights/app-insights-proactive-performance-diagnostics'
      IsHidden: false
      IsEnabledByDefault: true
      IsInPreview: false
      SupportsEmailNotifications: true
    }
    Enabled: true
    SendEmailsToSubscriptionOwners: true
    CustomEmails: []
  }
}

resource components_funcnzthipdfprocessor_name_migrationToAlertRulesCompleted 'microsoft.insights/components/ProactiveDetectionConfigs@2018-05-01-preview' = {
  parent: components_funcnzthipdfprocessor_name_resource
  name: 'migrationToAlertRulesCompleted'
  location: 'eastus'
  properties: {
    RuleDefinitions: {
      Name: 'migrationToAlertRulesCompleted'
      DisplayName: 'Migration To Alert Rules Completed'
      Description: 'A configuration that controls the migration state of Smart Detection to Smart Alerts'
      HelpUrl: 'https://docs.microsoft.com/en-us/azure/application-insights/app-insights-proactive-performance-diagnostics'
      IsHidden: true
      IsEnabledByDefault: false
      IsInPreview: true
      SupportsEmailNotifications: false
    }
    Enabled: false
    SendEmailsToSubscriptionOwners: true
    CustomEmails: []
  }
}

resource components_funcnzthipdfprocessor_name_slowpageloadtime 'microsoft.insights/components/ProactiveDetectionConfigs@2018-05-01-preview' = {
  parent: components_funcnzthipdfprocessor_name_resource
  name: 'slowpageloadtime'
  location: 'eastus'
  properties: {
    RuleDefinitions: {
      Name: 'slowpageloadtime'
      DisplayName: 'Slow page load time'
      Description: 'Smart Detection rules notify you of performance anomaly issues.'
      HelpUrl: 'https://docs.microsoft.com/en-us/azure/application-insights/app-insights-proactive-performance-diagnostics'
      IsHidden: false
      IsEnabledByDefault: true
      IsInPreview: false
      SupportsEmailNotifications: true
    }
    Enabled: true
    SendEmailsToSubscriptionOwners: true
    CustomEmails: []
  }
}

resource components_funcnzthipdfprocessor_name_slowserverresponsetime 'microsoft.insights/components/ProactiveDetectionConfigs@2018-05-01-preview' = {
  parent: components_funcnzthipdfprocessor_name_resource
  name: 'slowserverresponsetime'
  location: 'eastus'
  properties: {
    RuleDefinitions: {
      Name: 'slowserverresponsetime'
      DisplayName: 'Slow server response time'
      Description: 'Smart Detection rules notify you of performance anomaly issues.'
      HelpUrl: 'https://docs.microsoft.com/en-us/azure/application-insights/app-insights-proactive-performance-diagnostics'
      IsHidden: false
      IsEnabledByDefault: true
      IsInPreview: false
      SupportsEmailNotifications: true
    }
    Enabled: true
    SendEmailsToSubscriptionOwners: true
    CustomEmails: []
  }
}

resource storageAccounts_nzthipdfprocessor_name_default 'Microsoft.Storage/storageAccounts/blobServices@2023-04-01' = {
  parent: storageAccounts_nzthipdfprocessor_name_resource
  name: 'default'
  sku: {
    name: 'Standard_LRS'
    tier: 'Standard'
  }
  properties: {
    cors: {
      corsRules: []
    }
    deleteRetentionPolicy: {
      allowPermanentDelete: false
      enabled: false
    }
  }
}

resource Microsoft_Storage_storageAccounts_fileServices_storageAccounts_nzthipdfprocessor_name_default 'Microsoft.Storage/storageAccounts/fileServices@2023-04-01' = {
  parent: storageAccounts_nzthipdfprocessor_name_resource
  name: 'default'
  sku: {
    name: 'Standard_LRS'
    tier: 'Standard'
  }
  properties: {
    protocolSettings: {
      smb: {}
    }
    cors: {
      corsRules: []
    }
    shareDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

resource Microsoft_Storage_storageAccounts_queueServices_storageAccounts_nzthipdfprocessor_name_default 'Microsoft.Storage/storageAccounts/queueServices@2023-04-01' = {
  parent: storageAccounts_nzthipdfprocessor_name_resource
  name: 'default'
  properties: {
    cors: {
      corsRules: []
    }
  }
}

resource Microsoft_Storage_storageAccounts_tableServices_storageAccounts_nzthipdfprocessor_name_default 'Microsoft.Storage/storageAccounts/tableServices@2023-04-01' = {
  parent: storageAccounts_nzthipdfprocessor_name_resource
  name: 'default'
  properties: {
    cors: {
      corsRules: []
    }
  }
}

resource sites_func_nzthipdfprocessor_name_ftp 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2023-12-01' = {
  parent: sites_func_nzthipdfprocessor_name_resource
  name: 'ftp'
  location: 'East US'
  properties: {
    allow: false
  }
}

resource sites_func_nzthipdfprocessor_name_scm 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2023-12-01' = {
  parent: sites_func_nzthipdfprocessor_name_resource
  name: 'scm'
  location: 'East US'
  properties: {
    allow: false
  }
}

resource sites_func_nzthipdfprocessor_name_web 'Microsoft.Web/sites/config@2023-12-01' = {
  parent: sites_func_nzthipdfprocessor_name_resource
  name: 'web'
  location: 'East US'
  properties: {
    numberOfWorkers: 1
    defaultDocuments: [
      'Default.htm'
      'Default.html'
      'Default.asp'
      'index.htm'
      'index.html'
      'iisstart.htm'
      'default.aspx'
      'index.php'
    ]
    netFrameworkVersion: 'v4.0'
    requestTracingEnabled: false
    remoteDebuggingEnabled: false
    httpLoggingEnabled: false
    acrUseManagedIdentityCreds: false
    logsDirectorySizeLimit: 35
    detailedErrorLoggingEnabled: false
    publishingUsername: '$func-nzthipdfprocessor'
    scmType: 'None'
    use32BitWorkerProcess: false
    webSocketsEnabled: false
    alwaysOn: false
    managedPipelineMode: 'Integrated'
    virtualApplications: [
      {
        virtualPath: '/'
        physicalPath: 'site\\wwwroot'
        preloadEnabled: false
      }
    ]
    loadBalancing: 'LeastRequests'
    experiments: {
      rampUpRules: []
    }
    autoHealEnabled: false
    vnetRouteAllEnabled: false
    vnetPrivatePortsCount: 0
    localMySqlEnabled: false
    xManagedServiceIdentityId: 395
    ipSecurityRestrictions: [
      {
        ipAddress: 'Any'
        action: 'Allow'
        priority: 2147483647
        name: 'Allow all'
        description: 'Allow all access'
      }
    ]
    scmIpSecurityRestrictions: [
      {
        ipAddress: 'Any'
        action: 'Allow'
        priority: 2147483647
        name: 'Allow all'
        description: 'Allow all access'
      }
    ]
    scmIpSecurityRestrictionsUseMain: false
    http20Enabled: false
    minTlsVersion: '1.2'
    scmMinTlsVersion: '1.2'
    ftpsState: 'FtpsOnly'
    preWarmedInstanceCount: 0
    functionAppScaleLimit: 100
    functionsRuntimeScaleMonitoringEnabled: false
    minimumElasticInstanceCount: 0
    azureStorageAccounts: {}
  }
}

resource sites_func_nzthipdfprocessor_name_PDFProcessor 'Microsoft.Web/sites/functions@2023-12-01' = {
  parent: sites_func_nzthipdfprocessor_name_resource
  name: 'PDFProcessor'
  location: 'East US'
  properties: {
    script_href: 'https://func-nzthipdfprocessor.azurewebsites.net/admin/vfs/home/site/wwwroot/PDFProcessor.js'
    test_data_href: 'https://func-nzthipdfprocessor.azurewebsites.net/admin/vfs/tmp/FunctionsData/PDFProcessor.dat'
    href: 'https://func-nzthipdfprocessor.azurewebsites.net/admin/functions/PDFProcessor'
    config: {
      name: 'PDFProcessor'
      entryPoint: ''
      scriptFile: 'PDFProcessor.js'
      language: 'node'
      functionDirectory: '/home/site/wwwroot/src/functions'
      bindings: [
        {
          path: 'unprocessed-pdf/{name}.pdf'
          source: 'EventGrid'
          connection: '4de3b4_STORAGE'
          type: 'blobTrigger'
          name: 'blobTrigger079120cf05'
          direction: 'in'
        }
        {
          connection: '4de3b4_STORAGE'
          path: 'processed-text/{name}.txt'
          type: 'blob'
          name: '$return'
          direction: 'out'
        }
      ]
    }
    language: 'node'
    isDisabled: false
  }
}

resource sites_func_nzthipdfprocessor_name_sites_func_nzthipdfprocessor_name_azurewebsites_net 'Microsoft.Web/sites/hostNameBindings@2023-12-01' = {
  parent: sites_func_nzthipdfprocessor_name_resource
  name: '${sites_func_nzthipdfprocessor_name}.azurewebsites.net'
  location: 'East US'
  properties: {
    siteName: 'func-nzthipdfprocessor'
    hostNameType: 'Verified'
  }
}

resource storageAccounts_nzthipdfprocessor_name_default_app_package_func_storageAccounts_nzthipdfprocessor_name_ae571fc 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-04-01' = {
  parent: storageAccounts_nzthipdfprocessor_name_default
  name: 'app-package-func-${storageAccounts_nzthipdfprocessor_name}-ae571fc'
  properties: {
    immutableStorageWithVersioning: {
      enabled: false
    }
    defaultEncryptionScope: '$account-encryption-key'
    denyEncryptionScopeOverride: false
    publicAccess: 'None'
  }
  dependsOn: [
    storageAccounts_nzthipdfprocessor_name_resource
  ]
}

resource storageAccounts_nzthipdfprocessor_name_default_azure_webjobs_hosts 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-04-01' = {
  parent: storageAccounts_nzthipdfprocessor_name_default
  name: 'azure-webjobs-hosts'
  properties: {
    immutableStorageWithVersioning: {
      enabled: false
    }
    defaultEncryptionScope: '$account-encryption-key'
    denyEncryptionScopeOverride: false
    publicAccess: 'None'
  }
  dependsOn: [
    storageAccounts_nzthipdfprocessor_name_resource
  ]
}

resource storageAccounts_nzthipdfprocessor_name_default_azure_webjobs_secrets 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-04-01' = {
  parent: storageAccounts_nzthipdfprocessor_name_default
  name: 'azure-webjobs-secrets'
  properties: {
    immutableStorageWithVersioning: {
      enabled: false
    }
    defaultEncryptionScope: '$account-encryption-key'
    denyEncryptionScopeOverride: false
    publicAccess: 'None'
  }
  dependsOn: [
    storageAccounts_nzthipdfprocessor_name_resource
  ]
}

resource storageAccounts_nzthipdfprocessor_name_default_processed_text 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-04-01' = {
  parent: storageAccounts_nzthipdfprocessor_name_default
  name: 'processed-text'
  properties: {
    immutableStorageWithVersioning: {
      enabled: false
    }
    defaultEncryptionScope: '$account-encryption-key'
    denyEncryptionScopeOverride: false
    publicAccess: 'None'
  }
  dependsOn: [
    storageAccounts_nzthipdfprocessor_name_resource
  ]
}

resource storageAccounts_nzthipdfprocessor_name_default_unprocessed_pdf 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-04-01' = {
  parent: storageAccounts_nzthipdfprocessor_name_default
  name: 'unprocessed-pdf'
  properties: {
    immutableStorageWithVersioning: {
      enabled: false
    }
    defaultEncryptionScope: '$account-encryption-key'
    denyEncryptionScopeOverride: false
    publicAccess: 'None'
  }
  dependsOn: [
    storageAccounts_nzthipdfprocessor_name_resource
  ]
}

resource storageAccounts_nzthipdfprocessor_name_default_azure_webjobs_blobtrigger_066cfb5d689e8e5fcd81685c0ef5f8d0 'Microsoft.Storage/storageAccounts/queueServices/queues@2023-04-01' = {
  parent: Microsoft_Storage_storageAccounts_queueServices_storageAccounts_nzthipdfprocessor_name_default
  name: 'azure-webjobs-blobtrigger-066cfb5d689e8e5fcd81685c0ef5f8d0'
  properties: {
    metadata: {}
  }
  dependsOn: [
    storageAccounts_nzthipdfprocessor_name_resource
  ]
}

resource storageAccounts_nzthipdfprocessor_name_default_webjobs_blobtrigger_poison 'Microsoft.Storage/storageAccounts/queueServices/queues@2023-04-01' = {
  parent: Microsoft_Storage_storageAccounts_queueServices_storageAccounts_nzthipdfprocessor_name_default
  name: 'webjobs-blobtrigger-poison'
  properties: {
    metadata: {}
  }
  dependsOn: [
    storageAccounts_nzthipdfprocessor_name_resource
  ]
}

resource storageAccounts_nzthipdfprocessor_name_default_AzureFunctionsDiagnosticEvents202406 'Microsoft.Storage/storageAccounts/tableServices/tables@2023-04-01' = {
  parent: Microsoft_Storage_storageAccounts_tableServices_storageAccounts_nzthipdfprocessor_name_default
  name: 'AzureFunctionsDiagnosticEvents202406'
  properties: {}
  dependsOn: [
    storageAccounts_nzthipdfprocessor_name_resource
  ]
}

resource sites_func_nzthipdfprocessor_name_resource 'Microsoft.Web/sites@2023-12-01' = {
  name: sites_func_nzthipdfprocessor_name
  location: 'East US'
  kind: 'functionapp,linux'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '/subscriptions/2bcd95b1-1835-4d41-92ac-60c9c434ffd0/resourcegroups/rg-eg-blob/providers/Microsoft.ManagedIdentity/userAssignedIdentities/ThiagoTestUserAssignedIdentity': {}
    }
  }
  properties: {
    enabled: true
    hostNameSslStates: [
      {
        name: '${sites_func_nzthipdfprocessor_name}.azurewebsites.net'
        sslState: 'Disabled'
        hostType: 'Standard'
      }
      {
        name: '${sites_func_nzthipdfprocessor_name}.scm.azurewebsites.net'
        sslState: 'Disabled'
        hostType: 'Repository'
      }
    ]
    serverFarmId: serverfarms_FLEX_func_nzthipdfprocessor_d0ed_name_resource.id
    reserved: true
    isXenon: false
    hyperV: false
    dnsConfiguration: {}
    vnetRouteAllEnabled: false
    vnetImagePullEnabled: false
    vnetContentShareEnabled: false
    siteConfig: {
      numberOfWorkers: 1
      acrUseManagedIdentityCreds: false
      alwaysOn: false
      http20Enabled: false
      functionAppScaleLimit: 100
      minimumElasticInstanceCount: 0
    }
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: 'https://${storageAccounts_nzthipdfprocessor_name}.blob.core.windows.net/app-package-func-${storageAccounts_nzthipdfprocessor_name}-ae571fc'
          authentication: {
            type: 'UserAssignedIdentity'
            userAssignedIdentityResourceId: userAssignedIdentities_ThiagoTestUserAssignedIdentity_externalid
          }
        }
      }
      runtime: {
        name: 'node'
        version: '20'
      }
      scaleAndConcurrency: {
        alwaysReady: []
        maximumInstanceCount: 100
        instanceMemoryMB: 2048
      }
    }
    scmSiteAlsoStopped: false
    clientAffinityEnabled: false
    clientCertEnabled: false
    clientCertMode: 'Required'
    hostNamesDisabled: false
    vnetBackupRestoreEnabled: false
    customDomainVerificationId: '3E625E2EED687A1B66BC0A5228B7267DC0146345B64C99F0C62C07B53008BD59'
    containerSize: 1536
    dailyMemoryTimeQuota: 0
    httpsOnly: false
    redundancyMode: 'None'
    storageAccountRequired: false
    keyVaultReferenceIdentity: 'SystemAssigned'
  }
  dependsOn: [
    storageAccounts_nzthipdfprocessor_name_resource
  ]
}
