# Architecture Diagram

## Azure Monitoring Hybrid Observability Architecture

```mermaid
flowchart LR
    subgraph Sources[Telemetry Sources]
        HTTPApps[HTTP Endpoint Applications]
        AzureVMs[Azure Virtual Machines]
        OnPrem[On-Prem Servers and Apps]
        SaaS[SaaS Applications]
        NetSignals[Network Signals]
    end

    subgraph Ingestion[Collection and Ingestion]
        AppInsights[Application Insights]
        AMA[Azure Monitor Agent]
        Arc[Azure Arc]
        Connectors[SaaS Connectors and REST API Ingestion]
        NetWatcher[Network Watcher and Connection Monitor]
    end

    subgraph Observability[Azure Monitor Platform]
        Metrics[Azure Monitor Metrics]
        Logs[Azure Monitor Logs]
        LA[(Log Analytics Workspace)]
    end

    subgraph Experience[Visualization and Operations]
        Workbooks[Azure Workbooks]
        Grafana[Azure Managed Grafana]
        Alerts[Azure Monitor Alerts]
        ActionGroups[Action Groups]
        Notifications[Email SMS Webhook Logic Apps ITSM]
    end

    HTTPApps --> AppInsights
    AzureVMs --> AMA
    OnPrem --> Arc
    Arc --> AMA
    SaaS --> Connectors
    NetSignals --> NetWatcher

    AppInsights --> Metrics
    AppInsights --> Logs
    AMA --> Metrics
    AMA --> Logs
    Connectors --> Logs
    Connectors --> Metrics
    NetWatcher --> Metrics
    NetWatcher --> Logs

    Metrics --> LA
    Logs --> LA

    LA --> Workbooks
    LA --> Grafana
    Metrics --> Alerts
    Logs --> Alerts

    Alerts --> ActionGroups
    ActionGroups --> Notifications
```

## Diagram Notes

- Application and infrastructure telemetry converges into Azure Monitor data stores.
- Log Analytics Workspace is the central analytics layer for KQL queries and correlation.
- Dashboards are provided through Workbooks and Managed Grafana.
- Alerts evaluate metric and log conditions, then route to Action Groups for notifications and integrations.
