# Network Observability Guide

Practical implementation guide for monitoring network connectivity, latency, and packet-loss across cloud, on-premises, and SaaS paths using Azure Network Watcher and Connection Monitor.

## Overview

Network observability closes the gap between application telemetry and infrastructure health. When an application degrades, network-layer data answers whether the cause is the app itself or an upstream or downstream network path.

This guide covers:
- Connectivity and latency monitoring between workloads
- DNS and routing troubleshooting
- Network flow analysis and traffic insights
- Integration with Log Analytics for correlated alerting

All network telemetry flows to the same Log Analytics Workspace used by the rest of this platform.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   MONITORED PATHS                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Azure VMs   On-Prem Servers   SaaS Endpoints   HTTP Apps  │
│      │              │                │               │      │
│      └──────────────┴────────────────┴───────────────┘      │
│                             │                               │
├─────────────────────────────────────────────────────────────┤
│               COLLECTION LAYER                              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   Connection Monitor    Network Watcher    NSG Flow Logs   │
│   ├─ Endpoint probes    ├─ Packet capture  ├─ Inbound       │
│   ├─ Path analysis      ├─ IP flow verify  └─ Outbound      │
│   └─ Latency / loss     └─ Next hop                        │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│               LOG ANALYTICS WORKSPACE                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   NWConnectionMonitorTestResult   AzureNetworkAnalytics_CL │
│   NetworkMonitoring               AzureDiagnostics          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                             │
              ┌──────────────┴──────────────┐
              │                             │
        Workbooks and               Alerts and
        Dashboards                  Action Groups
```

**Data flow**: Connection Monitor agents send synthetic probes on a defined schedule. Results are written to Log Analytics. Alerts evaluate KQL conditions and route to Action Groups.

---

## Step 1: Enable Network Watcher

Network Watcher must be enabled in every Azure region where you have monitored resources.

```bash
# Enable Network Watcher in a region
az network watcher configure \
  --locations eastus westus westeurope \
  --enabled true \
  --resource-group NetworkWatcherRG
```

Verify:
```bash
az network watcher list --output table
```

---

## Step 2: Deploy Connection Monitor

Connection Monitor tests connectivity and latency between sources and destinations on a schedule. It supports Azure VMs, Arc-enabled machines, and external HTTP/HTTPS endpoints.

### Step 2a: Create a Connection Monitor via Azure CLI

```bash
az network watcher connection-monitor create \
  --name cm-platform-health \
  --resource-group rg-contoso-monitor-prod \
  --location eastus \
  --workspace-id "<LOG_ANALYTICS_WORKSPACE_RESOURCE_ID>"
```

### Step 2b: Add Test Groups via Azure Portal

For each critical path, create a Test Group in Connection Monitor:

1. Azure Portal → **Network Watcher** → **Connection Monitor** → select monitor
2. **Test Groups** → **Add test group**
3. Configure:

**Test Group: On-Prem to Azure**
| Field | Value |
|---|---|
| Source | Arc-enabled on-prem server |
| Destination | Log Analytics workspace endpoint |
| Protocol | HTTPS / TCP 443 |
| Frequency | Every 1 minute |
| Threshold: Latency | > 150 ms = degraded, > 500 ms = failed |
| Threshold: Loss | > 5% = degraded, > 20% = failed |

**Test Group: Azure to SaaS**
| Field | Value |
|---|---|
| Source | Azure VM or App Service |
| Destination | SaaS endpoint (e.g., `api.salesforce.com`) |
| Protocol | HTTPS / TCP 443 |
| Frequency | Every 5 minutes |
| Threshold: Latency | > 300 ms = degraded |
| Threshold: Loss | > 5% = failed |

**Test Group: Internal VM-to-VM**
| Field | Value |
|---|---|
| Source | App server VM |
| Destination | Database server VM (private IP) |
| Protocol | TCP on app port (e.g., 1433, 5432, 3306) |
| Frequency | Every 1 minute |
| Threshold: Latency | > 10 ms = degraded |

### Step 2c: Bicep Deployment

```bicep
param location string = 'eastus'
param workspaceId string

resource connectionMonitor 'Microsoft.Network/networkWatchers/connectionMonitors@2023-04-01' = {
  name: 'NetworkWatcher_${location}/cm-platform-health'
  location: location
  properties: {
    endpoints: [
      {
        name: 'source-azure-vm'
        type: 'AzureVM'
        resourceId: '<AZURE_VM_RESOURCE_ID>'
      }
      {
        name: 'dest-saas-endpoint'
        type: 'ExternalAddress'
        address: 'api.example-saas.com'
      }
    ]
    testConfigurations: [
      {
        name: 'https-probe'
        testFrequencySec: 60
        protocol: 'Https'
        httpConfiguration: {
          port: 443
          method: 'Get'
          validStatusCodeRanges: ['200-299']
        }
        successThreshold: {
          checksFailedPercent: 5
          roundTripTimeMs: 300
        }
      }
    ]
    testGroups: [
      {
        name: 'azure-to-saas'
        sources: ['source-azure-vm']
        destinations: ['dest-saas-endpoint']
        testConfigurations: ['https-probe']
        disable: false
      }
    ]
    outputs: [
      {
        type: 'Workspace'
        workspaceSettings: {
          workspaceResourceId: workspaceId
        }
      }
    ]
  }
}
```

---

## Step 3: Enable NSG Flow Logs (Optional)

NSG Flow Logs capture accepted and rejected traffic through Network Security Groups. Use them to audit traffic patterns and detect unexpected connections.

```bash
# Enable NSG flow logs
az network watcher flow-log create \
  --location eastus \
  --name flowlog-prod-nsg \
  --nsg rg-contoso-monitor-prod/nsg-app-prod \
  --storage-account /subscriptions/<SUB_ID>/resourceGroups/<RG>/providers/Microsoft.Storage/storageAccounts/<STORAGE_ACCT> \
  --workspace /subscriptions/<SUB_ID>/resourceGroups/<RG>/providers/Microsoft.OperationalInsights/workspaces/<WORKSPACE> \
  --enabled true \
  --format JSON \
  --log-version 2 \
  --retention 30
```

---

## Step 4: KQL Queries for Network Analysis

Use these queries in Log Analytics to analyze network health.

### Query: Connection Monitor Test Results Over Time

```kusto
NWConnectionMonitorTestResult
| where TimeGenerated > ago(1h)
| summarize
    avg_latency_ms = avg(RoundTripTimeAvg),
    max_latency_ms = max(RoundTripTimeMax),
    loss_pct = avg(ChecksFailedPercent)
    by TestGroupName, DestinationName, bin(TimeGenerated, 5m)
| order by TimeGenerated desc
```

### Query: Failed or Degraded Paths

```kusto
NWConnectionMonitorTestResult
| where TimeGenerated > ago(1h)
| where TestResult in ("Fail", "Degraded")
| project TimeGenerated, SourceName, DestinationName, TestGroupName, TestResult, RoundTripTimeAvg, ChecksFailedPercent
| order by TimeGenerated desc
```

### Query: Latency Trend Per Destination

```kusto
NWConnectionMonitorTestResult
| where TimeGenerated > ago(24h)
| summarize avg_latency = avg(RoundTripTimeAvg) by DestinationName, bin(TimeGenerated, 15m)
| render timechart
```

### Query: NSG Traffic Summary (Denied Traffic)

```kusto
AzureNetworkAnalytics_CL
| where SubType_s == "FlowLog"
| where FlowStatus_s == "D"
| summarize denied_flows = count() by SrcIP_s, DestIP_s, DestPort_d, L7Protocol_s
| top 20 by denied_flows desc
```

---

## Step 5: Alerts for Network Conditions

### Alert: Path Latency Exceeds Threshold

1. Azure Portal → Log Analytics Workspace → **Alerts** → **Create alert rule**
2. **Condition**: Custom log search

```kusto
NWConnectionMonitorTestResult
| where TestGroupName == "azure-to-saas"
| summarize avg_latency = avg(RoundTripTimeAvg)
| where avg_latency > 300
```

3. **Alert logic**: Threshold = 0 (trigger when any row returned)
4. **Frequency**: Every 5 minutes
5. **Lookback**: 5 minutes
6. **Action Group**: Route to on-call Action Group (see [ALERTING_NOTIFICATIONS.md](ALERTING_NOTIFICATIONS.md))

### Alert: Connection Loss Above 5%

```kusto
NWConnectionMonitorTestResult
| where TestGroupName == "on-prem-to-azure"
| summarize avg_loss = avg(ChecksFailedPercent)
| where avg_loss > 5
```

---

## Step 6: Network Health Workbook

Add a network health section to your Azure Workbook:

1. Azure Portal → **Monitor** → **Workbooks** → Open your platform workbook
2. Add a new tab: **Network Health**
3. Add these tiles:
   - Time chart: Average latency per test group (past 24h)
   - Grid: Failed/degraded probe count by path (past 1h)
   - Stat: Overall availability percentage per test group

### Sample Workbook KQL Tile: Path Availability

```kusto
NWConnectionMonitorTestResult
| where TimeGenerated > ago(24h)
| summarize
    total = count(),
    passed = countif(TestResult == "Pass")
    by TestGroupName
| extend availability_pct = round((todouble(passed) / todouble(total)) * 100, 1)
| project TestGroupName, availability_pct
```

---

## Validation Checklist

- [ ] Network Watcher enabled in all target regions
- [ ] Connection Monitor created and linked to Log Analytics Workspace
- [ ] Test groups configured for on-prem-to-Azure, cloud-to-SaaS, and internal VM-to-VM paths
- [ ] NSG Flow Logs enabled on production NSGs (if required)
- [ ] KQL queries return data for all test groups
- [ ] Latency and packet-loss alerts are active and tested
- [ ] Network health tiles added to monitoring dashboard
