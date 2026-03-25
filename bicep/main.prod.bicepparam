using './main.bicep'

param location = 'eastus'
param environment = 'prod'
param resourcePrefix = 'contoso'
param logAnalyticsSkuName = 'PerGB2018'
param logAnalyticsRetentionInDays = 90
param logAnalyticsDailyCap = 100
param applicationInsightsSamplingPercentage = 80
param grafanaSku = 'Premium'
param enableGrafana = true
param enableDiagnosticSettings = true
param tags = {
  businessUnit: 'operations'
  costCenter: 'monitoring-platform'
  owner: 'platform-team'
  project: 'azure-monitoring'
  environment: 'production'
  createdDate: '2026-03-25'
}
