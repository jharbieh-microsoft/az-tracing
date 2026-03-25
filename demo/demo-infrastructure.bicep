// Demo Infrastructure - Complete Bicep Template
// Deploys monitoring foundation for demo with web app, VMs, and SaaS integration

param location string = resourceGroup().location
param resourcePrefix string = 'demotrace'
param environment string = 'dev'

// Generate unique suffix for global resources
var uniqueSuffix = uniqueString(resourceGroup().id).substring(0, 6)
var appServicePlanName = 'plan-${resourcePrefix}-${environment}'
var webAppName = 'app-${resourcePrefix}-${uniqueSuffix}'
var workspaceName = 'law-${resourcePrefix}-${environment}'
var appInsightsName = 'appi-${resourcePrefix}-${environment}'
var actionGroupName = 'ag-${resourcePrefix}-${environment}'
var functionAppName = 'func-${resourcePrefix}-${uniqueSuffix}'
var storageAccountName = 'stg${resourcePrefix}${uniqueSuffix}'

// Tags for cost allocation
var commonTags = {
  environment: environment
  project: 'demo-monitoring'
  createdBy: 'bicep'
  costCenter: 'engineering'
}

// ========== Log Analytics Workspace ==========
resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: workspaceName
  location: location
  tags: commonTags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    dailyQuotaGb: 5
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

// ========== Application Insights ==========
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: commonTags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: workspace.id
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    RetentionInDays: 30
    SamplingPercentage: 100
  }
}

// ========== App Service Plan ==========
resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: appServicePlanName
  location: location
  tags: commonTags
  sku: {
    name: 'B1'
    tier: 'Basic'
    size: 'B1'
    family: 'B'
    capacity: 1
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

// ========== Web App ==========
resource webApp 'Microsoft.Web/sites@2022-09-01' = {
  name: webAppName
  location: location
  tags: commonTags
  kind: 'app,linux'
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'NODE|18-lts'
      alwaysOn: false
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'XDT_MicrosoftApplicationInsights_Mode'
          value: 'recommended'
        }
      ]
    }
  }
}

// ========== Action Group ==========
resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: actionGroupName
  location: 'global'
  tags: commonTags
  properties: {
    groupShortName: 'demoalerts'
    enabled: true
    emailReceivers: [
      {
        name: 'Demo Admin'
        emailAddress: 'admin@contoso.com'
        useCommonAlertSchema: true
      }
    ]
    webhookReceivers: []
    smsReceivers: []
    itsmReceivers: []
  }
}

// ========== Storage Account for Functions ==========
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAccountName
  location: location
  tags: commonTags
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
  }
}

// ========== Function App ==========
resource functionApp 'Microsoft.Web/sites@2022-09-01' = {
  name: functionAppName
  location: location
  tags: commonTags
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'NODE|18'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_RUNTIME'
          value: 'node'
        }
        {
          name: 'WORKSPACE_ID'
          value: workspace.properties.customerId
        }
        {
          name: 'SHARED_KEY'
          value: workspace.listKeys().primarySharedKey
        }
        {
          name: 'GITHUB_TOKEN'
          value: '' // Configure manually
        }
      ]
    }
  }
}

// ========== Diagnostic Settings ==========
resource workspaceDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: workspace
  name: '${workspaceName}-diagnostics'
  properties: {
    workspaceId: workspace.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}

// ========== Outputs ==========
output workspaceId string = workspace.id
output workspaceName string = workspace.name
output workspaceCustomerId string = workspace.properties.customerId
output appInsightsKey string = appInsights.properties.InstrumentationKey
output appInsightsConnectionString string = appInsights.properties.ConnectionString
output webAppUrl string = 'https://${webApp.properties.defaultHostName}'
output functionAppUrl string = 'https://${functionApp.properties.defaultHostName}'
output actionGroupId string = actionGroup.id
output storageAccountName string = storageAccount.name
