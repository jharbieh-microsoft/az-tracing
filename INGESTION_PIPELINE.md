# Unified Ingestion Pipeline Architecture

Comprehensive ingestion pipeline design for collecting telemetry from HTTP applications, on-premises data center workloads, SaaS platforms, and custom sources into a centralized Log Analytics Workspace.

## Overview

The unified ingestion pipeline aggregates data from all monitoring sources into a single Log Analytics Workspace, enabling:
- Centralized correlation across all workload types
- Single source of truth for dashboards and alerts
- Unified RBAC and data governance
- Cost visibility across all telemetry sources

## Current Repository Coverage

This pipeline design is now backed by implementation assets in this repository:

1. Monitoring foundation deployment is documented in [bicep/README.md](bicep/README.md) and implemented in the [bicep](bicep) folder.
2. Data center onboarding and Azure Monitor Agent collection patterns are documented in [DATA_CENTER_MONITORING.md](DATA_CENTER_MONITORING.md).
3. SaaS ingestion patterns and examples are documented in [SAAS_INTEGRATION.md](SAAS_INTEGRATION.md).
4. End-to-end validation of the pipeline is packaged in [DEMO_SOLUTION.md](DEMO_SOLUTION.md) and the [demo](demo) folder.

The current demo package proves the pipeline across four sources:
- Azure Web App using Application Insights
- Azure Virtual Machine using Azure Monitor Agent and Data Collection Rules
- Data Center Virtual Machine using the hybrid monitoring pattern
- SaaS telemetry using Azure Functions and the Log Analytics Data Collector API

```
┌─────────────────────────────────────────────────────────────────┐
│                    TELEMETRY SOURCES                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  HTTP Applications        Data Center Workloads    SaaS Apps    │
│  ├─ ASP.NET/Node.js      ├─ Web servers (IIS)     ├─ Slack     │
│  ├─ Python/Java          ├─ Databases (SQL)       ├─ Salesforce│
│  ├─ Go/Rust              ├─ Background jobs       ├─ Datadog   │
│  └─ REST APIs            └─ Scheduled tasks       └─ GitHub    │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
                                  ↓
┌─────────────────────────────────────────────────────────────────┐
│              INGESTION CHANNELS & PROTOCOLS                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  App Insights SDK    Azure Monitor Agent    HTTP Collector API  │
│  ├─ Auto-instrument  ├─ DCR-based          ├─ REST POST       │
│  ├─ Events, metrics  ├─ Perf counters      ├─ Custom JSON     │
│  └─ Traces, deps     ├─ Event logs         └─ Shared key auth │
│                      └─ Custom logs                             │
│                                                                   │
│  Native Connectors   Azure Functions       Logic Apps          │
│  ├─ ServiceNow       ├─ Timer triggers     ├─ Scheduled        │
│  ├─ Microsoft 365    ├─ API polling        ├─ Webhook handlers │
│  └─ Datadog          └─ Transform & send   └─ SaaS orchestration
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
                                  ↓
┌─────────────────────────────────────────────────────────────────┐
│          AZURE MONITOR DATA INGESTION PLANE                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │        Azure Monitor Service (Ingestion Endpoints)         │ │
│  │                                                              │ │
│  │  Data Collection Service (DCS)                             │ │
│  │  ├─ Metrics ingestion (time-series)                        │ │
│  │  ├─ Logs ingestion (structured & unstructured)             │ │
│  │  ├─ Traces ingestion (distributed tracing)                 │ │
│  │  └─ Custom events (application-specific payloads)          │ │
│  │                                                              │ │
│  │  Data Transformation & Enrichment                          │ │
│  │  ├─ DCR-based filtering                                    │ │
│  │  ├─ Schema validation                                      │ │
│  │  ├─ Geo-IP enrichment (optional)                           │ │
│  │  └─ Field transformations (KQL-like)                       │ │
│  │                                                              │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
                                  ↓
┌─────────────────────────────────────────────────────────────────┐
│           LOG ANALYTICS WORKSPACE (STORAGE TIER)                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Tables (Auto-created or custom):                               │
│  ├─ AppTraces, AppRequests, AppDependencies (App Insights)      │
│  ├─ Perf, Event, Syslog (Azure Monitor Agent)                   │
│  ├─ W3CIISLog (IIS logs)                                        │
│  ├─ CustomMetrics_CL, CustomLogs_CL (HTTP Data Collector)       │
│  ├─ ServiceNow_CL, GitHub_CL, Stripe_CL (Connectors/APIs)       │
│  ├─ AlertLog, AuditLog (Platform logs)                          │
│  └─ [Your custom tables]                                        │
│                                                                   │
│  Retention Policies (per table):                                │
│  ├─ Hot storage: 30-90 days                                     │
│  ├─ Tiered storage: 180-365 days                                │
│  └─ Archive (optional): 1-7 years                               │
│                                                                   │
│  Query & Analysis Layer (KQL)                                   │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
                                  ↓
┌─────────────────────────────────────────────────────────────────┐
│          CONSUMPTION & ANALYTICS LAYER                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Dashboards          Alerts              Workbooks              │
│  ├─ Workbooks        ├─ Metric alerts    ├─ Multi-step         │
│  ├─ Grafana          ├─ Log alerts       ├─ Interactive        │
│  └─ Custom apps      └─ Anomaly detect   └─ Automated          │
│                                                                   │
│  Exports & Integrations                                         │
│  ├─ Power BI (semantic models)                                  │
│  ├─ Splunk (forwarding connectors)                              │
│  ├─ SIEM (Azure Sentinel)                                       │
│  └─ External BI tools (via API)                                 │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## Ingestion Methods by Source Type

### 1. HTTP Applications → Application Insights → Log Analytics

**Recommended for**: .NET, Java, Node.js, Python, Go web applications

**Technology Stack**:
- **Application Insights SDK** (or Codeless Agent for .NET)
- **Instrumentation Provider**: Auto-instrumentation where available
- **Transport**: HTTPS to Azure Monitor ingestion endpoint
- **Data Types**: Requests, dependencies, exceptions, custom events, metrics

**Implementation**:
```csharp
// Auto-instrumentation (preferred)
services.AddApplicationInsightsTelemetry(options => {
    options.InstrumentationKey = config["ApplicationInsights:InstrumentationKey"];
});

// Or manual for custom events
using Microsoft.ApplicationInsights;
var telemetryClient = new TelemetryClient();
telemetryClient.TrackEvent("OrderProcessed", 
    properties: new Dictionary<string, string> { {"OrderId", "123"} },
    metrics: new Dictionary<string, double> { {"Amount", 99.99} }
);
```

**Flow**:
```
Application → App Insights SDK → Azure Monitor Ingestion → Log Analytics
                                   (ods.opinsights.azure.com)
```

**Latency**: 30–60 seconds  
**Cost**: Included in Log Analytics ingestion

---

### 2. On-Premises Data Center Workloads → Azure Monitor Agent → Log Analytics

**Recommended for**: Windows/Linux servers running web apps, databases, background jobs

**Technology Stack**:
- **Azure Arc Agent** (server onboarding)
- **Azure Monitor Agent (AMA)** (data collection)
- **Data Collection Rules (DCRs)** (configuration)
- **Transport**: HTTPS outbound to Azure Monitor endpoints

**Implementation**:
```bicep
// Deploy AMA via policy
resource dataCollectionRule 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: 'dcr-webservers'
  location: location
  properties: {
    dataSources: {
      performanceCounters: [
        {
          name: 'cpuMemory'
          counterSpecifiers: [
            '\\Processor(_Total)\\% Processor Time'
            '\\Memory\\% Committed Bytes In Use'
          ]
          scheduledTransferPeriod: 'PT1M'
        }
      ]
    }
    destinations: {
      logAnalytics: [
        {
          name: 'workspace'
          workspaceResourceId: workspaceId
        }
      ]
    }
    dataFlows: [
      {
        streams: ['Microsoft-Perf']
        destinations: ['workspace']
      }
    ]
  }
}
```

**Flow**:
```
Data Center Server → Azure Arc → Azure Monitor Agent → Azure Monitor Service → Log Analytics
                                      (Outbound HTTPS only)
```

**Latency**: 1–5 minutes (configurable per DCR)  
**Cost**: Free agent + Log Analytics ingestion

---

### 3. SaaS Applications → Multiple Ingestion Channels

#### 3a. Synthetic Monitoring (Application Insights)

**Recommended for**: Public APIs, status pages, availability monitoring

```json
{
  "type": "Microsoft.Insights/webtests",
  "apiVersion": "2022-04-01",
  "name": "salesforce-api-test",
  "properties": {
    "locations": [{"id": "/subscriptions/.../providers/Microsoft.Location/locations/eastus"}],
    "kind": "synthetic",
    "frequency": 300,
    "timeout": 30,
    "request": {
      "url": "https://instance.salesforce.com/services/data/v57.0/limits",
      "httpMethod": "GET",
      "headers": [{"name": "Authorization", "value": "Bearer {{token}}"}]
    }
  }
}
```

**Flow**: Synthetic test → App Insights → Log Analytics (availabilityResults table)

---

#### 3b. HTTP Data Collector API

**Recommended for**: Custom telemetry, webhook integrations, API polling results

**Technology Stack**:
- **Log Analytics Data Collector API** (v2016-04-01)
- **HTTPS POST** with HMAC-SHA256 signature
- **Custom tables** (_CL suffix)

**Implementation**:
```python
# Python example: Send Stripe metrics
import requests
import hmac
import hashlib
import base64
import json
from datetime import datetime

def send_to_log_analytics(workspace_id, shared_key, table_name, data):
    url = f"https://{workspace_id}.ods.opinsights.azure.com/api/logs?api-version=2016-04-01"
    
    # Prepare payload
    payload = json.dumps(data)
    content_length = len(payload.encode('utf-8'))
    
    # Generate signature
    timestamp = datetime.utcnow().strftime('%a, %d %b %Y %H:%M:%S GMT')
    string_to_sign = f"POST\n{content_length}\napplication/json\nx-ms-date:{timestamp}\n/api/logs"
    
    signature = base64.b64encode(
        hmac.new(
            base64.b64decode(shared_key),
            string_to_sign.encode('utf-8'),
            hashlib.sha256
        ).digest()
    ).decode('utf-8')
    
    headers = {
        "Authorization": f"SharedKey {workspace_id}:{signature}",
        "Content-Type": "application/json",
        "Log-Type": table_name,
        "x-ms-date": timestamp,
        "x-ms-AzureCloud": "AzurePublicCloud"
    }
    
    response = requests.post(url, data=payload, headers=headers)
    return response.status_code

# Send Stripe charge metrics
send_to_log_analytics(
    workspace_id="workspace-uuid",
    shared_key="shared-key-base64",
    table_name="StripeMetrics_CL",
    data={
        "charges": 150,
        "revenue": 3500.00,
        "failed_charges": 3,
        "currency": "USD"
    }
)
```

**Flow**: Your app/script → HTTP POST → Log Analytics REST endpoint → Log Analytics table

---

#### 3c. Azure Functions + Timer Trigger (API Polling)

**Recommended for**: SaaS REST APIs with scheduled polling

**Technology Stack**:
- **Azure Functions** (Node.js, Python, C#)
- **Timer Trigger** (schedule: "0 */5 * * * *" for every 5 minutes)
- **HTTP Data Collector API** (for ingestion)

**Implementation**:
```javascript
// JavaScript example: Poll GitHub API
const axios = require('axios');
const https = require('https');
const crypto = require('crypto');

module.exports = async function(context, timer) {
    // Fetch from GitHub API
    const repos = await axios.get('https://api.github.com/user/repos', {
        headers: { 'Authorization': `Bearer ${process.env.GITHUB_TOKEN}` }
    });
    
    const metrics = {
        repo_count: repos.data.length,
        active_repos: repos.data.filter(r => !r.archived).length,
        total_stars: repos.data.reduce((sum, r) => sum + r.stargazers_count, 0),
        timestamp: new Date().toISOString()
    };
    
    // Send to Log Analytics
    await sendToLogAnalytics('GitHubMetrics_CL', [metrics]);
};

async function sendToLogAnalytics(tableName, data) {
    const workspaceId = process.env.WORKSPACE_ID;
    const sharedKey = Buffer.from(process.env.SHARED_KEY, 'base64');
    
    const payload = JSON.stringify(data);
    const contentLength = Buffer.byteLength(payload);
    const timestamp = new Date().toUTCString();
    
    const stringToSign = `POST\n${contentLength}\napplication/json\nx-ms-date:${timestamp}\n/api/logs`;
    const signature = crypto.createHmac('sha256', sharedKey).update(stringToSign).digest('base64');
    
    const options = {
        hostname: `${workspaceId}.ods.opinsights.azure.com`,
        port: 443,
        path: '/api/logs?api-version=2016-04-01',
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Content-Length': contentLength,
            'Log-Type': tableName,
            'Authorization': `SharedKey ${workspaceId}:${signature}`,
            'x-ms-date': timestamp
        }
    };
    
    return new Promise((resolve, reject) => {
        const req = https.request(options, res => {
            res.on('data', () => {});
            res.on('end', () => resolve(res.statusCode));
        });
        req.on('error', reject);
        req.write(payload);
        req.end();
    });
}
```

**Flow**: Timer Trigger → Fetch SaaS API → Transform → HTTP Data Collector API → Log Analytics

**Latency**: 5–60 minutes (based on schedule)  
**Cost**: ~$1–5/month per function

---

#### 3d. Logic Apps + Webhook

**Recommended for**: Real-time SaaS alerts, event-driven ingestion

**Technology Stack**:
- **Logic Apps** (no-code/low-code orchestration)
- **Webhook trigger** (receives push events)
- **HTTP action** (calls Log Analytics API)

**Implementation**:
```json
{
  "triggers": {
    "When_a_webhook_request_is_received": {
      "type": "Request",
      "kind": "Http",
      "inputs": {
        "schema": {
          "type": "object",
          "properties": {
            "alert_id": {"type": "string"},
            "severity": {"type": "string"},
            "message": {"type": "string"}
          }
        }
      }
    }
  },
  "actions": {
    "Send_to_Log_Analytics": {
      "type": "Http",
      "inputs": {
        "method": "POST",
        "uri": "https://@{variables('workspace_id')}.ods.opinsights.azure.com/api/logs?api-version=2016-04-01",
        "headers": {
          "Log-Type": "SaaSAlerts_CL",
          "x-ms-date": "@{utcNow()}",
          "Authorization": "@{variables('auth_header')}"
        },
        "body": {
          "alert_id": "@{triggerBody().alert_id}",
          "severity": "@{triggerBody().severity}",
          "message": "@{triggerBody().message}",
          "received_at": "@{utcNow()}"
        }
      }
    }
  }
}
```

**Flow**: SaaS webhook → Logic App webhook trigger → Parse event → HTTP Data Collector API → Log Analytics

**Latency**: <1 second  
**Cost**: Pay-per-invocation (~$0.000025 per action)

---

#### 3e. Native Connectors

**Recommended for**: Enterprise SaaS with native Azure integrations (ServiceNow, Microsoft 365, Dynamics, Datadog)

**Technology Stack**:
- **Azure Connectors** (pre-built integrations)
- **Managed Identity** (authentication)
- **Automatic mapping** to Log Analytics tables

**Implementation**:
```bicep
// Deploy ServiceNow connector
resource servicenowConnector 'Microsoft.OperationalInsights/workspaces/dataConnectors@2021-10-01-preview' = {
  parent: workspace
  name: 'ServiceNow'
  properties: {
    kind: 'ServiceNow'
    connectorDefinitionId: 'ServiceNow'
    dataTypes: {
      incidents: {
        state: 'Enabled'
      }
      changeManagement: {
        state: 'Enabled'
      }
    }
    tenantId: subscription().tenantId
    apiToken: servicenowApiToken
  }
}
```

**Flow**: SaaS system → Native connector → Log Analytics (pre-configured tables)

**Latency**: 5–30 minutes  
**Cost**: Included in Log Analytics ingestion

---

## Technology Stack Recommendations

| Layer | Technology | Pros | Cons | Use Case |
|-------|-----------|------|------|----------|
| **Application Instrumentation** | Application Insights SDK | Zero-config, auto-instrumentation, rich telemetry | Language-specific overhead | HTTP apps (.NET, Java, Node.js) |
| | OpenTelemetry SDK | Multi-language, cloud-native standard | Requires manual setup, less Azure integration | Polyglot environments, Kubernetes |
| | AppDynamics/Dynatrace collectors | Enterprise APM, advanced features | Cost, vendor lock-in | Large-scale enterprises |
| **Infrastructure Collection** | Azure Monitor Agent | Native Azure, DCR-driven, free | Windows/Linux only | On-premises/hybrid servers |
| | Telegraf | Multi-platform, lightweight, plugin-based | Requires configuration, separate agent | Linux-heavy environments |
| | Datadog/New Relic agents | Rich features, vendor dashboards | Expensive, vendor lock-in | Existing Datadog/NR customers |
| **SaaS Ingestion** | HTTP Data Collector API | Simple, no dependencies, low cost, flexible | Manual auth, needs custom code | Custom SaaS, APIs without connectors |
| | Azure Functions | Serverless, scalable, pay-per-use | Cold starts, limited compute | Scheduled polling, lightweight transforms |
| | Logic Apps | Low-code, visual, webhook-capable | Limited compute, vendor-specific | Business users, webhook integration |
| | Azure Data Factory | Enterprise ETL, complex transforms | Overkill for simple ingestion, cost | Data warehousing, heavy transforms |
| **Messaging & Buffering** | Event Hubs | High-throughput, auto-scaling, built-in partitioning | Complexity, additional cost | High-volume real-time streaming |
| | Service Bus | Guaranteed delivery, FIFO, DLQ support | Latency, cost per message | Mission-critical, ordered processing |
| | Storage Queue | Simple, cheap, reliable | No ordering guarantees, latency | Batch ingestion, non-critical data |

**Recommended Stack for Most Orgs**:
```
HTTP Apps         → Application Insights SDK
Data Center       → Azure Arc + Azure Monitor Agent
Simple SaaS       → HTTP Data Collector API (direct or Functions)
Complex SaaS      → Logic Apps or native connectors
Real-time alerts  → Webhooks + Logic Apps
```

---

## Reference Architecture: End-to-End Flow

### Scenario: E-Commerce Platform Monitoring

```
┌─ Web Frontend (ASP.NET Core) →─┐
│                                  │
├─ API Backend (Node.js) →────────┤        ┌─ Log Analytics Workspace ─┐
│                                  ├──────→ │                           │
├─ Database Server (SQL Server) ──┤        │  ├─ AppRequests            │
│  (data center) → Arc/AMA         │        │  ├─ AppDependencies       │
│                                  │        │  ├─ Perf (Windows Server) │
├─ Payment SaaS (Stripe) ─────────┤        │  ├─ StripeMetrics_CL      │
│  (Timer function → HTTP API)     │        │  ├─ SlackAlerts_CL        │
│                                  │        │  └─ W3CIISLog             │
└─ Slack Webhooks ────────────────┤        │                           │
   (Logic App webhook)             │        └──────────────────────────┘
       ↓                            │              ↓
       └────────────────────────────┘         KQL Queries
                                              Dashboard
                                              Alerts
```

---

## Implementation Phases

### Phase 0: Assess Existing Data Sources
- Inventory all applications (web, database, jobs, SaaS)
- Determine ingestion method per source
- Estimate total data volume (GB/day)

### Phase 1: Deploy Foundation
- Create Log Analytics Workspace
- Deploy Bicep infrastructure
- Configure RBAC and retention policies

### Phase 2: Onboard Priority Applications
- HTTP apps: Application Insights SDK
- Data center servers: Arc + AMA
- 1-2 critical SaaS sources

### Phase 3: Build Dashboards & Alerts
- Create KQL queries
- Publish Workbooks
- Configure alert rules

### Phase 4: Scale & Optimize
- Onboard remaining SaaS sources
- Optimize data ingestion costs
- Automate runbook workflows

## Deployment and Validation Assets

Use the following repository assets to move from pipeline design to execution:

1. [DEMO_SOLUTION.md](DEMO_SOLUTION.md) for the end-to-end walkthrough and validation queries.
2. [demo/deploy-demo.ps1](demo/deploy-demo.ps1) for automated deployment of the demo environment.
3. [demo/DEPLOYMENT_REFERENCE.md](demo/DEPLOYMENT_REFERENCE.md) for the shortest deployment path and validation sequence.
4. [demo/TROUBLESHOOTING.md](demo/TROUBLESHOOTING.md) for diagnosis of ingestion gaps, agent issues, and Function App configuration problems.
5. [demo/dcr-azure-vm.json](demo/dcr-azure-vm.json) and [demo/dcr-datadc-vm.json](demo/dcr-datadc-vm.json) for Azure and hybrid VM collection rules.
6. [demo/azure-function-github-metrics.js](demo/azure-function-github-metrics.js) for the SaaS polling implementation.
7. [demo/workbook-template.json](demo/workbook-template.json) and [demo/demo-alerts.json](demo/demo-alerts.json) for pipeline validation and operational monitoring.

---

## Cost Model

| Source Type | Avg Data/Day | Monthly Cost |
|---|---|---|
| HTTP Application (small) | 0.5 GB | $3–5 |
| Data Center Server (baseline) | 0.3 GB | $2–3 |
| SaaS (via HTTP Data Collector) | 0.05 GB | $0.50 |
| **Total (10 apps + 5 servers + 5 SaaS)** | ~6 GB | ~$40–60 |

---

## Monitoring the Ingestion Pipeline Itself

Create alerts for pipeline health:

```kusto
// Alert if data is missing from a source
union *
| where TimeGenerated > ago(1h)
| summarize LastDataTime = max(TimeGenerated) by Type
| where LastDataTime < ago(30m)
| project Source = Type, LastDataTime, Status = "Data Gap"
```

---

## Next Steps

1. **Review this pipeline** against your specific application inventory.
2. **Choose ingestion methods** per source type and map each source to one of the patterns in this document.
3. **Validate infrastructure costs** using Azure Pricing Calculator.
4. **Use the demo assets** to validate the target ingestion path before onboarding production workloads.
5. **Proceed to Phase 1** of implementation using the monitoring foundation and demo deployment assets already included in the repository.

---

**Last Updated**: March 25, 2026  
**Version**: 1.0.0
