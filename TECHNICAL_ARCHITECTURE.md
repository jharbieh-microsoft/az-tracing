# Technical Architecture Recommendation

Diagram: [Architecture Diagram](ARCHITECTURE_DIAGRAM.md)

## Overview

Use Azure Monitor as the core observability platform for a hybrid monitoring architecture.

## Implemented Artifacts in This Repository

The target architecture described here is now supported by implementation and validation assets in this repository:

1. Monitoring foundation deployment assets in [bicep/README.md](bicep/README.md) and the [bicep](bicep) folder.
2. Hybrid server onboarding guidance in [DATA_CENTER_MONITORING.md](DATA_CENTER_MONITORING.md).
3. SaaS integration patterns and examples in [SAAS_INTEGRATION.md](SAAS_INTEGRATION.md).
4. Unified ingestion design and workload mapping in [INGESTION_PIPELINE.md](INGESTION_PIPELINE.md).
5. End-to-end demo deployment, validation, and troubleshooting assets in [DEMO_SOLUTION.md](DEMO_SOLUTION.md) and the [demo](demo) folder.

These assets provide a practical baseline for validating the architecture before production rollout.

## Core Services

- Azure Monitor: central platform for collecting and analyzing metrics and logs
- Log Analytics Workspace: consolidated telemetry storage and query layer
- Application Insights: application performance monitoring for HTTP-based workloads
- Azure Monitor Agent (AMA): guest-level collection from virtual machines
- Azure Arc: Azure management and monitoring extension for on-premises servers

## Ingestion and Collection Strategy

### HTTP Endpoint Applications

- Instrument with Application Insights for request metrics, dependencies, traces, and exceptions

### Virtual Machines

- Install and configure Azure Monitor Agent
- Collect performance counters, event logs, and custom signals

### On-Premises Data Center Workloads

Monitor data center applications running on Windows and Linux servers through **Azure Arc** integration and **Azure Monitor Agent (AMA)** with **Data Collection Rules (DCRs)**.

#### Phase 1: Server Onboarding with Azure Arc

- Connect on-premises servers to Azure using Azure Arc Agent
- Servers gain hybrid identity and Azure management capabilities
- AMA deployment becomes policy-driven and centralized
- Supported platforms: Windows Server 2012 R2+, RHEL 7+, Ubuntu 18.04+, CentOS 7+, SLES 12+

#### Phase 2: Agent Deployment and Configuration

- Deploy Azure Monitor Agent via Arc policies (push model) or manual installation
- Configure **Data Collection Rules (DCRs)** to specify:
  - Performance metrics (CPU, memory, disk, network)
  - Event log collection (Windows Event Viewer)
  - Application logs and text logs
  - Syslog collection (Linux)
  - Custom performance counters

#### Phase 3: Application-Specific Monitoring

**HTTP/REST Web Applications**
- Instrument with Application Insights SDK (auto-instrumentation available for .NET, Java, Node.js, Python)
- Collect: response times, request rates, dependency traces, exceptions
- Forward to Log Analytics Workspace

**Database Applications**
- Enable SQL Server, MySQL, PostgreSQL native monitoring if available
- Use AMA to collect:
  - Query performance logs
  - Lock wait times
  - Connection pool statistics
  - Slow query logs (if supported)
- For SQL Server: Enable Azure Monitoring for SQL Servers (Arc-connected)

**Background Jobs and Batch Processes**
- Instrument job code with Application Insights or custom logging
- Log to local file/syslog, then forward to Log Analytics via AMA
- Track: job start/end times, duration, success/failure status, items processed

**Scheduled Tasks and Cron Jobs**
- Use AMA to collect Windows Task Scheduler or Linux cron logs
- For detailed tracking: Have tasks log to files or database, ingest via AMA
- Ingest job output logs using DCR text log collection

#### Data Collection Rule (DCR) Strategy

Create DCRs per workload type, not per server:
- `dcr-webapp-monitoring` — Web application servers
- `dcr-database-monitoring` — Database servers
- `dcr-jobs-monitoring` — Background job servers
- `dcr-system-monitoring` — Baseline OS and infrastructure metrics

Apply DCRs to server groups via Azure Arc resource groups or tags.

#### Network Connectivity Requirements

- **Outbound HTTPS only**: Servers require outbound access to Azure Monitor endpoints (`*.ods.opinsights.azure.com`)
- **Firewall rules**: Port 443 to Azure endpoints (no inbound required)
- **Proxy support**: AMA supports HTTP/HTTPS proxies with authentication
- **Private Link (optional)**: For air-gapped environments, use Private Link for secure ingestion

#### Alerting from Data Center Workloads

- Configure metric alerts based on AMA-collected performance data
- Configure log query alerts based on event logs, application logs, and syslog
- Alert examples:
  - CPU > 80% for 5+ minutes
  - Application crash (Windows Event ID 1000, segfault in syslog)
  - Job failure (exit code != 0)
  - Database transaction log growth > 80%
  - Disk space available < 10%

### SaaS Applications

For SaaS services with HTTP/internet-only access, use one or more of these patterns:

#### Pattern 1: Synthetic Monitoring (Availability Tests)
- Use **Application Insights Availability Tests** to probe SaaS endpoints from multiple Azure regions
- Detects service outages, latency degradation, and response failures
- Returns telemetry (response time, availability %) to Log Analytics
- Best for: Public HTTP endpoints, REST APIs, status pages

#### Pattern 2: Native Connectors
- Some SaaS vendors (ServiceNow, Salesforce, Microsoft 365, etc.) publish native Azure connectors
- Connectors push telemetry directly to Log Analytics Workspace
- Often include incident data, performance metrics, and audit logs
- Best for: Enterprise SaaS platforms with Azure integration

#### Pattern 3: HTTP Data Collector API
- SaaS systems (or custom scripts) post telemetry to Log Analytics via secured HTTP endpoint
- Authenticate with shared key; send custom JSON payloads
- Ideal for vendors without native connectors
- Best for: Custom SaaS applications, APIs that support webhooks, polling agents

#### Pattern 4: Logic Apps or Azure Functions + REST API Polling
- Scheduled Logic App or Function Timer trigger calls SaaS REST API on fixed cadence (e.g., every 5 minutes)
- Extracts metrics, status, or incident data from API response
- Sends to Log Analytics via HTTP Data Collector API
- Best for: SaaS platforms with documented REST APIs (GitHub, Datadog, Stripe, etc.)

#### Pattern 5: Webhook Integration for Real-Time Alerts
- SaaS system sends alerts/events to Azure Logic Apps webhook endpoint in real-time
- Logic App processes the alert and creates incident record in Log Analytics
- Optionally triggers Azure Monitor action groups for immediate notification
- Best for: Active alerting from SaaS platforms that support webhook delivery

#### Implementation Patterns by SaaS Type

| SaaS Vendor | Data Type | Recommended Pattern | Example |
|-------------|-----------|---------------------|---------|
| Microsoft 365, Dynamics, Power BI | Activity logs, incidents | Native connector or REST API | Office 365 connector → Log Analytics |
| Datadog, New Relic, Splunk | Metrics, traces, logs | HTTP Data Collector API or Logic App | Scheduled Logic App → HTTP API call → Log Analytics |
| GitHub, GitLab, Bitbucket | Repository events, deployments | REST API polling | Function App polls API every hour |
| Slack, Teams, Discord | Chat logs, bot activities | Webhook → Logic App → Log Analytics | Slack event subscription → webhook |
| Stripe, Shopify, Twilio | Transaction, call, SMS events | Webhook or REST API | Scheduled function fetches ledger |
| AWS, GCP, other cloud | Cost, performance, security | REST API polling | Cloud Custodian or custom function |
| Public SaaS status pages | Uptime status | HTTP synthetic test or web scraping | Application Insights availability test |

#### Data Ingestion and Timeliness

| Pattern | Ingestion Latency | Cost | Complexity | Best For |
|---------|------------------|------|-----------|----------|
| Synthetic monitoring | 1–5 minutes | Low ($) | Low | Availability/latency visibility |
| Native connector | Real-time to 5 min | Medium ($$) | Low | Full-featured integrations |
| HTTP Data Collector | Near real-time | Low ($) | Medium | Custom payloads, push model |
| API polling (Logic App/Function) | 5–60 minutes | Low–Medium | Medium | Scheduled extraction |
| Webhooks | <1 second | Low ($) | Medium–High | Real-time alerting |

### Network Observability

- Use Network Watcher and Connection Monitor for latency, connectivity, and packet-loss insights

## Storage and Query Model

- Use Azure Monitor Metrics for near-real-time numeric monitoring
- Use Azure Monitor Logs with KQL for deep analysis and cross-source correlation

## Dashboards and Visualization

- Use Azure Workbooks for native, customizable operational dashboards
- Use Azure Managed Grafana for advanced visualization scenarios and broader dashboard experiences

## Alerting and Notification Design

- Configure Azure Monitor Alerts with:
  - Metric alerts for threshold-based conditions
  - Log query alerts for advanced conditional logic
- Route notifications through Action Groups to:
  - Email
  - SMS
  - Webhooks
  - Logic Apps
  - ITSM integrations (for example, ServiceNow)

## Infrastructure Parameters

Capture these details to parameterize Bicep templates and support deployments across environments (dev, test, prod):

### Naming and Identification

- **Resource prefix**: Short identifier for organization/project (e.g., `contoso`, `az-tracing`)
- **Environment**: `dev`, `test`, `prod`
- **Location**: Azure region (e.g., `eastus`, `westeurope`)
- **Resource group name**: Proposed naming pattern (e.g., `rg-{prefix}-monitor-{environment}`)

### Log Analytics Workspace Configuration

- **Workspace SKU**: `PerGB2018` (default for production use)
- **Daily ingestion cap (GB)**: Limits daily cost exposure (e.g., 10 GB/day for dev, 100 GB/day for prod)
- **Data retention (days)**: Compliance and cost-driven retention window
  - Development: 7–30 days
  - Production: 30–90 days
  - Compliance/archive: 365+ days (consider separate retention tables)
- **Workspace name**: Pattern (e.g., `law-{prefix}-{environment}`)

### Application Insights Configuration

- **Instrumentation key storage**: Key Vault reference or direct injection
- **Daily ingestion cap (GB)**: Per Application Insights instance
- **Sampling rate**: Default 100% for dev/test; configure adaptive sampling for production (50–80%)
- **Retention (days)**: 30 (standard), higher with separate Log Analytics link

### Azure Managed Grafana Configuration

- **Grafana instance SKU**: `Standard` (default) or `Premium` for enterprise features
- **Grafana admin user**: Service principal or managed identity for automated setup
- **Dashboard persistence**: Store dashboard JSON in source control or Azure Blob Storage

### Access Control (RBAC)

Apply role assignments at resource group or resource level:

- **Azure Monitor Reader**: Operators viewing dashboards and alerts (read-only)
- **Azure Monitor Contributor**: Platform engineers managing workspaces and rules
- **Log Analytics Contributor**: Data engineers managing queries and retention policies
- **Grafana Admin**: Dashboard and data source management
- **System-assigned Managed Identity**: For Azure Monitor Agent, Azure Arc, and agent-based collection

Assign via:
- Azure AD groups (preferred for team-scoped access)
- Service principals (for automation and CI/CD)
- User identities (for individual admins)

### Environment Strategy

Define monitoring workspace separation:

- **Single workspace per environment**: Dev, test, and prod each have isolated Log Analytics Workspace (recommended for larger deployments)
- **Shared workspace for non-prod**: Dev and test share a single workspace to reduce support overhead
- **Cost allocation tags**: Apply tags to enable chargeback by business unit or application

### Cost and Sizing Assumptions

- **Log ingestion rate**: GB/day estimate per workload type (e.g., 5–15 GB/day for typical medium-scale hybrid environment)
- **Alert rules**: Estimate quantity (e.g., 20–50 baseline rules per phase)
- **Workbooks and dashboards**: Estimate count per team (typically 5–10 per operations team)
- **On-call and notifications**: Action group destinations (email, SMS, webhooks)

## Implementation Benefits

- Unified monitoring across mixed hosting environments
- Deep query and correlation capability through KQL
- Native integration with Azure services
- Built-in scalability and enterprise-grade security/compliance alignment
- Dynamic thresholding support to reduce alert noise and false positives

## Suggested Rollout Sequence

1. Create a Log Analytics Workspace and baseline Azure Monitor configuration.
2. Onboard HTTP applications with Application Insights.
3. Onboard Azure VMs and Arc-enabled servers with AMA.
4. Integrate SaaS telemetry sources.
5. Build dashboards in Workbooks and/or Managed Grafana.
6. Implement and tune alerts and Action Groups.

## Repository References

- [README.md](README.md) for the current repository status and document map
- [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) for phased rollout and exit criteria
- [DEMO_SOLUTION.md](DEMO_SOLUTION.md) for a concrete reference implementation across four monitored source types
