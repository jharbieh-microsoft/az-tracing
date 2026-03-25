# SaaS Integration and Monitoring Guide

Practical guidance for monitoring external SaaS applications with Azure Monitor when you have HTTP/internet-only access.

## Overview

Most SaaS platforms expose monitoring data through one of five integration patterns. This guide shows how to implement each, with step-by-step examples for popular platforms.

**Why monitor SaaS?**
- Detect service degradation before customer impact
- Correlate SaaS outages with application failures in your Log Analytics workspace
- Create centralized dashboards showing health across all dependencies
- Trigger alerts to on-call teams for critical incidents
- Maintain audit trail for compliance

## Pattern 1: Synthetic Monitoring (HTTP Health Checks)

**Use when**: You need simple availability/latency monitoring for HTTP endpoints or public APIs.

**Azure Service**: Application Insights Availability Tests

### Example: Monitor a SaaS API Endpoint

1. In Azure Portal, open your Application Insights resource
2. **Monitoring** → **Availability**
3. Create **Standard Test**:
   - **Test name**: Salesforce API Health Check
   - **URL**: `https://yourinstance.salesforce.com/services/data/v57.0/limits`
   - **Test frequency**: Every 5 minutes
   - **Locations**: East US, West Europe, Southeast Asia (minimum 3)
   - **Success criteria**:
     - HTTP status: 200
     - Response time: < 2000 ms

4. Results automatically flow to Log Analytics as `availabilityResults` table

### Query: Find SaaS Availability Issues

```kusto
availabilityResults
| where name == "Salesforce API Health Check"
| summarize availability = (todouble(sum(tolong(success))) / count()) * 100 by bin(timestamp, 5m)
| render timechart
```

### Alert: Trigger When Availability Falls Below 95%

1. In Application Insights, go to **Alerts** → **Create alert rule**
2. Condition: `availabilityResults | where name == "Salesforce API Health Check"` 
3. Custom Logic: 
   ```kusto
   availabilityResults
   | where name == "Salesforce API Health Check"
   | summarize availability = (todouble(sum(tolong(success))) / count()) * 100
   | where availability < 95
   ```
4. Alert action: Route to Action Group (email, Teams, webhook)

**Cost**: ~$0.50/month per synthetic test

---

## Pattern 2: Native Connectors

**Use when**: Your SaaS platform has a built-in Azure connector.

**Popular connectors**:
- Microsoft 365 (Exchange, Teams, SharePoint)
- Dynamics 365
- ServiceNow
- Datadog
- Salesforce
- Power BI

### Example: Ingest ServiceNow Incidents into Log Analytics

1. In your Log Analytics Workspace, go to **Data Connectors**
2. Search for and install **ServiceNow**
3. Configure:
   - ServiceNow instance URL: `https://yourinstance.service-now.com`
   - OAuth credentials (or API key)
   - Sync frequency: Every 5 minutes
   - Tables to ingest: `incident`, `change_request`, `problem`

4. Incidents appear in Log Analytics as `ServiceNow_CL` table (custom logs)

### Query: Active Incidents by Priority

```kusto
ServiceNow_CL
| where state_s != "Closed"
| summarize count() by priority_s, impact_s
| project Priority = priority_s, Impact = impact_s, Incident_Count = count_
| order by Priority asc
```

### Alert: Notify When P1 Incidents Spike

```kusto
ServiceNow_CL
| where priority_s == "1"  // P1 = Critical
| summarize incident_count = dcount(number_s) by bin(TimeGenerated, 15m)
| where incident_count > 5
```

**Cost**: Included in Log Analytics ingestion (typically $2–$5 per GB)

---

## Pattern 3: HTTP Data Collector API

**Use when**: You need to send custom telemetry from SaaS or scripts without a native connector.

**How it works**: 
- SaaS system or scheduled task POSTs JSON to a secured Azure endpoint
- Data appears in Log Analytics as custom table
- No 3rd-party connector needed

### Example: Ingest Stripe Payment Metrics

**Step 1: Create Custom Table in Log Analytics**

Via Azure CLI:
```bash
az monitor log-analytics workspace table create \
  -g rg-contoso-monitor-prod \
  -n law-contoso-prod \
  --name StripeMetrics_CL \
  --columns-param @- <<EOF
[
  {"name": "account_id", "type": "string"},
  {"name": "revenue", "type": "real"},
  {"name": "transaction_count", "type": "int"},
  {"name": "failed_charges", "type": "int"},
  {"name": "location", "type": "string"},
  {"name": "TimeGenerated", "type": "datetime"}
]
EOF
```

**Step 2: Get Data Collector Endpoint and Shared Key**

In Log Analytics Workspace → **Agents** → copy:
- **Workspace ID** (UUID)
- **Primary key** (shared secret)

**Step 3: Create PowerShell Script to Send Data**

```powershell
function Send-StripeMetricsToLogAnalytics {
    param(
        [string]$WorkspaceId,
        [string]$SharedKey,
        [hashtable]$Metrics
    )
    
    $TimeStamp = (Get-Date).ToUniversalTime() | Get-Date -Format "o"
    $Headers = @{
        "Log-Type" = "StripeMetrics_CL"
        "x-ms-date" = $TimeStamp
        "x-ms-AzureCloud" = "AzurePublicCloud"
    }
    
    # Build JSON payload
    $Payload = @{
        account_id = $Metrics.account_id
        revenue = $Metrics.revenue
        transaction_count = $Metrics.transaction_count
        failed_charges = $Metrics.failed_charges
        location = $Metrics.location
        TimeGenerated = $TimeStamp
    } | ConvertTo-Json
    
    # Generate HMAC-SHA256 signature
    $ContentLength = [System.Text.Encoding]::UTF8.GetByteCount($Payload)
    $StringToSign = "POST`n$ContentLength`napplication/json`n$($Headers.'x-ms-date')`n/api/logs"
    $HmacSha256 = New-Object System.Security.Cryptography.HMACSHA256
    $HmacSha256.Key = [Convert]::FromBase64String($SharedKey)
    $Signature = [Convert]::ToBase64String($HmacSha256.ComputeHash([Text.Encoding]::UTF8.GetBytes($StringToSign)))
    $Headers["Authorization"] = "SharedKey ${WorkspaceId}:$Signature"
    
    # Send to Log Analytics
    $Uri = "https://${WorkspaceId}.ods.opinsights.azure.com/api/logs?api-version=2016-04-01"
    Invoke-RestMethod -Uri $Uri -Method Post -Headers $Headers -Body $Payload -ContentType "application/json"
}

# Call the function with Stripe data (pulled from Stripe API)
$Metrics = @{
    account_id = "acct_1234567890"
    revenue = 15234.50
    transaction_count = 342
    failed_charges = 2
    location = "East US"
}

Send-StripeMetricsToLogAnalytics -WorkspaceId "YOUR_WORKSPACE_ID" -SharedKey "YOUR_SHARED_KEY" -Metrics $Metrics
```

**Step 4: Schedule the Script**

Create an Azure Automation runbook or Azure Function Timer trigger to run this script every 5 minutes.

### Query: Daily Revenue Trend

```kusto
StripeMetrics_CL
| summarize total_revenue = sum(revenue_d), avg_failed = avg(failed_charges_d) by bin(TimeGenerated, 1d)
| render timechart
```

**Cost**: ~$0.50–$1.00 per GB ingested (depends on metric volume)

---

## Pattern 4: Logic App or Function + API Polling

**Use when**: You want scheduled extraction from SaaS REST APIs without native connectors.

**Example: Poll GitHub API for Deployment Status**

### Create Logic App Workflow

1. Azure Portal → **Create Logic App**
2. **Recurrence trigger**: Every 30 minutes
3. **HTTP action**: GET `https://api.github.com/repos/{owner}/{repo}/deployments`
   - Headers: `Authorization: Bearer {github_token}`
4. **Parse JSON**: Extract deployment status, environment, timestamp
5. **Send HTTP POST to Log Analytics Data Collector API** (as shown in Pattern 3)

### Example Logic App JSON

```json
{
  "definition": {
    "$schema": "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#",
    "triggers": {
      "Recurrence": {
        "type": "Recurrence",
        "recurrence": {
          "frequency": "Minute",
          "interval": 30
        }
      }
    },
    "actions": {
      "Get_GitHub_Deployments": {
        "type": "Http",
        "inputs": {
          "method": "GET",
          "uri": "https://api.github.com/repos/@{variables('repo_owner')}/@{variables('repo_name')}/deployments",
          "headers": {
            "Authorization": "Bearer @{variables('github_token')}",
            "Accept": "application/vnd.github.v3+json"
          }
        }
      },
      "Parse_JSON": {
        "type": "ParseJson",
        "inputs": {
          "content": "@body('Get_GitHub_Deployments')",
          "schema": {
            "type": "array",
            "items": {
              "type": "object",
              "properties": {
                "id": {"type": "integer"},
                "status": {"type": "string"},
                "environment": {"type": "string"},
                "created_at": {"type": "string"}
              }
            }
          }
        }
      },
      "For_each_deployment": {
        "type": "Foreach",
        "foreach": "@body('Parse_JSON')",
        "actions": {
          "Send_to_Log_Analytics": {
            "type": "Http",
            "inputs": {
              "method": "POST",
              "uri": "https://@{variables('workspace_id')}.ods.opinsights.azure.com/api/logs?api-version=2016-04-01",
              "headers": {
                "Log-Type": "GitHubDeployments_CL",
                "x-ms-date": "@{utcNow()}",
                "Authorization": "@{variables('auth_header')}"
              },
              "body": {
                "deployment_id": "@{items('For_each_deployment').id}",
                "status": "@{items('For_each_deployment').status}",
                "environment": "@{items('For_each_deployment').environment}",
                "created_at": "@{items('For_each_deployment').created_at}"
              }
            }
          }
        }
      }
    }
  }
}
```

### Query: Deployment Success Rate

```kusto
GitHubDeployments_CL
| summarize success_rate = (todouble(countif(status_s == "success")) / count()) * 100 
           by environment_s, bin(TimeGenerated, 1d)
| render columnchart
```

**Cost**: ~$2–$5/month per Logic App (depending on execution frequency)

---

## Pattern 5: Webhook Integration for Real-Time Alerts

**Use when**: SaaS platform sends alerts/events in real-time and you need immediate action.

**Example: Slack security alerts to Azure**

### Create Logic App Webhook Endpoint

1. Azure Portal → **Create Logic App**
2. **Trigger**: When an HTTP request is received
   - Generate schema from sample webhook payload
3. **Actions**:
   - Parse the webhook JSON
   - Extract alert severity, topic, timestamp
   - Send to Log Analytics
   - Route high-severity alerts to Action Group

### Slack to Azure Example

**Slack configuration**:
1. Create Slack App → **Event Subscriptions**
2. Enable request URL verification
3. Subscribe to `message.channels`, `app_mention` events
4. Request URL: Your Logic App HTTP POST trigger URL

**Logic App**:
```json
{
  "trigger": {
    "type": "Request",
    "kind": "Http",
    "inputs": {
      "schema": {
        "type": "object",
        "properties": {
          "event": {
            "type": "object",
            "properties": {
              "type": {"type": "string"},
              "text": {"type": "string"},
              "channel": {"type": "string"},
              "user": {"type": "string"}
            }
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
        "uri": "https://@{variables('workspace_id')}.ods.opinsights.azure.com/api/logs",
        "body": {
          "event_type": "@{body('trigger').event.type}",
          "text": "@{body('trigger').event.text}",
          "channel": "@{body('trigger').event.channel}",
          "user": "@{body('trigger').event.user}",
          "timestamp": "@{utcNow()}"
        }
      }
    }
  }
}
```

**Cost**: ~$1–$3/month per webhook endpoint

---

## Implementation Checklist

### For Each SaaS Application

- [ ] Identify available integration patterns (native connector, API, webhook, synthetic test)
- [ ] Choose pattern based on latency requirements, cost, and complexity
- [ ] Create custom Log Analytics table if needed
- [ ] Implement data ingestion (connector, Logic App, Function, or synthetic test)
- [ ] Test data flow (run once, verify custom table populated)
- [ ] Create KQL queries for dashboards and troubleshooting
- [ ] Configure alerts on critical metrics
- [ ] Document SaaS integration in runbook (for on-call teams)
- [ ] Monitor data ingestion costs (set daily caps if needed)

---

## Cost Optimization Tips

1. **Filter at source**: Only ingest critical metrics, not all API data
2. **Batch updates**: Collect data for 5–10 minutes, then send once
3. **Use table retention policies**: Delete old SaaS data after 7–30 days if not compliance-critical
4. **Prefer webhooks over polling**: Real-time webhooks are more cost-effective than frequent API polls
5. **Consolidate custom tables**: If monitoring 10 SaaS apps, use fewer large tables rather than many small ones

Example: **GitHub + Stripe + Salesforce**
- Synthetic monitoring (GitHub uptime): $0.50/month
- Stripe API polling (Logic App): $2/month
- Stripe metrics (100 MB/month ingestion): $2/month
- Salesforce connector (400 MB/month): $4/month
- **Total**: ~$9/month

---

## Troubleshooting

| Problem | Cause | Solution |
|---------|-------|----------|
| Data not appearing in custom table | Auth failure, wrong endpoint | Check workspace ID, shared key, and table name |
| Synthetic test failing intermittently | SaaS API throttling, network issues | Increase test frequency threshold, use multiple regions |
| High latency in Logic App polling | API response time, integration overhead | Add caching, reduce payload size, increase poll interval |
| Webhook not receiving data | Incorrect URL, auth headers missing | Re-verify webhook URL, check SaaS platform logs |

---

## Related Documentation

- [Technical Architecture](TECHNICAL_ARCHITECTURE.md) — SaaS integration patterns section
- [Implementation Plan](IMPLEMENTATION_PLAN.md) — Phase 4: SaaS onboarding
- [Azure Monitor Data Collector API](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/data-collector-api) — Official reference
- [Application Insights Availability Tests](https://learn.microsoft.com/en-us/azure/azure-monitor/app/availability-overview) — Detailed guide

---

**Last Updated**: March 25, 2026  
**Version**: 1.0.0
