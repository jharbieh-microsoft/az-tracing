using './main.bicep'

param location = 'eastus'
param environment = 'dev'
param resourcePrefix = 'contoso'
param logAnalyticsSkuName = 'PerGB2018'
param logAnalyticsRetentionInDays = 30
param logAnalyticsDailyCap = 10
param applicationInsightsSamplingPercentage = 100
param grafanaSku = 'Standard'
param enableGrafana = true
param enableDiagnosticSettings = true
param tags = {
  businessUnit: 'operations'
  costCenter: 'monitoring-platform'
  owner: 'platform-team'
  project: 'azure-monitoring'
  createdDate: '2026-03-25'
}
