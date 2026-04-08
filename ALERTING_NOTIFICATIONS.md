# Alerting and Notification Design

Consolidated alert catalog, severity model, routing matrix, and operational runbook references for the Azure Monitor hybrid observability platform.

## Overview

This document defines:
- Alert severity classification and escalation tiers
- Alert catalog organized by workload and signal type
- Action Group configuration and notification routing matrix
- Suppression and maintenance window guidance
- Runbook references per alert category

All alerts route through Azure Monitor Alerts and Action Groups. Alert rules are defined as log query alerts or metric alerts depending on signal type. For provisioning the foundation Action Group, see [bicep/README.md](bicep/README.md).

---

## Severity Model

| Severity | Label | Definition | Response Target |
|---|---|---|---|
| Sev 0 | Critical | Complete service outage or data loss imminent | Immediate — page on-call, escalate within 15 min |
| Sev 1 | High | Significant degradation affecting users or key business processes | Respond within 30 minutes |
| Sev 2 | Medium | Partial degradation or elevated error rate; users partially affected | Respond within 2 hours |
| Sev 3 | Low | Warning threshold crossed; no current user impact | Review within next business day |
| Sev 4 | Informational | Operational event for audit, compliance, or trending | No response required; logged for review |

---

## Action Group Configuration

Action Groups define who gets notified and through which channel when an alert fires.

### Recommended Action Groups

| Action Group | Purpose | Channels |
|---|---|---|
| `ag-oncall-critical` | Critical and high-severity incidents | PagerDuty/PagerDuty webhook, SMS to on-call, Teams channel |
| `ag-ops-medium` | Medium-severity operational degradation | Email to ops team, Teams notification |
| `ag-review-low` | Low-severity warnings and informational | Email digest to platform team |
| `ag-itsm` | ITSM ticket creation | ServiceNow webhook or Logic App |
| `ag-security` | Security and identity alerts | Security team email, SIEM webhook |

### Provision Action Groups via Azure CLI

```bash
# Critical on-call group
az monitor action-group create \
  --resource-group rg-contoso-monitor-prod \
  --name ag-oncall-critical \
  --short-name "OnCallCrit" \
  --action email oncall-lead oncall-lead@contoso.com \
  --action sms oncall-sms +1-555-000-0001 \
  --action webhook pagerduty "https://events.pagerduty.com/integration/<KEY>/enqueue"

# Ops medium group
az monitor action-group create \
  --resource-group rg-contoso-monitor-prod \
  --name ag-ops-medium \
  --short-name "OpsMed" \
  --action email ops-team ops-monitoring@contoso.com \
  --action webhook teams-notify "https://contoso.webhook.office.com/webhookb2/<TEAMS_WEBHOOK>"

# ITSM group via Logic App
az monitor action-group create \
  --resource-group rg-contoso-monitor-prod \
  --name ag-itsm \
  --short-name "ITSM" \
  --action logicapp itsm-ticket \
    /subscriptions/<SUB_ID>/resourceGroups/<RG>/providers/Microsoft.Logic/workflows/create-servicenow-ticket \
    https://prod-00.eastus.logic.azure.com/workflows/<WORKFLOW_ID>/triggers/manual/paths/invoke
```

---

## Alert Catalog

### HTTP Applications (Application Insights)

| Alert Name | Severity | Signal | Condition | Action Group |
|---|---|---|---|---|
| HTTP Error Rate Elevated | Sev 1 | Log query | `requests | where success == false | summarize failRate = (count() * 100.0) / count() | where failRate > 5` | ag-oncall-critical |
| Response Time Degraded | Sev 2 | Metric | Average response time > 2000 ms over 5 min | ag-ops-medium |
| Application Availability Drop | Sev 0 | Availability test | Availability < 90% across 3 locations | ag-oncall-critical |
| Dependency Failure Spike | Sev 2 | Log query | `dependencies | where success == false | summarize count() | where count_ > 20` | ag-ops-medium |
| Exception Rate Spike | Sev 2 | Log query | Exception count > 50 in 5 min | ag-ops-medium |

#### KQL: HTTP Error Rate Alert Rule

```kusto
requests
| where TimeGenerated > ago(5m)
| summarize
    total = count(),
    failed = countif(success == false)
| extend failRate = (todouble(failed) / todouble(total)) * 100
| where failRate > 5
```

---

### Virtual Machines (Azure Monitor Agent)

| Alert Name | Severity | Signal | Condition | Action Group |
|---|---|---|---|---|
| High CPU Usage | Sev 2 | Metric | CPU % > 90 for 10 min | ag-ops-medium |
| Low Disk Space | Sev 1 | Log query | Free space < 10% for 15 min | ag-oncall-critical |
| Memory Pressure | Sev 2 | Metric | Available memory < 10% for 10 min | ag-ops-medium |
| Agent Heartbeat Lost | Sev 1 | Log query | No heartbeat in 10 min | ag-oncall-critical |
| Windows Event Error Count | Sev 3 | Log query | > 50 error events in 30 min | ag-review-low |

#### KQL: Disk Space Alert Rule

```kusto
InsightsMetrics
| where TimeGenerated > ago(15m)
| where Namespace == "LogicalDisk" and Name == "FreeSpacePercentage"
| summarize avg_free = avg(Val) by Computer, Tags
| where avg_free < 10
```

#### KQL: Agent Heartbeat Lost

```kusto
Heartbeat
| where TimeGenerated > ago(10m)
| summarize last_beat = max(TimeGenerated) by Computer
| where last_beat < ago(10m)
```

---

### On-Premises Servers (Azure Arc + AMA)

Same alert rules as VMs above apply to Arc-enabled machines. Additional watch items:

| Alert Name | Severity | Signal | Condition | Action Group |
|---|---|---|---|---|
| Arc Agent Disconnected | Sev 1 | Log query | Arc connectivity status = disconnected for 15 min | ag-oncall-critical |
| AMA Extension Health Degraded | Sev 2 | Resource health | Extension health != healthy | ag-ops-medium |

#### KQL: Arc Agent Connectivity Check

```kusto
Heartbeat
| where TimeGenerated > ago(15m)
| where Category == "Direct Agent"
| summarize last_seen = max(TimeGenerated) by Computer, SourceComputerId
| where last_seen < ago(15m)
| project Computer, last_seen
```

---

### Network Observability (Connection Monitor)

| Alert Name | Severity | Signal | Condition | Action Group |
|---|---|---|---|---|
| Path Latency Exceeded | Sev 2 | Log query | Average RTT > threshold for test group | ag-ops-medium |
| Packet Loss Elevated | Sev 1 | Log query | Loss % > 10% for 5 min | ag-oncall-critical |
| Connection Path Failed | Sev 1 | Log query | TestResult == "Fail" | ag-oncall-critical |

See [NETWORK_OBSERVABILITY.md](NETWORK_OBSERVABILITY.md) for full KQL examples.

---

### SaaS Applications

| Alert Name | Severity | Signal | Condition | Action Group |
|---|---|---|---|---|
| SaaS Availability Below 95% | Sev 1 | Availability test | Availability < 95% | ag-oncall-critical |
| SaaS API Response Degraded | Sev 2 | Availability test | Response time > 3000 ms | ag-ops-medium |
| SaaS Connector Ingestion Gap | Sev 2 | Log query | No records in custom table for 30 min | ag-ops-medium |

See [SAAS_INTEGRATION.md](SAAS_INTEGRATION.md) for connector-specific examples.

---

### Microsoft 365

| Alert Name | Severity | Signal | Condition | Action Group |
|---|---|---|---|---|
| Active M365 Service Incident | Sev 1 | Log query | Unresolved incident in M365ServiceHealth_CL | ag-oncall-critical |
| Sign-In Failure Spike | Sev 2 | Log query | > 50 failures in 15 min | ag-security |
| Admin Role Assignment | Sev 2 | Log query | Role management event in AuditLogs | ag-security |
| M365 Health Polling Gap | Sev 3 | Log query | No records in M365ServiceHealth_CL for 20 min | ag-review-low |

See [M365_MONITORING.md](M365_MONITORING.md) for full KQL examples.

---

## Notification Routing Matrix

| Severity | Primary Channel | Secondary Channel | ITSM Ticket | Escalation Path |
|---|---|---|---|---|
| Sev 0 Critical | Page on-call (SMS + webhook) | Teams P0 channel | Auto-created P1 | Escalate to manager at 15 min |
| Sev 1 High | Email to on-call team | Teams alert channel | Auto-created P2 | Escalate at 30 min if unacknowledged |
| Sev 2 Medium | Email to ops team | Teams ops channel | Manual creation | Review in next standup |
| Sev 3 Low | Email digest | — | None | Review within business day |
| Sev 4 Informational | Log only | — | None | No escalation |

---

## Alert Suppression and Maintenance Windows

### Create a Maintenance Window

Use Azure Monitor Action Rule to suppress alerts during planned maintenance:

```bash
az monitor alert-processing-rule create \
  --resource-group rg-contoso-monitor-prod \
  --name  "maint-window-weekend-patching" \
  --rule-type Suppression \
  --scopes "/subscriptions/<SUB_ID>/resourceGroups/rg-contoso-monitor-prod" \
  --filter-alert-context "contains" "patching" \
  --schedule-recurrence-type Weekly \
  --schedule-recurrence Sunday \
  --schedule-start-time "2026-04-12T02:00:00" \
  --schedule-end-time "2026-04-12T06:00:00"
```

### Suppress Specific Alert During Deployment

```bash
az monitor alert-processing-rule create \
  --resource-group rg-contoso-monitor-prod \
  --name "suppress-during-deploy" \
  --rule-type Suppression \
  --scopes "/subscriptions/<SUB_ID>" \
  --filter-alert-rule-name "contains" "HTTP Error Rate" \
  --schedule-start-time "2026-04-15T10:00:00" \
  --schedule-end-time "2026-04-15T11:00:00"
```

---

## Runbook References

| Alert Category | Runbook Title | Location |
|---|---|---|
| HTTP application degradation | App availability and error response runbook | To be created in ops wiki |
| VM resource exhaustion | VM triage and scaling runbook | To be created in ops wiki |
| Arc agent disconnection | Arc reconnect and agent health runbook | [DATA_CENTER_MONITORING.md](DATA_CENTER_MONITORING.md) |
| Network path failure | Network path triage runbook | [NETWORK_OBSERVABILITY.md](NETWORK_OBSERVABILITY.md) |
| M365 service incident | M365 incident response runbook | [M365_MONITORING.md](M365_MONITORING.md) |
| SaaS availability | SaaS triage and escalation runbook | [SAAS_INTEGRATION.md](SAAS_INTEGRATION.md) |

---

## Dynamic Thresholds

For high-variability workloads (such as batch jobs and seasonal traffic), use Azure Monitor dynamic thresholds to reduce false positives:

1. Azure Portal → **Monitor** → **Alerts** → **Create alert rule**
2. Signal: Select a metric (e.g., CPU Percentage)
3. Alert Logic → **Dynamic** threshold
4. Configure:
   - Sensitivity: Medium (recommended starting point)
   - Operator: Greater than
   - Aggregation granularity: 5 minutes
   - Frequency: Every 5 minutes
5. Link to appropriate Action Group from the routing matrix above

Dynamic thresholds use machine learning to model expected behavior and alert only when the signal deviates from that model.

---

## Validation Checklist

- [ ] All Action Groups provisioned and tested with a test notification
- [ ] HTTP, VM, Arc, network, SaaS, and M365 alert rules are active
- [ ] At least one alert per severity level has been end-to-end tested
- [ ] Suppression rules are configured for scheduled maintenance windows
- [ ] Routing matrix reviewed and approved by security and operations teams
- [ ] Runbook links added to alert descriptions in Azure Monitor
- [ ] Dynamic thresholds applied to variable workloads
