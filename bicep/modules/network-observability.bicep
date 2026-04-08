metadata description = 'Network observability resources for baseline path monitoring.'

@description('Azure region for network observability resources.')
param location string

@description('Environment name.')
param environment string

@description('Short identifier prefix for resource naming.')
param resourcePrefix string

@description('Resource ID of Log Analytics Workspace.')
param workspaceResourceId string

@description('Deploy baseline connection monitor.')
param enableConnectionMonitor bool = true

var networkWatcherName = 'NetworkWatcher_${location}'

resource networkWatcher 'Microsoft.Network/networkWatchers@2023-11-01' = {
  name: networkWatcherName
  location: location
}

resource connectionMonitor 'Microsoft.Network/networkWatchers/connectionMonitors@2023-11-01' = if (enableConnectionMonitor) {
  parent: networkWatcher
  name: 'cm-baseline-${resourcePrefix}-${environment}'
  location: location
  properties: {
    notes: 'Baseline internet path monitor. Replace endpoints with production sources/destinations.'
    endpoints: [
      {
        name: 'source-external'
        type: 'ExternalAddress'
        address: '1.1.1.1'
      }
      {
        name: 'dest-external'
        type: 'ExternalAddress'
        address: '8.8.8.8'
      }
    ]
    testConfigurations: [
      {
        name: 'tcp-443'
        testFrequencySec: 300
        protocol: 'Tcp'
        tcpConfiguration: {
          port: 443
        }
        successThreshold: {
          checksFailedPercent: 20
          roundTripTimeMs: 300
        }
      }
    ]
    testGroups: [
      {
        name: 'baseline-path'
        sources: [
          'source-external'
        ]
        destinations: [
          'dest-external'
        ]
        testConfigurations: [
          'tcp-443'
        ]
        disable: false
      }
    ]
    outputs: [
      {
        type: 'Workspace'
        workspaceSettings: {
          workspaceResourceId: workspaceResourceId
        }
      }
    ]
  }
}

output networkWatcherResourceId string = networkWatcher.id
output connectionMonitorResourceId string = enableConnectionMonitor ? connectionMonitor.id : ''
