# Azure Monitor Monitoring Foundation - Bicep Module

Production-ready Bicep module for deploying the Azure Monitor hybrid observability platform foundation.

## Overview

This module provisions the core Azure Monitor infrastructure as described in [TECHNICAL_ARCHITECTURE.md](../TECHNICAL_ARCHITECTURE.md):

- **Log Analytics Workspace**: Centralized telemetry storage with configurable retention and ingestion caps
- **Application Insights**: APM instrumentation for HTTP-based applications
- **Azure Managed Grafana**: Advanced visualization and dashboard platform
- **Action Group**: Alert routing and notification configuration
- **Diagnostic Settings**: Platform telemetry collection

## Files

- `main.bicep` — Main Bicep template with all resource definitions
- `main.dev.bicepparam` — Parameter values for development environment
- `main.prod.bicepparam` — Parameter values for production environment

## Prerequisites

- Azure subscription with appropriate permissions (Owner or Contributor on target resource group)
- Azure CLI (version 2.50+) or Azure PowerShell (version 10+)
- Resource group created in target environment

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `location` | string | `resourceGroup().location` | Azure region for resource deployment |
| `environment` | string | `dev` | Environment name: `dev`, `test`, or `prod` |
| `resourcePrefix` | string | (required) | 2–10 character prefix for resource naming |
| `logAnalyticsSkuName` | string | `PerGB2018` | Log Analytics pricing tier |
| `logAnalyticsRetentionInDays` | int | `30` | Data retention window (7–730 days) |
| `logAnalyticsDailyCap` | int | `10` | Daily ingestion cap in GB |
| `applicationInsightsSamplingPercentage` | int | `100` | Sampling rate for telemetry (1–100%) |
| `grafanaSku` | string | `Standard` | Grafana pricing tier: `Standard` or `Premium` |
| `enableGrafana` | bool | `true` | Deploy Grafana instance |
| `enableDiagnosticSettings` | bool | `true` | Enable platform diagnostic logging |
| `tags` | object | `{}` | Cost allocation and tracking tags |

### Environment-Specific Recommendations

**Development**
- Retention: 7–30 days
- Daily cap: 5–10 GB
- Sampling: 100% (full telemetry)
- Grafana: Standard

**Production**
- Retention: 90+ days
- Daily cap: 50–200 GB (based on workload)
- Sampling: 50–80% (adaptive sampling)
- Grafana: Premium (advanced features, SLA)

## Deployment

### Using Azure CLI

```bash
# Deploy to development environment
az deployment group create \
  --name 'monitor-foundation-dev' \
  --resource-group 'rg-contoso-monitor-dev' \
  --template-file './main.bicep' \
  --parameters './main.dev.bicepparam'

# Deploy to production environment
az deployment group create \
  --name 'monitor-foundation-prod' \
  --resource-group 'rg-contoso-monitor-prod' \
  --template-file './main.bicep' \
  --parameters './main.prod.bicepparam'
```

### Using Azure PowerShell

```powershell
# Deploy to development environment
New-AzResourceGroupDeployment `
  -Name 'monitor-foundation-dev' `
  -ResourceGroupName 'rg-contoso-monitor-dev' `
  -TemplateFile './main.bicep' `
  -TemplateParameterFile './main.dev.bicepparam'

# Deploy to production environment
New-AzResourceGroupDeployment `
  -Name 'monitor-foundation-prod' `
  -ResourceGroupName 'rg-contoso-monitor-prod' `
  -TemplateFile './main.bicep' `
  -TemplateParameterFile './main.prod.bicepparam'
```

### Custom Parameter Overrides

Override parameters at deployment time without modifying files:

```bash
az deployment group create \
  --name 'monitor-foundation-custom' \
  --resource-group 'rg-custom' \
  --template-file './main.bicep' \
  --parameters './main.dev.bicepparam' \
  --parameters location='westeurope' \
             logAnalyticsRetentionInDays=60 \
             logAnalyticsDailyCap=25
```

## Outputs

The template provides the following outputs for downstream configuration and agent deployment:

| Output | Description |
|--------|-------------|
| `logAnalyticsWorkspaceId` | Resource ID of Log Analytics Workspace |
| `logAnalyticsWorkspaceName` | Workspace name (for agent config) |
| `applicationInsightsInstrumentationKey` | Application Insights instrumentation key |
| `applicationInsightsConnectionString` | Application Insights connection string |
| `applicationInsightsResourceId` | Resource ID of Application Insights component |
| `grafanaResourceId` | Resource ID of Managed Grafana instance |
| `grafanaUrl` | Grafana endpoint URL |
| `actionGroupResourceId` | Resource ID of Action Group |
| `appliedTags` | All tags applied to resources |

## Next Steps

After successful deployment:

1. **Onboard Applications**: Use the Application Insights instrumentation key to instrument HTTP applications (see Phase 2 of [IMPLEMENTATION_PLAN.md](../IMPLEMENTATION_PLAN.md))

2. **Configure Agents**: Deploy Azure Monitor Agent to Azure VMs and Arc-enabled on-premises servers using the Log Analytics Workspace ID and shared key

3. **Set Up Grafana**: Access Grafana at the provided endpoint URL to configure data sources and dashboards

4. **Configure Alerts**: Populate the Action Group with email recipients, webhooks, or ITSM integrations

5. **Enable SaaS Integration**: Connect SaaS telemetry sources as documented in implementation phase 4

## Cost Estimation

Cost varies by:
- **Log ingestion rate**: GB/day ingested (primary driver)
- **Retention period**: Longer retention increases storage cost
- **Grafana SKU**: Standard ~$50/month, Premium ~$150/month
- **Application Insights sampling**: Lower sampling = lower costs

**Example monthly cost** (production, 50 GB/day ingestion, 90-day retention):
- Log Analytics: ~$1,500–$2,500
- Application Insights: ~$500–$1,000
- Managed Grafana (Premium): ~$150
- **Estimated total**: $2,150–$3,650/month

Use Azure Pricing Calculator for precise estimates: https://azure.microsoft.com/en-us/pricing/calculator/

## Support and Maintenance

- **Template validation**: Run `az bicep build` to validate syntax
- **Deployment validation**: Use `--mode Validate` flag before actual deployment
- **Updates**: Re-run deployment with updated parameters to modify existing resources
- **Costs**: Monitor via Azure Cost Management and set alerts on daily caps to prevent runaway expenses

## Related Documentation

- [Business Requirements](../BUSINESS_REQUIREMENTS.md)
- [Technical Architecture](../TECHNICAL_ARCHITECTURE.md)
- [Architecture Diagram](../ARCHITECTURE_DIAGRAM.md)
- [Implementation Plan](../IMPLEMENTATION_PLAN.md)
- [Unified Ingestion Pipeline](../INGESTION_PIPELINE.md)
- [Demo Solution](../DEMO_SOLUTION.md)

---

**Version**: 1.0.0  
**Last Updated**: March 25, 2026  
**Maintained By**: Platform Engineering Team
