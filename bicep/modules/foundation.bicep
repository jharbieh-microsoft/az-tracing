metadata description = 'Foundation resources for Azure Monitor observability platform.'

@description('The Azure region where resources will be deployed.')
param location string

@description('Environment name: dev, test, or prod.')
@allowed([
  'dev'
  'test'
  'prod'
])
param environment string

@description('Short identifier prefix for resource naming (e.g., contoso).')
@minLength(2)
@maxLength(10)
param resourcePrefix string

@description('Log Analytics Workspace pricing tier.')
@allowed([
  'PerGB2018'
  'Free'
])
param logAnalyticsSkuName string

@description('Data retention in days for Log Analytics Workspace.')
@minValue(7)
@maxValue(730)
param logAnalyticsRetentionInDays int

@description('Daily ingestion cap in GB to control costs.')
@minValue(1)
@maxValue(500)
param logAnalyticsDailyCap int

@description('Adaptive sampling percentage for Application Insights (1-100).')
@minValue(1)
@maxValue(100)
param applicationInsightsSamplingPercentage int

@description('Azure Managed Grafana pricing tier.')
@allowed([
  'Standard'
  'Premium'
])
param grafanaSku string

@description('Deploy Azure Managed Grafana instance.')
param enableGrafana bool

@description('Enable diagnostic settings to send platform logs to Log Analytics.')
param enableDiagnosticSettings bool

@description('Tags to apply to all resources for organization and cost allocation.')
param tags object = {}

var workspaceName = 'law-${resourcePrefix}-${environment}'
var applicationInsightsName = 'appi-${resourcePrefix}-${environment}'
var grafanaName = 'grafana-${resourcePrefix}-${environment}'
var resourceTags = union(tags, {
  environment: environment
  createdBy: 'bicep'
  managedBy: 'infrastructure-team'
})

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: workspaceName
  location: location
  tags: resourceTags
  properties: {
    sku: {
      name: logAnalyticsSkuName
    }
    retentionInDays: logAnalyticsRetentionInDays
    workspaceCapping: {
      dailyQuotaGb: logAnalyticsDailyCap
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    features: {
      searchVersion: 1
      legacy: 0
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

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

resource grafana 'Microsoft.Dashboard/grafana@2023-09-01' = if (enableGrafana) {
  name: grafanaName
  location: location
  sku: {
    name: grafanaSku
  }
  identity: {
    type: 'SystemAssigned'
  }
  tags: resourceTags
  properties: {
    publicNetworkAccess: 'Enabled'
    zoneRedundancy: environment == 'prod' ? 'Enabled' : 'Disabled'
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnosticSettings) {
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

output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.name
output applicationInsightsInstrumentationKey string = applicationInsights.properties.InstrumentationKey
output applicationInsightsConnectionString string = applicationInsights.properties.ConnectionString
output applicationInsightsResourceId string = applicationInsights.id
output grafanaResourceId string = enableGrafana ? grafana.id : ''
output grafanaName string = enableGrafana ? grafana.name : ''
output appliedTags object = resourceTags
