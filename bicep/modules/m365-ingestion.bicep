metadata description = 'Microsoft 365 ingestion baseline resources.'

@description('Azure region for M365 ingestion resources.')
param location string

@description('Environment name.')
param environment string

@description('Short identifier prefix for resource naming.')
param resourcePrefix string

@description('Name of the Log Analytics workspace.')
param workspaceName string

@description('Resource ID of the Log Analytics workspace.')
param workspaceResourceId string

@description('Action group to route M365 service incident alerts.')
param actionGroupResourceId string

@description('Create baseline M365 custom table and alert.')
param enableM365Baseline bool = true

resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: workspaceName
}

resource m365Table 'Microsoft.OperationalInsights/workspaces/tables@2022-10-01' = if (enableM365Baseline) {
  parent: workspace
  name: 'M365ServiceHealth_CL'
  properties: {
    schema: {
      name: 'M365ServiceHealth_CL'
      columns: [
        {
          name: 'TimeGenerated'
          type: 'datetime'
        }
        {
          name: 'IssueId'
          type: 'string'
        }
        {
          name: 'Service'
          type: 'string'
        }
        {
          name: 'Status'
          type: 'string'
        }
        {
          name: 'Classification'
          type: 'string'
        }
      ]
    }
    retentionInDays: 30
    totalRetentionInDays: 30
    plan: 'Analytics'
  }
}

resource m365IncidentAlert 'Microsoft.Insights/scheduledQueryRules@2023-12-01' = if (enableM365Baseline) {
  name: 'sqr-m365-incident-${resourcePrefix}-${environment}'
  location: location
  properties: {
    description: 'Detect active M365 service incidents in custom table.'
    displayName: 'M365 Active Service Incident'
    enabled: true
    severity: 1
    scopes: [
      workspaceResourceId
    ]
    evaluationFrequency: 'PT15M'
    windowSize: 'PT15M'
    criteria: {
      allOf: [
        {
          query: 'M365ServiceHealth_CL | where Classification == "incident" | where Status !in ("ServiceRestored", "Resolved")'
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
      actionGroups: empty(actionGroupResourceId) ? [] : [
        actionGroupResourceId
      ]
    }
    autoMitigate: true
  }
}

output m365TableResourceId string = enableM365Baseline ? m365Table.id : ''
output m365AlertRuleResourceId string = enableM365Baseline ? m365IncidentAlert.id : ''
