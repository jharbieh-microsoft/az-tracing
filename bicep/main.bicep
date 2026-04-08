// Azure Monitor Monitoring Platform - Modular Orchestrator
// Step 1: compile/deploy remediation
// Step 2: split into modules (foundation, alerting, data-collection, network, m365)

metadata description = 'Modular Azure Monitor observability deployment orchestrator.'
metadata version = '1.1.0'

@description('The Azure region where resources will be deployed.')
param location string = resourceGroup().location

@description('Environment name: dev, test, or prod.')
@allowed([
  'dev'
  'test'
  'prod'
])
param environment string = 'dev'

@description('Short identifier prefix for resource naming (e.g., contoso, org-name).')
@minLength(2)
@maxLength(10)
param resourcePrefix string

@description('Log Analytics Workspace pricing tier.')
@allowed([
  'PerGB2018'
  'Free'
])
param logAnalyticsSkuName string = 'PerGB2018'

@description('Data retention in days for Log Analytics Workspace.')
@minValue(7)
@maxValue(730)
param logAnalyticsRetentionInDays int = 30

@description('Daily ingestion cap in GB to control costs.')
@minValue(1)
@maxValue(500)
param logAnalyticsDailyCap int = 10

@description('Adaptive sampling percentage for Application Insights (1-100).')
@minValue(1)
@maxValue(100)
param applicationInsightsSamplingPercentage int = 100

@description('Azure Managed Grafana pricing tier.')
@allowed([
  'Standard'
  'Premium'
])
param grafanaSku string = 'Standard'

@description('Deploy Azure Managed Grafana instance.')
param enableGrafana bool = true

@description('Enable diagnostic settings to send platform logs to Log Analytics.')
param enableDiagnosticSettings bool = true

@description('Tags to apply to all resources for organization and cost allocation.')
param tags object = {}

@description('Deploy alerting module resources.')
param enableAlertingModule bool = true

@description('Deploy data collection module resources.')
param enableDataCollectionModule bool = true

@description('Deploy network observability module resources.')
param enableNetworkObservabilityModule bool = true

@description('Deploy Microsoft 365 ingestion baseline module resources.')
param enableM365IngestionModule bool = true

@description('Optional email receiver for critical Action Group.')
param criticalEmailAddress string = ''

@description('Optional email receiver for medium Action Group.')
param opsEmailAddress string = ''

@description('Optional webhook receiver for ITSM integration.')
param itsmWebhookServiceUri string = ''

module foundation './modules/foundation.bicep' = {
  name: 'foundation-${resourcePrefix}-${environment}'
  params: {
    location: location
    environment: environment
    resourcePrefix: resourcePrefix
    logAnalyticsSkuName: logAnalyticsSkuName
    logAnalyticsRetentionInDays: logAnalyticsRetentionInDays
    logAnalyticsDailyCap: logAnalyticsDailyCap
    applicationInsightsSamplingPercentage: applicationInsightsSamplingPercentage
    grafanaSku: grafanaSku
    enableGrafana: enableGrafana
    enableDiagnosticSettings: enableDiagnosticSettings
    tags: tags
  }
}

module alerting './modules/alerting.bicep' = if (enableAlertingModule) {
  name: 'alerting-${resourcePrefix}-${environment}'
  params: {
    location: 'global'
    environment: environment
    resourcePrefix: resourcePrefix
    workspaceResourceId: foundation.outputs.logAnalyticsWorkspaceId
    criticalEmailAddress: criticalEmailAddress
    opsEmailAddress: opsEmailAddress
    itsmWebhookServiceUri: itsmWebhookServiceUri
  }
}

module dataCollection './modules/data-collection.bicep' = if (enableDataCollectionModule) {
  name: 'data-collection-${resourcePrefix}-${environment}'
  params: {
    location: location
    environment: environment
    resourcePrefix: resourcePrefix
    workspaceResourceId: foundation.outputs.logAnalyticsWorkspaceId
  }
}

module networkObservability './modules/network-observability.bicep' = if (enableNetworkObservabilityModule) {
  name: 'network-observability-${resourcePrefix}-${environment}'
  params: {
    location: location
    environment: environment
    resourcePrefix: resourcePrefix
    workspaceResourceId: foundation.outputs.logAnalyticsWorkspaceId
  }
}

module m365Ingestion './modules/m365-ingestion.bicep' = if (enableM365IngestionModule) {
  name: 'm365-ingestion-${resourcePrefix}-${environment}'
  params: {
    location: location
    environment: environment
    resourcePrefix: resourcePrefix
    workspaceName: foundation.outputs.logAnalyticsWorkspaceName
    workspaceResourceId: foundation.outputs.logAnalyticsWorkspaceId
    actionGroupResourceId: enableAlertingModule ? alerting!.outputs.oncallCriticalActionGroupId : ''
  }
}

@description('The resource ID of the Log Analytics Workspace.')
output logAnalyticsWorkspaceId string = foundation.outputs.logAnalyticsWorkspaceId

@description('The workspace name for agent and connector configuration.')
output logAnalyticsWorkspaceName string = foundation.outputs.logAnalyticsWorkspaceName

@description('The Application Insights instrumentation key.')
output applicationInsightsInstrumentationKey string = foundation.outputs.applicationInsightsInstrumentationKey

@description('The Application Insights connection string.')
output applicationInsightsConnectionString string = foundation.outputs.applicationInsightsConnectionString

@description('The resource ID of the Application Insights component.')
output applicationInsightsResourceId string = foundation.outputs.applicationInsightsResourceId

@description('The resource ID of the Azure Managed Grafana instance.')
output grafanaResourceId string = foundation.outputs.grafanaResourceId

@description('The resource name of the Azure Managed Grafana instance.')
output grafanaName string = foundation.outputs.grafanaName

@description('Critical Action Group resource ID.')
output oncallCriticalActionGroupId string = enableAlertingModule ? alerting!.outputs.oncallCriticalActionGroupId : ''

@description('Baseline Data Collection Rule resource ID.')
output baselineDcrId string = enableDataCollectionModule ? dataCollection!.outputs.baselineDcrId : ''

@description('Connection Monitor resource ID.')
output connectionMonitorResourceId string = enableNetworkObservabilityModule ? networkObservability!.outputs.connectionMonitorResourceId : ''

@description('M365 custom table resource ID.')
output m365TableResourceId string = enableM365IngestionModule ? m365Ingestion!.outputs.m365TableResourceId : ''
