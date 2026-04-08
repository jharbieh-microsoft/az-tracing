metadata description = 'Alerting resources: Action Groups, baseline alert rules, and processing rules.'

@description('Location for global alert resources.')
param location string = 'global'

@description('Environment name.')
param environment string

@description('Short identifier prefix for resource naming.')
param resourcePrefix string

@description('Resource ID of Log Analytics Workspace.')
param workspaceResourceId string

@description('Enable deployment of baseline alert rules.')
param enableBaselineAlerts bool = true

@description('Optional email receiver for critical Action Group.')
param criticalEmailAddress string = ''

@description('Optional email receiver for medium Action Group.')
param opsEmailAddress string = ''

@description('Optional webhook receiver for ITSM integration.')
param itsmWebhookServiceUri string = ''

var actionGroupPrefix = '${resourcePrefix}${environment}'

resource agOncallCritical 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'ag-oncall-critical-${resourcePrefix}-${environment}'
  location: location
  properties: {
    groupShortName: take('oncall${actionGroupPrefix}', 12)
    enabled: true
    emailReceivers: empty(criticalEmailAddress)
      ? []
      : [
          {
            name: 'critical-email'
            emailAddress: criticalEmailAddress
            useCommonAlertSchema: true
          }
        ]
    smsReceivers: []
    webhookReceivers: []
  }
}

resource agOpsMedium 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'ag-ops-medium-${resourcePrefix}-${environment}'
  location: location
  properties: {
    groupShortName: take('opsmed${actionGroupPrefix}', 12)
    enabled: true
    emailReceivers: empty(opsEmailAddress)
      ? []
      : [
          {
            name: 'ops-email'
            emailAddress: opsEmailAddress
            useCommonAlertSchema: true
          }
        ]
    smsReceivers: []
    webhookReceivers: []
  }
}

resource agItsm 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'ag-itsm-${resourcePrefix}-${environment}'
  location: location
  properties: {
    groupShortName: take('itsm${actionGroupPrefix}', 12)
    enabled: true
    emailReceivers: []
    smsReceivers: []
    webhookReceivers: empty(itsmWebhookServiceUri)
      ? []
      : [
          {
            name: 'itsm-webhook'
            serviceUri: itsmWebhookServiceUri
            useCommonAlertSchema: true
          }
        ]
  }
}

resource heartbeatAlert 'Microsoft.Insights/scheduledQueryRules@2023-12-01' = if (enableBaselineAlerts) {
  name: 'sqr-heartbeat-missing-${resourcePrefix}-${environment}'
  location: location
  properties: {
    description: 'Triggers when monitored hosts stop reporting heartbeat.'
    displayName: 'Heartbeat Missing'
    enabled: true
    severity: 1
    scopes: [
      workspaceResourceId
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT10M'
    criteria: {
      allOf: [
        {
          query: 'Heartbeat | summarize lastHeartbeat=max(TimeGenerated) by Computer | where lastHeartbeat < ago(10m)'
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [
        agOncallCritical.id
      ]
    }
    autoMitigate: true
  }
}

resource deploySuppressionWindow 'Microsoft.AlertsManagement/actionRules@2021-08-08' = {
  name: 'ar-maintenance-window-${resourcePrefix}-${environment}'
  location: location
  properties: {
    description: 'Baseline suppression rule placeholder for maintenance windows.'
    enabled: false
    scopes: [
      workspaceResourceId
    ]
    conditions: []
    actions: [
      {
        actionType: 'RemoveAllActionGroups'
      }
    ]
  }
}

output oncallCriticalActionGroupId string = agOncallCritical.id
output opsMediumActionGroupId string = agOpsMedium.id
output itsmActionGroupId string = agItsm.id
