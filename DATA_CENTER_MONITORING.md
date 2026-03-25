# Data Center Application Monitoring Guide

Comprehensive guidance for monitoring applications running on Windows and Linux servers in your on-premises data centers with Azure Arc and Azure Monitor.

## Overview

This guide covers monitoring the full range of server-based applications:
- HTTP/REST web applications
- Relational and NoSQL databases
- Background jobs and queue processors
- Scheduled tasks and cron jobs
- System infrastructure (CPU, memory, disk, network)

All data flows to your centralized Log Analytics Workspace for correlation, alerting, and dashboard visibility.

## Architecture

```
On-Premises Data Center
    ↓
[Windows/Linux Servers]
    ↓
[Azure Arc Connected Machine Agent]
    ↓
[Azure Monitor Agent (AMA) + Data Collection Rules]
    ↓
[Azure Monitor → Log Analytics Workspace]
    ↓
[Alerts, Dashboards, KQL Queries]
```

---

## Step 1: Azure Arc Onboarding

Before you can deploy Azure Monitor Agent, servers must be registered with Azure Arc.

### Prerequisites

- Azure subscription
- Azure resource group for Arc machines (e.g., `rg-arc-datacenters`)
- Outbound HTTPS connectivity to Azure (port 443)
- Supported OS versions:
  - **Windows**: Server 2012 R2, 2016, 2019, 2022
  - **Linux**: RHEL 7+, Ubuntu 18.04+, CentOS 7+, SLES 12+, Debian 10+

### Option A: Install Arc Agent via Script (Windows)

```powershell
# Download the Arc installation script
$ProgressPreference = "SilentlyContinue"
Invoke-WebRequest -Uri "https://aka.ms/arcagentwinscript" -OutFile "AzureConnectedMachineAgent.msi"

# Run the installer
msiexec.exe /i AzureConnectedMachineAgent.msi /l*v installationlog.txt

# Register with Azure Arc
$token = az account get-access-token --query accessToken -o tsv
& "$env:ProgramFiles\AzureConnectedMachineAgent\azcmagent.exe" connect `
  --service-principal-id "<SERVICE_PRINCIPAL_ID>" `
  --service-principal-secret "<SERVICE_PRINCIPAL_SECRET>" `
  --resource-group "rg-arc-datacenters" `
  --tenant-id "<TENANT_ID>" `
  --location "eastus" `
  --tags "datacenter=dc1" "environment=prod" "application=web-farm"
```

### Option B: Install Arc Agent via Bash (Linux)

```bash
# Download the Arc installation script
wget https://aka.ms/dependencyagentlinux -O InstallDependencyAgent-Linux64.bin

# Run the installer
sudo sh InstallDependencyAgent-Linux64.bin -s

# Install Azure Monitor Agent
wget https://aka.ms/dependencyagentlinux -O AzureMonitoringAgent.sh
sudo bash AzureMonitoringAgent.sh

# Register with Azure Arc
/opt/azcmagent/bin/azcmagent connect \
  --service-principal-id "<SERVICE_PRINCIPAL_ID>" \
  --service-principal-secret "<SERVICE_PRINCIPAL_SECRET>" \
  --resource-group "rg-arc-datacenters" \
  --tenant-id "<TENANT_ID>" \
  --location "eastus" \
  --tags datacenter=dc1 environment=prod application=web-farm
```

### Verify Arc Connection

```bash
# Windows
& "$env:ProgramFiles\AzureConnectedMachineAgent\azcmagent.exe" show

# Linux
azcmagent show
```

Expected output should show `Agent Status: Connected`.

---

## Step 2: Deploy Azure Monitor Agent (AMA)

Once Arc is active, deploy Azure Monitor Agent using Bicep, Azure Policy, or portal.

### Option A: Deploy via Bicep (Recommended for IaC)

```bicep
param location string = 'eastus'
param arcMachineResourceId string
param workspaceResourceId string
param dcrResourceId string

// Azure Monitor Agent extension on Arc machine
resource ama 'Microsoft.HybridCompute/machines/extensions@2023-06-20-preview' = {
  name: '${last(split(arcMachineResourceId, '/'))}/AzureMonitorWindowsAgent'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorWindowsAgent'
    typeHandlerVersion: '1.12'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
  }
}

// Associate machine with Data Collection Rule
resource dcrAssociation 'Microsoft.Insights/dataCollectionRuleAssociations@2022-06-01' = {
  scope: arc_machine
  name: 'dcr-web-apps'
  properties: {
    dataCollectionRuleId: dcrResourceId
    description: 'Collect web application logs and metrics'
  }
}
```

### Option B: Deploy via Azure Policy

Policy automatically deploys AMA to all Arc machines in a resource group:

```json
{
  "policyDefinitionId": "/subscriptions/{subId}/providers/Microsoft.Authorization/policyDefinitions/Deploy-AMA-Windows-Arc",
  "parameters": {
    "workspaceResourceId": {
      "value": "/subscriptions/{subId}/resourceGroups/{rg}/providers/Microsoft.OperationalInsights/workspaces/{workspaceName}"
    },
    "dcrResourceId": {
      "value": "/subscriptions/{subId}/resourceGroups/{rg}/providers/Microsoft.Insights/dataCollectionRules/dcr-web-apps"
    }
  },
  "metadata": {
    "category": "Azure Monitor"
  }
}
```

Apply via:
```bash
az policy assignment create \
  --name "deploy-ama-arc" \
  --scope "/subscriptions/{subId}/resourceGroups/rg-arc-datacenters" \
  --policy "path/to/policy.json"
```

### Option C: Deploy via Portal

1. Azure Portal → **Arc Machines** → Select machine
2. **Extensions** → **Add**
3. Choose **Azure Monitor Agent** for Windows or Linux
4. Configure and deploy

---

## Step 3: Create Data Collection Rules (DCRs)

Data Collection Rules define what to collect and where to send it.

### DCR 1: Web Application Monitoring (Windows)

```json
{
  "type": "Microsoft.Insights/dataCollectionRules",
  "apiVersion": "2022-06-01",
  "name": "dcr-webapp-windows",
  "location": "eastus",
  "properties": {
    "description": "Collect IIS logs, application logs, and system metrics from web servers",
    "dataSources": {
      "windowsEventLogs": [
        {
          "name": "eventLogsDataSource",
          "streams": ["Microsoft-Event"],
          "scheduledTransferPeriod": "PT5M",
          "logNames": [
            "Application",
            "System",
            "Security"
          ],
          "xPathQueries": [
            "Application!*[System[(EventID=1000 or EventID=1001)]]",
            "System!*[System[(EventID=7036 or EventID=7040)]]"
          ]
        }
      ],
      "performanceCounters": [
        {
          "name": "perfCountersDataSource",
          "streams": ["Microsoft-Perf"],
          "scheduledTransferPeriod": "PT1M",
          "counterSpecifiers": [
            "\\Processor(_Total)\\% Processor Time",
            "\\Memory\\% Committed Bytes In Use",
            "\\PhysicalDisk(_Total)\\% Disk Time",
            "\\PhysicalDisk(_Total)\\Avg. Disk Queue Length",
            "\\Network Interface(*)\\Bytes Received/sec",
            "\\Network Interface(*)\\Bytes Sent/sec",
            "\\Web Service(_Total)\\Current Connections",
            "\\Web Service(_Total)\\Get Requests/sec",
            "\\ASP.NET Applications(_Total)\\Request Execution Time"
          ]
        }
      ],
      "logFiles": [
        {
          "name": "iisLogsDataSource",
          "streams": ["Microsoft-W3CIISLog"],
          "filePatterns": [
            "C:\\inetpub\\logs\\LogFiles\\W3SVC1\\u_*.log"
          ],
          "format": "text",
          "collectFromAllDirectories": false,
          "scheduledTransferPeriod": "PT5M"
        }
      ]
    },
    "destinations": {
      "logAnalytics": [
        {
          "name": "dataCollectionEvent",
          "workspaceResourceId": "/subscriptions/{subId}/resourceGroups/{rg}/providers/Microsoft.OperationalInsights/workspaces/{workspaceName}"
        }
      ]
    },
    "dataFlows": [
      {
        "streams": ["Microsoft-Event", "Microsoft-Perf", "Microsoft-W3CIISLog"],
        "destinations": ["dataCollectionEvent"]
      }
    ]
  }
}
```

### DCR 2: Database Server Monitoring (Windows SQL Server)

```json
{
  "name": "dcr-database-sqlserver",
  "properties": {
    "dataSources": {
      "windowsEventLogs": [
        {
          "name": "sqlServerEventLogs",
          "scheduledTransferPeriod": "PT5M",
          "logNames": [
            "Application",
            "System"
          ],
          "xPathQueries": [
            "Application!*[System[(EventID>=17000 and EventID<=17999)]]"
          ]
        }
      ],
      "performanceCounters": [
        {
          "name": "sqlServerPerfCounters",
          "scheduledTransferPeriod": "PT1M",
          "counterSpecifiers": [
            "\\SQLServer:General Statistics\\User Connections",
            "\\SQLServer:SQL Statistics\\Batch Requests/sec",
            "\\SQLServer:SQL Statistics\\SQL Compilations/sec",
            "\\SQLServer:Buffer Manager\\Buffer Cache Hit Ratio",
            "\\SQLServer:Memory Manager\\Total Server Memory (KB)",
            "\\SQLServer:Locks(_Total)\\Lock Waits/sec",
            "\\SQLServer:Databases(_Total)\\Data File(s) Size (KB)"
          ]
        }
      ]
    },
    "destinations": {
      "logAnalytics": [
        {
          "name": "workspace",
          "workspaceResourceId": "/subscriptions/{subId}/resourceGroups/{rg}/providers/Microsoft.OperationalInsights/workspaces/{workspaceName}"
        }
      ]
    },
    "dataFlows": [
      {
        "streams": ["Microsoft-Event", "Microsoft-Perf"],
        "destinations": ["workspace"]
      }
    ]
  }
}
```

### DCR 3: Linux Application Monitoring

```json
{
  "name": "dcr-linux-apps",
  "properties": {
    "dataSources": {
      "syslog": [
        {
          "name": "syslogDataSource",
          "streams": ["Microsoft-Syslog"],
          "facilityNames": ["auth", "authpriv", "cron", "daemon", "mark", "news", "syslog", "user", "uucp", "local0", "local7"],
          "logLevels": ["Debug", "Info", "Notice", "Warning", "Error", "Critical", "Alert", "Emergency"],
          "scheduledTransferPeriod": "PT5M"
        }
      ],
      "performanceCounters": [
        {
          "name": "linuxPerfCounters",
          "streams": ["Microsoft-Perf"],
          "scheduledTransferPeriod": "PT1M",
          "counterSpecifiers": [
            "\\Processor\\% Processor Time",
            "\\Memory\\% Used Memory",
            "\\LogicalDisk(_Total)\\% Used Inodes",
            "\\LogicalDisk(_Total)\\% Used Space",
            "\\NetworkInterface(*)\\Bytes Received/sec",
            "\\NetworkInterface(*)\\Bytes Transmitted/sec"
          ]
        }
      ],
      "logFiles": [
        {
          "name": "applicationLogsLinux",
          "streams": ["Microsoft-TextLog"],
          "filePatterns": [
            "/var/log/apache2/error.log",
            "/var/log/nginx/error.log",
            "/var/log/app/application*.log"
          ],
          "format": "text",
          "scheduledTransferPeriod": "PT5M"
        }
      ]
    },
    "destinations": {
      "logAnalytics": [
        {
          "name": "workspace",
          "workspaceResourceId": "/subscriptions/{subId}/resourceGroups/{rg}/providers/Microsoft.OperationalInsights/workspaces/{workspaceName}"
        }
      ]
    },
    "dataFlows": [
      {
        "streams": ["Microsoft-Syslog", "Microsoft-Perf", "Microsoft-TextLog"],
        "destinations": ["workspace"]
      }
    ]
  }
}
```

---

## Step 4: Application-Specific Instrumentation

### Web Applications (IIS, Apache, Nginx)

**Option A: Automatic instrumentation (Recommended)**

For .NET applications in IIS, enable **Codeless Application Monitoring**:

```bicep
// Deploy Application Insights Codeless Agent to IIS
resource appInsightsExtension 'Microsoft.HybridCompute/machines/extensions@2023-06-20-preview' = {
  name: '${arcMachineName}/ApplicationInsightsWindowsAgent'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'ApplicationInsightsWindowsAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
  }
}
```

**Option B: Manual SDK instrumentation**

For .NET applications:
```csharp
using Microsoft.ApplicationInsights;
using Microsoft.ApplicationInsights.DataContracts;

public class Program
{
    static TelemetryClient telemetryClient = new();

    public static void Main()
    {
        // Track custom events
        telemetryClient.TrackEvent("ApplicationStarted");
        
        // Track metrics
        telemetryClient.GetMetric("RequestDuration").TrackValue(250);
        
        // Track exceptions
        try
        {
            // business logic
        }
        catch (Exception ex)
        {
            telemetryClient.TrackException(ex);
        }
        
        // Flush telemetry
        telemetryClient.Flush();
    }
}
```

For Java applications:
```xml
<!-- pom.xml -->
<dependency>
    <groupId>com.microsoft.applicationinsights</groupId>
    <artifactId>applicationinsights-core</artifactId>
    <version>3.4.0</version>
</dependency>
```

### Database Applications

**SQL Server: Enable SQL Auditing**

```sql
CREATE SERVER AUDIT [AzureMonitorAudit]
TO APPLICATION_LOG;

ALTER SERVER AUDIT [AzureMonitorAudit] WITH (STATE = ON);

CREATE DATABASE AUDIT SPECIFICATION [AzureMonitorSpec]
FOR SERVER AUDIT [AzureMonitorAudit]
ADD (SELECT, INSERT, UPDATE, DELETE ON DATABASE::YourDB BY dbo);

ALTER DATABASE AUDIT SPECIFICATION [AzureMonitorSpec] WITH (STATE = ON);
```

Then configure DCR to ingest SQL Server Event logs.

**MySQL: Enable Slow Query Log**

```sql
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 2;  -- Log queries taking > 2 seconds
SET GLOBAL log_queries_not_using_indexes = 'ON';
```

Configure DCR to monitor `/var/log/mysql/slow.log`.

**PostgreSQL: Enable Query Logging**

```sql
ALTER SYSTEM SET log_min_duration_statement = 1000;  -- Log queries > 1 second
ALTER SYSTEM SET log_statement = 'all';
SELECT pg_reload_conf();
```

### Background Jobs and Scheduled Tasks

**Windows: Task Scheduler Integration**

Log job execution to Application event log:

```powershell
# In your job script
$EventLog = "Application"
$EventSource = "YourJobName"

# Register event source if not exists
if (![System.Diagnostics.EventLog]::SourceExists($EventSource)) {
    [System.Diagnostics.EventLog]::CreateEventSource($EventSource, $EventLog)
}

# Log job start
Write-EventLog -LogName $EventLog -Source $EventSource -EventId 1000 -Message "Job started: ProcessOrder"

# Job logic
try {
    # Do work
    Write-EventLog -LogName $EventLog -Source $EventSource -EventId 1001 -Message "Job completed successfully: 500 orders processed"
}
catch {
    Write-EventLog -LogName $EventLog -Source $EventSource -EventId 1002 -Message "Job failed: $_"
}
```

**Linux: Cron Job Integration**

Log to syslog:

```bash
#!/bin/bash
# /usr/local/bin/backup-job.sh

logger -t backup-job "Starting backup..."

# Backup logic
if mysqldump -u user -p'password' mydb > /backups/mydb.sql; then
    logger -t backup-job "Backup completed successfully"
else
    logger -t backup-job "Backup failed!"
fi
```

Run via crontab:
```
0 2 * * * /usr/local/bin/backup-job.sh >> /var/log/backup-job.log 2>&1
```

---

## Step 5: KQL Queries for Dashboards

### Web Application Performance

```kusto
// Average response time and request rate over time
W3CIISLog
| where TimeGenerated > ago(24h)
| summarize ResponseTime = avg(TimeTaken), RequestCount = count() by bin(TimeGenerated, 5m), cServerIp
| render timechart
```

### Database Query Performance

```kusto
// Slow SQL queries (SQL Server)
Event
| where EventID == 17000
| where RenderedDescription contains "duration"
| parse RenderedDescription with * "duration " duration:long " ms" *
| where duration > 1000
| summarize count() by Computer, bin(TimeGenerated, 1h)
| sort by count_ desc
```

### Job Execution Status

```kusto
// Application event log for job execution
Event
| where EventLog == "Application" and Source == "YourJobName"
| extend Status = case(EventID == 1000, "Started", EventID == 1001, "Success", EventID == 1002, "Failed", "Unknown")
| summarize SuccessCount = countif(Status == "Success"), FailureCount = countif(Status == "Failed") by day = bin(TimeGenerated, 1d)
| project Day = day, SuccessRate = (SuccessCount * 100 / (SuccessCount + FailureCount))
```

### System Resource Utilization

```kusto
// CPU and memory over time
Perf
| where ObjectName == "Processor" and CounterName == "% Processor Time"
| summarize AvgCPU = avg(CounterValue) by Computer, bin(TimeGenerated, 5m)
| render timechart
```

---

## Step 6: Create Alerts

### Alert: Web Application Response Time > 2 seconds

```kusto
W3CIISLog
| summarize AvgResponseTime = avg(TimeTaken) by bin(TimeGenerated, 5m)
| where AvgResponseTime > 2000
```

### Alert: Database Connection Pool Exhaustion

```kusto
Perf
| where ObjectName == "SQLServer:General Statistics" and CounterName == "User Connections"
| where CounterValue > 100
```

### Alert: Scheduled Job Failure

```kusto
Event
| where Source == "YourJobName" and EventID == 1002
```

---

## Cost Optimization

| Item | Monthly Cost | Optimization |
|------|--------------|---------------|
| Arc agent (free) | $0 | N/A |
| AMA agent (free) | $0 | N/A |
| Log Analytics (50 GB ingestion) | $25–$50 | Set daily cap, delete old logs |
| Application Insights (10 GB sampling) | $10–$20 | Reduce sampling rate, filter logs |
| **Total (5 servers)** | ~$200–$300 | Budget-friendly for data center monitoring |

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Arc agent won't connect | Check outbound HTTPS routing to Azure, verify service principal credentials |
| AMA not collecting data | Check DCR is associated with machine, verify log file paths, check RBAC permissions |
| High ingestion costs | Reduce performance counter frequency, filter event logs by EventID, use log rotation |
| Gaps in telemetry | Restart AMA, check agent logs in `Event Viewer > Applications and Services Logs > Azure Monitor Agent` |

---

## Next Steps

1. **Onboard first pilot server** with Arc and AMA
2. **Test data flow** — verify custom tables in Log Analytics
3. **Create dashboards** for web apps, databases, jobs
4. **Tune alerts** based on baseline metrics
5. **Scale to production** — 20+ servers in data center
6. **Integrate with Phase 2 onwards** of [IMPLEMENTATION_PLAN.md](../IMPLEMENTATION_PLAN.md)

---

**Last Updated**: March 25, 2026  
**Version**: 1.0.0
