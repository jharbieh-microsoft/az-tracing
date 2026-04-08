metadata description = 'Data collection resources for VM and hybrid telemetry.'

@description('Azure region for DCR resources.')
param location string

@description('Environment name.')
param environment string

@description('Short identifier prefix for resource naming.')
param resourcePrefix string

@description('Resource ID of Log Analytics Workspace.')
param workspaceResourceId string

@description('Deploy baseline Data Collection Rule.')
param enableDataCollectionRule bool = true

resource dcrBaseline 'Microsoft.Insights/dataCollectionRules@2022-06-01' = if (enableDataCollectionRule) {
  name: 'dcr-baseline-${resourcePrefix}-${environment}'
  location: location
  properties: {
    description: 'Collects baseline performance counters and system logs for monitored servers.'
    dataCollectionEndpointId: null
    streamDeclarations: {}
    dataSources: {
      performanceCounters: [
        {
          name: 'perf-baseline'
          streams: [
            'Microsoft-Perf'
          ]
          samplingFrequencyInSeconds: 60
          counterSpecifiers: [
            '\\Processor(_Total)\\% Processor Time'
            '\\Memory\\Available MBytes'
            '\\LogicalDisk(_Total)\\% Free Space'
            '\\Network Interface(*)\\Bytes Total/sec'
          ]
        }
      ]
      windowsEventLogs: [
        {
          name: 'windows-events'
          streams: [
            'Microsoft-Event'
          ]
          xPathQueries: [
            'Application!*[System[(Level=1 or Level=2)]]'
            'System!*[System[(Level=1 or Level=2)]]'
          ]
        }
      ]
      syslog: [
        {
          name: 'linux-syslog'
          streams: [
            'Microsoft-Syslog'
          ]
          facilityNames: [
            'auth'
            'daemon'
            'syslog'
          ]
          logLevels: [
            'Error'
            'Critical'
            'Alert'
          ]
        }
      ]
    }
    destinations: {
      logAnalytics: [
        {
          name: 'la-destination'
          workspaceResourceId: workspaceResourceId
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          'Microsoft-Perf'
          'Microsoft-Event'
          'Microsoft-Syslog'
        ]
        destinations: [
          'la-destination'
        ]
      }
    ]
  }
}

output baselineDcrId string = enableDataCollectionRule ? dcrBaseline.id : ''
