# Microsoft 365 Monitoring Guide

Implementation guide for centralizing Microsoft 365 service health, audit, and usage telemetry into the Azure Monitor Log Analytics platform.

## Overview

Microsoft 365 (Exchange Online, Teams, SharePoint Online, and related services) is classified as an internal application in this platform. As part of the corporate Azure tenant, its health and audit data should flow into the same Log Analytics Workspace used for on-premises and cloud workloads, enabling:

- Correlated incident detection across M365 services and internal infrastructure
- Unified alerting for M365 service degradation, license, and security events
- Centralized dashboards spanning M365, on-prem, and Azure workloads
- Compliance and audit log retention alongside other application telemetry

## Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                  MICROSOFT 365 TENANT                          │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│   Exchange Online    Teams    SharePoint    Entra ID           │
│         │               │          │           │               │
│         └───────────────┴──────────┴───────────┘               │
│                              │                                  │
│               Microsoft Graph API / M365 Connectors            │
│                              │                                  │
└──────────────────────────────┼─────────────────────────────────┘
                               │
┌──────────────────────────────▼─────────────────────────────────┐
│               INGESTION LAYER (AZURE TENANT)                   │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│   Microsoft Sentinel / Defender XDR Connector (audit/security) │
│   M365 Content Activity API (compliance/audit logs)            │
│   Azure Monitor M365 Solution (service health + metrics)       │
│   Logic Apps / Azure Functions (custom metric polling)         │
│                                                                 │
└──────────────────────────────┬─────────────────────────────────┘
                               │
┌──────────────────────────────▼─────────────────────────────────┐
│             LOG ANALYTICS WORKSPACE                            │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│   OfficeActivity    MicrosoftGraphActivityLogs                 │
│   ServiceHealthIssue_CL    M365MessageCenter_CL                │
│   SigninLogs    AuditLogs    AADNonInteractiveUserSignInLogs    │
│                                                                 │
└────────────────────────────────────────────────────────────────┘
                               │
           ┌───────────────────┴───────────────────┐
           │                                       │
     Workbooks and                         Alerts and
     Dashboards                            Action Groups
```

**Data flow**: M365 telemetry reaches Log Analytics through native connectors, the Content Activity API, or Azure Functions polling Graph API. All data lands in dedicated tables and is available to the same KQL queries, alerts, and dashboards used across the rest of the platform.

---

## Pattern 1: Microsoft 365 Native Connector (Service Health and Alerts)

**Use when**: You want M365 Service Health advisories, incidents, and Message Center notifications in Log Analytics without custom code.

### Step 1: Enable the Microsoft 365 Data Connector

> Requires: Log Analytics Workspace with Microsoft Sentinel enabled, or direct M365 solution deployment.

**Via Microsoft Sentinel:**

1. Azure Portal → **Microsoft Sentinel** → Select your workspace
2. **Data Connectors** → Search for **Microsoft 365**
3. Select **Open connector page**
4. Under **Configuration**, check:
   - Exchange
   - SharePoint
   - Teams
5. Click **Apply Changes**

This enables the `OfficeActivity` table in Log Analytics.

### Step 2: Verify Data Arrival

```kusto
OfficeActivity
| where TimeGenerated > ago(1h)
| summarize count() by RecordType, OfficeWorkload
| order by count_ desc
```

Expected output includes rows for `Exchange`, `SharePoint`, and `MicrosoftTeams`.

---

## Pattern 2: Entra ID Sign-In and Audit Logs

**Use when**: You need identity and access event data: failed sign-ins, MFA events, conditional access outcomes, user and admin activity.

### Step 1: Enable Entra ID Diagnostic Settings

1. Azure Portal → **Microsoft Entra ID** → **Monitoring** → **Diagnostic Settings**
2. **Add diagnostic setting**
3. Select logs:
   - AuditLogs
   - SignInLogs
   - NonInteractiveUserSignInLogs
   - ServicePrincipalSignInLogs
   - RiskyUsers
   - UserRiskEvents
4. Destination: **Send to Log Analytics Workspace** → select your workspace
5. Save

### Step 2: Verify Data Arrival

```kusto
SigninLogs
| where TimeGenerated > ago(1h)
| summarize failures = countif(ResultType != "0"), total = count()
    by UserPrincipalName
| where failures > 0
| order by failures desc
```

### Query: Failed MFA Events

```kusto
SigninLogs
| where TimeGenerated > ago(24h)
| where AuthenticationRequirement == "multiFactorAuthentication"
| where ResultType != "0"
| project TimeGenerated, UserPrincipalName, AppDisplayName, ResultDescription, IPAddress, Location
| order by TimeGenerated desc
```

### Query: Admin Activity (Audit Log)

```kusto
AuditLogs
| where TimeGenerated > ago(24h)
| where Category == "RoleManagement" or Category == "UserManagement"
| project TimeGenerated, OperationName, InitiatedBy, TargetResources, Result
| order by TimeGenerated desc
```

---

## Pattern 3: M365 Service Health Polling via Azure Function

**Use when**: You need M365 service health incidents and advisories as structured records in Log Analytics for alerting and historical correlation. Uses the Microsoft Graph API `serviceHealth` endpoint.

### Prerequisites

- App registration in Entra ID with:
  - Permission: `ServiceHealth.Read.All` (application permission)
  - Admin consent granted
- Application client ID, tenant ID, and client secret

### Step 1: Create App Registration

```bash
# Create app registration
az ad app create --display-name "m365-health-monitor"

# Add Graph API application permission for ServiceHealth.Read.All
az ad app permission add \
  --id <APP_ID> \
  --api 00000003-0000-0000-c000-000000000000 \
  --api-permissions bf7b1a76-6e77-406b-b258-bf5c7720e98f=Role

# Grant admin consent
az ad app permission admin-consent --id <APP_ID>
```

### Step 2: Azure Function — Poll M365 Service Health

```powershell
# Function: Poll-M365ServiceHealth
# Timer trigger: every 15 minutes

param($Timer)

$tenantId     = $env:TENANT_ID
$clientId     = $env:CLIENT_ID
$clientSecret = $env:CLIENT_SECRET
$workspaceId  = $env:WORKSPACE_ID
$workspaceKey = $env:WORKSPACE_KEY

# Acquire token
$tokenBody = @{
    grant_type    = "client_credentials"
    client_id     = $clientId
    client_secret = $clientSecret
    scope         = "https://graph.microsoft.com/.default"
}
$token = (Invoke-RestMethod -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" `
    -Method Post -Body $tokenBody).access_token

# Fetch service health issues
$headers = @{ Authorization = "Bearer $token" }
$issues = (Invoke-RestMethod `
    -Uri "https://graph.microsoft.com/v1.0/admin/serviceAnnouncement/issues" `
    -Headers $headers).value

# Send to Log Analytics
$records = $issues | ForEach-Object {
    @{
        IssueId         = $_.id
        Title           = $_.title
        Service         = $_.service
        Feature         = $_.feature
        Status          = $_.status
        Classification  = $_.classification
        Severity        = $_.impactDescription
        StartDateTime   = $_.startDateTime
        LastModified    = $_.lastModifiedDateTime
        IsResolved      = $_.isResolved
        TimeGenerated   = (Get-Date).ToUniversalTime().ToString("o")
    }
}

if ($records.Count -gt 0) {
    $body = $records | ConvertTo-Json -AsArray
    $contentLength = [System.Text.Encoding]::UTF8.GetByteCount($body)
    $date = (Get-Date).ToUniversalTime().ToString("R")
    $stringToSign = "POST`n$contentLength`napplication/json`nx-ms-date:$date`n/api/logs"
    $hmac = New-Object System.Security.Cryptography.HMACSHA256
    $hmac.Key = [Convert]::FromBase64String($workspaceKey)
    $sig = [Convert]::ToBase64String($hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($stringToSign)))
    $authHeader = "SharedKey ${workspaceId}:$sig"

    Invoke-RestMethod `
        -Uri "https://${workspaceId}.ods.opinsights.azure.com/api/logs?api-version=2016-04-01" `
        -Method Post `
        -Headers @{ Authorization = $authHeader; "Log-Type" = "M365ServiceHealth"; "x-ms-date" = $date } `
        -Body $body `
        -ContentType "application/json"

    Write-Host "Sent $($records.Count) health records to Log Analytics"
}
```

### Step 3: Query M365 Health in Log Analytics

```kusto
M365ServiceHealth_CL
| where TimeGenerated > ago(24h)
| where IsResolved_b == false
| project TimeGenerated, Service_s, Title_s, Status_s, Classification_s
| order by TimeGenerated desc
```

---

## Pattern 4: Teams and Exchange Usage Metrics via Graph API

**Use when**: You need usage statistics (active users, call quality, mailbox quota) for capacity planning or SLA tracking.

### Step 1: Grant Graph API Permissions

Add these application permissions to the app registration from Pattern 3:

| Permission | Purpose |
|---|---|
| `Reports.Read.All` | Usage reports for Teams, Exchange, SharePoint |
| `CallRecords.Read.All` | Teams call quality records |

### Step 2: Azure Function — Collect Teams Usage

```powershell
# Fetch Teams activity report (last 7 days)
$report = Invoke-RestMethod `
    -Uri "https://graph.microsoft.com/v1.0/reports/getTeamsUserActivityCounts(period='D7')" `
    -Headers @{ Authorization = "Bearer $token" }

# Parse and send to Log Analytics as TeamsUsage_CL table
```

### Query: Teams Call Quality Issues

```kusto
M365TeamsUsage_CL
| where TimeGenerated > ago(7d)
| summarize avg_calls = avg(CallCount_d) by bin(TimeGenerated, 1d)
| render timechart
```

---

## Step 5: Alerts for M365 Events

### Alert: Active M365 Service Incident

```kusto
M365ServiceHealth_CL
| where IsResolved_b == false
| where Classification_s == "incident"
| where TimeGenerated > ago(15m)
```

Set frequency: 15 minutes. Trigger when row count > 0.

### Alert: Spike in Failed Sign-Ins

```kusto
SigninLogs
| where TimeGenerated > ago(15m)
| summarize failures = countif(ResultType != "0")
| where failures > 50
```

### Alert: Admin Role Assignment

```kusto
AuditLogs
| where TimeGenerated > ago(5m)
| where OperationName == "Add member to role"
| where Category == "RoleManagement"
```

Route all alerts to your defined Action Groups — see [ALERTING_NOTIFICATIONS.md](ALERTING_NOTIFICATIONS.md).

---

## Workbook: M365 Service Health Dashboard

Add an M365 tab to your platform Workbook with the following tiles:

| Tile | Query | Type |
|---|---|---|
| Active incidents | `M365ServiceHealth_CL | where IsResolved_b == false` | Grid |
| Incident timeline | Service health over 24h | Time chart |
| Sign-in failures | Failed sign-ins by user | Bar chart |
| Admin activity | Recent role changes | Grid |
| Teams usage | Daily active users | Line chart |

---

## Validation Checklist

- [ ] `OfficeActivity` table receives data from Exchange, SharePoint, and Teams
- [ ] Entra ID diagnostic settings route SigninLogs and AuditLogs to workspace
- [ ] Azure Function polls M365 Service Health every 15 minutes
- [ ] `M365ServiceHealth_CL` table is populated
- [ ] Alerts are active for active incidents and sign-in failures
- [ ] M365 tab added to platform monitoring dashboard
