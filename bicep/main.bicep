// Azure Monitor Monitoring Foundation - Bicep Module
// Deploys Log Analytics Workspace, Application Insights, Managed Grafana, and RBAC

metadata description = 'Azure Monitor hybrid observability platform foundation for unified monitoring across cloud, hybrid, and SaaS workloads.'
metadata version = '1.0.0'

param location string = resourceGroup().location
@description('The Azure region where resources will be deployed.')

param environment string = 'dev'
@description('Environment name: dev, test, or prod.')
@allowed([
  'dev'
  'test'
  'prod'
])

param resourcePrefix string
@description('Short identifier prefix for resource naming (e.g., contoso, org-name).')
@minLength(2)
@maxLength(10)

param logAnalyticsSkuName string = 'PerGB2018'
@description('Log Analytics Workspace pricing tier.')
@allowed([
  'PerGB2018'
  'Free'
])

param logAnalyticsRetentionInDays int = 30
@description('Data retention in days for Log Analytics Workspace.')
@minValue(7)
@maxValue(730)

param logAnalyticsDailyCap int = 10
@description('Daily ingestion cap in GB to control costs.')
@minValue(1)
@maxValue(500)

param applicationInsightsSamplingPercentage int = 100
@description('Adaptive sampling percentage for Application Insights (1-100).')
@minValue(1)
@maxValue(100)

param grafanaSku string = 'Standard'
@description('Azure Managed Grafana pricing tier.')
@allowed([
  'Standard'
  'Premium'
])

param enableGrafana bool = true
@description('Deploy Azure Managed Grafana instance.')

param enableDiagnosticSettings bool = true
@description('Enable diagnostic settings to send platform logs to Log Analytics.')

param tags object = {}
@description('Tags to apply to all resources for organization and cost allocation.')

// Resource naming
var resourceGroupName = resourceGroup().name
var workspaceName = 'law-${resourcePrefix}-${environment}'
var applicationInsightsName = 'appi-${resourcePrefix}-${environment}'
var grafanaName = 'grafana-${resourcePrefix}-${environment}'
var actionGroupName = 'ag-${resourcePrefix}-${environment}'
var resourceTags = union(tags, {
  environment: environment
  createdBy: 'bicep'
  managedBy: 'infrastructure-team'
})

// Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: workspaceName
  location: location
  tags: resourceTags
  properties: {
    sku: {
      name: logAnalyticsSkuName
    }
    retentionInDays: logAnalyticsRetentionInDays
    dailyQuotaGb: logAnalyticsDailyCap
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    features: {
      searchVersion: 1
      legacy: 0
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

// Application Insights
resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  kind: 'web'
  tags: resourceTags
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    RetentionInDays: logAnalyticsRetentionInDays
    SamplingPercentage: applicationInsightsSamplingPercentage
  }
}

// Azure Managed Grafana
resource grafana 'Microsoft.Dashboard/grafana@2023-09-01' = if (enableGrafana) {
  name: grafanaName
  location: location
  sku: {
    name: grafanaSku
  }
  kind: 'nativeGrafana'
  identity: {
    type: 'SystemAssigned'
  }
  tags: resourceTags
  properties: {
    publicNetworkAccessEnabled: true
    zoneRedundancyEnabled: environment == 'prod' ? true : false
    grafanaIntegrations: {
      azureMonitorWorkspaceIntegrations: []
    }
  }
}

// Action Group for alerts and notifications
resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: actionGroupName
  location: 'global'
  tags: resourceTags
  properties: {
    groupShortName: 'monitoralerts'
    enabled: true
    // Add receivers as needed during deployment or via parameters
    emailReceivers: []
    smsReceivers: []
    webhookReceivers: []
  }
}

// Diagnostic Settings for Log Analytics Workspace
resource logAnalyticsDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnosticSettings) {
  scope: logAnalyticsWorkspace
  name: '${workspaceName}-diagnostics'
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}

// Outputs
@description('The resource ID of the Log Analytics Workspace.')
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id

@description('The workspace key (shared key) for agent configuration.')
output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.name

@description('The Application Insights instrumentation key.')
output applicationInsightsInstrumentationKey string = applicationInsights.properties.InstrumentationKey

@description('The Application Insights connection string.')
output applicationInsightsConnectionString string = applicationInsights.properties.ConnectionString

@description('The resource ID of the Application Insights component.')
output applicationInsightsResourceId string = applicationInsights.id

@description('The resource ID of the Azure Managed Grafana instance.')
output grafanaResourceId string = enableGrafana ? grafana.id : ''

@description('The endpoint URL of the Azure Managed Grafana instance.')
output grafanaUrl string = enableGrafana ? 'https://${grafana.properties.endpoint}' : ''

@description('The resource ID of the Action Group.')
output actionGroupResourceId string = actionGroup.id

@description('Full resource tags applied to all resources.')
output appliedTags object = resourceTags
