# Azure Monitor Hybrid Observability - Modular Bicep

Modular Bicep deployment for the Azure Monitor hybrid observability platform.

## Overview

This deployment provisions and composes core observability resources as described in [TECHNICAL_ARCHITECTURE.md](../TECHNICAL_ARCHITECTURE.md):

- **Foundation**: Log Analytics, Application Insights, Managed Grafana, diagnostic settings
- **Alerting**: Action Groups, baseline scheduled query alert, processing rule placeholder
- **Data Collection**: Baseline Data Collection Rule for Perf/Event/Syslog streams
- **Network Observability**: Network Watcher and baseline Connection Monitor
- **Microsoft 365 Baseline**: M365 custom table and baseline incident alert rule

## Files

- `main.bicep` — Modular orchestrator template
- `main.dev.bicepparam` — Parameter values for development environment
- `main.prod.bicepparam` — Parameter values for production environment
- `modules/foundation.bicep` — Foundation resources
- `modules/alerting.bicep` — Alerting resources
- `modules/data-collection.bicep` — Baseline data collection resources
- `modules/network-observability.bicep` — Network observability resources
- `modules/m365-ingestion.bicep` — M365 baseline ingestion resources

## Prerequisites

- Azure subscription with appropriate permissions (Owner or Contributor on target resource group)
- Azure CLI (version 2.50+) or Azure PowerShell (version 10+)
- Resource group created in target environment

## Required RBAC for IaC Deployment

This section defines least-privilege access for two personas:

1. Developer with minimum permissions (validate and review)
2. Platform deployment team (execute Bicep deployments)

The guidance below is aligned to this modular deployment and checked against Azure MCP role/CLI guidance.

### Persona 1: Developer (Minimum Permissions)

Use this profile when a developer needs to inspect templates, run `what-if`, and verify outputs but should not create or modify infrastructure.

| Scope | Role | Why |
|------|------|-----|
| Target Resource Group | Reader | Read resource state and deployment outputs |
| Log Analytics Workspace (optional) | Monitoring Reader | Query monitoring state and validate signals |
| Managed Grafana (optional) | Grafana Viewer | View dashboards without admin actions |

Notes:

- Developers with this profile should not be able to run `az deployment group create` in write mode.
- Use this role set for safe review and validation workflows.

### Persona 2: Platform Deployer (Required to Deploy)

Use this profile for the platform team account or service principal that runs Bicep deployment.

| Scope | Role | Why |
|------|------|-----|
| Target Resource Group | Contributor | Create/update all resources in this Bicep deployment |
| Network Watcher resource group (if different RG) | Network Contributor | Required when managing Network Watcher/Connection Monitor outside target RG |
| Subscription or target scope | User Access Administrator (optional) | Required only if deployment process also creates RBAC role assignments |

Important:

- If your deployment pipeline does not create role assignments, `User Access Administrator` is not required.
- If role assignments are part of the pipeline, assign `User Access Administrator` only at the minimal required scope.

### Practical Least-Privilege Recommendation

For this repository, start with:

1. Developer: `Reader` on deployment RG
2. Platform deployer: `Contributor` on deployment RG
3. Add `Network Contributor` only if Network Watcher is managed in a different RG
4. Add `User Access Administrator` only when role assignments are automated

### RBAC Assignment Commands (Platform Team)

```bash
# Variables
subscriptionId="<subscription-id>"
resourceGroupName="<target-rg>"
deployerPrincipal="<deployer-upn-or-object-id>"
developerPrincipal="<developer-upn-or-object-id>"

# Developer minimum access
az role assignment create \
  --assignee "$developerPrincipal" \
  --role "Reader" \
  --scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName"

# Platform deployer access
az role assignment create \
  --assignee "$deployerPrincipal" \
  --role "Contributor" \
  --scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName"

# Optional: only if Network Watcher is in a different resource group
az role assignment create \
  --assignee "$deployerPrincipal" \
  --role "Network Contributor" \
  --scope "/subscriptions/$subscriptionId/resourceGroups/NetworkWatcherRG"

# Optional: only if deployment process creates role assignments
az role assignment create \
  --assignee "$deployerPrincipal" \
  --role "User Access Administrator" \
  --scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName"
```

### RBAC Verification Commands

```bash
# List role assignments at deployment scope
az role assignment list \
  --scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName" \
  --output table

# Validate template without deployment write actions
az deployment group validate \
  --name "monitor-foundation-validate" \
  --resource-group "$resourceGroupName" \
  --template-file "./main.bicep" \
  --parameters "./main.dev.bicepparam"

# Preview changes
az deployment group what-if \
  --name "monitor-foundation-whatif" \
  --resource-group "$resourceGroupName" \
  --template-file "./main.bicep" \
  --parameters "./main.dev.bicepparam"
```

### Verify Existing RBAC for a Specific Principal

Use this section when the platform team needs to confirm whether a specific user, service principal, or managed identity already has required access.

#### Inputs to Gather

- `subscriptionId`: Azure subscription ID
- `resourceGroupName`: deployment resource group
- `principal`: user UPN, appId, objectId, or managed identity principal ID

#### Required Role Matrix for This Deployment

| Principal Type | Scope | Required Role | Mandatory |
|------|------|------|------|
| Developer | Resource Group | Reader | Yes |
| Platform Deployer | Resource Group | Contributor | Yes |
| Platform Deployer | NetworkWatcherRG (if different RG) | Network Contributor | Conditional |
| Platform Deployer | Resource Group | User Access Administrator | Conditional (only if pipeline creates RBAC assignments) |

#### Azure CLI: Check All Assignments for a Principal at Scope

```bash
subscriptionId="<subscription-id>"
resourceGroupName="<target-rg>"
principal="<principal-upn-or-object-id>"

scope="/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName"

az role assignment list \
  --assignee "$principal" \
  --scope "$scope" \
  --include-inherited \
  --output table
```

#### Azure CLI: Check a Specific Role Exists

```bash
# Example: verify Contributor exists for deployer at RG scope
az role assignment list \
  --assignee "$principal" \
  --scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName" \
  --include-inherited \
  --query "[?roleDefinitionName=='Contributor']" \
  --output table

# Example: verify Reader exists for developer at RG scope
az role assignment list \
  --assignee "$principal" \
  --scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName" \
  --include-inherited \
  --query "[?roleDefinitionName=='Reader']" \
  --output table
```

#### Azure CLI: One-Step Pass/Fail Check Script

```bash
#!/usr/bin/env bash
set -euo pipefail

subscriptionId="<subscription-id>"
resourceGroupName="<target-rg>"
developerPrincipal="<developer-upn-or-object-id>"
deployerPrincipal="<deployer-upn-or-object-id>"
networkWatcherRg="NetworkWatcherRG"
checkNetworkContributor="false"   # true|false
checkUaa="false"                  # true|false

rgScope="/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName"
nwScope="/subscriptions/$subscriptionId/resourceGroups/$networkWatcherRg"

function assert_role() {
  local assignee="$1"
  local roleName="$2"
  local scope="$3"

  local count
  count=$(az role assignment list \
    --assignee "$assignee" \
    --scope "$scope" \
    --include-inherited \
    --query "[?roleDefinitionName=='$roleName'] | length(@)" \
    -o tsv)

  if [ "$count" -gt 0 ]; then
    echo "PASS: $assignee has $roleName on $scope"
  else
    echo "FAIL: $assignee missing $roleName on $scope"
  fi
}

assert_role "$developerPrincipal" "Reader" "$rgScope"
assert_role "$deployerPrincipal" "Contributor" "$rgScope"

if [ "$checkNetworkContributor" = "true" ]; then
  assert_role "$deployerPrincipal" "Network Contributor" "$nwScope"
fi

if [ "$checkUaa" = "true" ]; then
  assert_role "$deployerPrincipal" "User Access Administrator" "$rgScope"
fi
```

#### PowerShell: Check All Assignments for a Principal

```powershell
$subscriptionId = "<subscription-id>"
$resourceGroupName = "<target-rg>"
$principal = "<principal-upn-or-object-id>"

$scope = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName"

az role assignment list `
  --assignee $principal `
  --scope $scope `
  --include-inherited `
  --output table
```

#### PowerShell: Pass/Fail Function for Role Checks

```powershell
function Test-PrincipalRole {
    param(
        [Parameter(Mandatory = $true)] [string]$Assignee,
        [Parameter(Mandatory = $true)] [string]$RoleName,
        [Parameter(Mandatory = $true)] [string]$Scope
    )

    $count = az role assignment list `
        --assignee $Assignee `
        --scope $Scope `
        --include-inherited `
        --query "[?roleDefinitionName=='$RoleName'] | length(@)" `
        -o tsv

    if ([int]$count -gt 0) {
        Write-Host "PASS: $Assignee has $RoleName on $Scope" -ForegroundColor Green
        return $true
    }
    else {
        Write-Host "FAIL: $Assignee missing $RoleName on $Scope" -ForegroundColor Red
        return $false
    }
}

# Example usage
$subscriptionId = "<subscription-id>"
$resourceGroupName = "<target-rg>"
$developerPrincipal = "<developer-upn-or-object-id>"
$deployerPrincipal = "<deployer-upn-or-object-id>"

$rgScope = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName"

Test-PrincipalRole -Assignee $developerPrincipal -RoleName "Reader" -Scope $rgScope
Test-PrincipalRole -Assignee $deployerPrincipal -RoleName "Contributor" -Scope $rgScope
```

#### Troubleshooting RBAC Verification

- If no assignments appear, re-run with `--include-inherited` to include parent-scope assignments.
- If assignment exists but deployment still fails, verify the principal used by pipeline runtime matches the checked principal.
- If role was just assigned, wait a few minutes for RBAC propagation and retry.
- For service principals, verify tenant context and subscription context are correct before listing assignments.

### Platform Team Handoff Template

Use this copy/paste template in your platform request ticket.

```text
Title: RBAC + Deployment Request for Azure Monitor Hybrid Observability IaC

Repository: az-tracing
IaC Path: bicep/main.bicep
Environment: <dev|test|prod>
Subscription ID: <subscription-id>
Resource Group: <target-rg>
Region: <azure-region>

Requester (Developer): <developer-upn-or-object-id>
Deployer (Platform SPN/User): <deployer-upn-or-object-id>

Requested Access:
1) Developer -> Reader on target RG
2) Deployer -> Contributor on target RG
3) Optional: Deployer -> Network Contributor on NetworkWatcherRG (if used)
4) Optional: Deployer -> User Access Administrator (only if role assignments are automated in pipeline)

Requested Execution:
1) Apply role assignments
2) Run bicep validate
3) Run what-if
4) Run deployment using bicep/main.bicep and environment parameter file
5) Share deployment outputs and any failures
```

### One-Command-Set Script (Bash)

```bash
#!/usr/bin/env bash
set -euo pipefail

# ---------- Required Inputs ----------
subscriptionId="<subscription-id>"
resourceGroupName="<target-rg>"
location="<azure-region>"
deployerPrincipal="<deployer-upn-or-object-id>"
developerPrincipal="<developer-upn-or-object-id>"
paramFile="./main.dev.bicepparam"   # or ./main.prod.bicepparam
deploymentName="monitor-foundation-$(date +%Y%m%d%H%M%S)"

# ---------- Optional Inputs ----------
networkWatcherRg="NetworkWatcherRG"
grantNetworkContributor="false"      # true|false
grantUserAccessAdmin="false"         # true|false

echo "Setting subscription context..."
az account set --subscription "$subscriptionId"

echo "Ensuring resource group exists..."
az group create --name "$resourceGroupName" --location "$location" >/dev/null

echo "Assigning RBAC..."
az role assignment create --assignee "$developerPrincipal" --role "Reader" --scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName" || true
az role assignment create --assignee "$deployerPrincipal" --role "Contributor" --scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName" || true

if [ "$grantNetworkContributor" = "true" ]; then
  az role assignment create --assignee "$deployerPrincipal" --role "Network Contributor" --scope "/subscriptions/$subscriptionId/resourceGroups/$networkWatcherRg" || true
fi

if [ "$grantUserAccessAdmin" = "true" ]; then
  az role assignment create --assignee "$deployerPrincipal" --role "User Access Administrator" --scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName" || true
fi

echo "Validating Bicep..."
az bicep build --file ./main.bicep
az deployment group validate --name "$deploymentName-validate" --resource-group "$resourceGroupName" --template-file ./main.bicep --parameters "$paramFile"

echo "Previewing changes (what-if)..."
az deployment group what-if --name "$deploymentName-whatif" --resource-group "$resourceGroupName" --template-file ./main.bicep --parameters "$paramFile"

echo "Deploying..."
az deployment group create --name "$deploymentName" --resource-group "$resourceGroupName" --template-file ./main.bicep --parameters "$paramFile"

echo "Done."
```

### One-Command-Set Script (PowerShell)

```powershell
param(
    [Parameter(Mandatory = $true)] [string]$SubscriptionId,
    [Parameter(Mandatory = $true)] [string]$ResourceGroupName,
    [Parameter(Mandatory = $true)] [string]$Location,
    [Parameter(Mandatory = $true)] [string]$DeveloperPrincipal,
    [Parameter(Mandatory = $true)] [string]$DeployerPrincipal,
    [string]$ParamFile = "./main.dev.bicepparam",
    [string]$NetworkWatcherRg = "NetworkWatcherRG",
    [bool]$GrantNetworkContributor = $false,
    [bool]$GrantUserAccessAdmin = $false
)

$ErrorActionPreference = 'Stop'
$deploymentName = "monitor-foundation-$((Get-Date).ToString('yyyyMMddHHmmss'))"

Write-Host "Setting subscription context..."
az account set --subscription $SubscriptionId | Out-Null

Write-Host "Ensuring resource group exists..."
az group create --name $ResourceGroupName --location $Location | Out-Null

Write-Host "Assigning RBAC..."
az role assignment create --assignee $DeveloperPrincipal --role Reader --scope "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName" | Out-Null
az role assignment create --assignee $DeployerPrincipal --role Contributor --scope "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName" | Out-Null

if ($GrantNetworkContributor) {
    az role assignment create --assignee $DeployerPrincipal --role "Network Contributor" --scope "/subscriptions/$SubscriptionId/resourceGroups/$NetworkWatcherRg" | Out-Null
}

if ($GrantUserAccessAdmin) {
    az role assignment create --assignee $DeployerPrincipal --role "User Access Administrator" --scope "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName" | Out-Null
}

Write-Host "Validating Bicep..."
az bicep build --file ./main.bicep | Out-Null
az deployment group validate --name "$deploymentName-validate" --resource-group $ResourceGroupName --template-file ./main.bicep --parameters $ParamFile | Out-Null

Write-Host "Previewing changes (what-if)..."
az deployment group what-if --name "$deploymentName-whatif" --resource-group $ResourceGroupName --template-file ./main.bicep --parameters $ParamFile

Write-Host "Deploying..."
az deployment group create --name $deploymentName --resource-group $ResourceGroupName --template-file ./main.bicep --parameters $ParamFile

Write-Host "Done."
```

### Optional Rollback and Cleanup (Bash)

Use this only when you need to back out a failed deployment or remove a test environment.

```bash
#!/usr/bin/env bash
set -euo pipefail

# ---------- Required Inputs ----------
subscriptionId="<subscription-id>"
resourceGroupName="<target-rg>"
deploymentName="<deployment-name>"   # e.g., monitor-foundation-20260408153000

# ---------- Optional Inputs ----------
deleteResourceGroup="false"           # true|false
developerPrincipal="<developer-upn-or-object-id>"
deployerPrincipal="<deployer-upn-or-object-id>"
removeRoleAssignments="false"         # true|false

az account set --subscription "$subscriptionId"

echo "Checking deployment operations..."
az deployment operation group list \
  --resource-group "$resourceGroupName" \
  --name "$deploymentName" \
  --output table || true

echo "Deleting resources created by deployment where possible..."
resourceIds=$(az deployment operation group list \
  --resource-group "$resourceGroupName" \
  --name "$deploymentName" \
  --query "[?properties.provisioningOperation=='Create' && properties.targetResource.id!=null].properties.targetResource.id" \
  -o tsv || true)

if [ -n "${resourceIds:-}" ]; then
  while IFS= read -r id; do
    [ -z "$id" ] && continue
    echo "Deleting $id"
    az resource delete --ids "$id" || true
  done <<< "$resourceIds"
fi

if [ "$removeRoleAssignments" = "true" ]; then
  echo "Removing optional role assignments..."
  az role assignment delete --assignee "$developerPrincipal" --role "Reader" --scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName" || true
  az role assignment delete --assignee "$deployerPrincipal" --role "Contributor" --scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName" || true
fi

if [ "$deleteResourceGroup" = "true" ]; then
  echo "Deleting resource group $resourceGroupName"
  az group delete --name "$resourceGroupName" --yes --no-wait
fi

echo "Rollback/cleanup workflow completed."
```

### Optional Rollback and Cleanup (PowerShell)

Use this only when you need to back out a failed deployment or remove a test environment.

```powershell
param(
    [Parameter(Mandatory = $true)] [string]$SubscriptionId,
    [Parameter(Mandatory = $true)] [string]$ResourceGroupName,
    [Parameter(Mandatory = $true)] [string]$DeploymentName,
    [bool]$DeleteResourceGroup = $false,
    [bool]$RemoveRoleAssignments = $false,
    [string]$DeveloperPrincipal = "",
    [string]$DeployerPrincipal = ""
)

$ErrorActionPreference = 'Stop'

az account set --subscription $SubscriptionId | Out-Null

Write-Host "Checking deployment operations..."
az deployment operation group list --resource-group $ResourceGroupName --name $DeploymentName --output table

Write-Host "Deleting resources created by deployment where possible..."
$resourceIds = az deployment operation group list \
  --resource-group $ResourceGroupName \
  --name $DeploymentName \
  --query "[?properties.provisioningOperation=='Create' && properties.targetResource.id!=null].properties.targetResource.id" \
  -o tsv

if ($resourceIds) {
    $resourceIds.Split("`n") | ForEach-Object {
        $id = $_.Trim()
        if (-not [string]::IsNullOrWhiteSpace($id)) {
            Write-Host "Deleting $id"
            az resource delete --ids $id | Out-Null
        }
    }
}

if ($RemoveRoleAssignments) {
    if (-not [string]::IsNullOrWhiteSpace($DeveloperPrincipal)) {
        az role assignment delete --assignee $DeveloperPrincipal --role Reader --scope "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName" | Out-Null
    }
    if (-not [string]::IsNullOrWhiteSpace($DeployerPrincipal)) {
        az role assignment delete --assignee $DeployerPrincipal --role Contributor --scope "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName" | Out-Null
    }
}

if ($DeleteResourceGroup) {
    Write-Host "Deleting resource group $ResourceGroupName"
    az group delete --name $ResourceGroupName --yes --no-wait | Out-Null
}

Write-Host "Rollback/cleanup workflow completed."
```

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

## RBAC and Deployment Preflight Checklist

Use this checklist before running `validate`, `what-if`, or `create` deployments.

- [ ] Correct subscription context selected (`az account show` matches target subscription)
- [ ] Target resource group exists and is in the expected region
- [ ] Developer principal has `Reader` at target resource group scope
- [ ] Platform deployer principal has `Contributor` at target resource group scope
- [ ] If Network Watcher is in a separate resource group, deployer has `Network Contributor` on that scope
- [ ] If pipeline automates role assignments, deployer has `User Access Administrator` at required scope
- [ ] Role assignments validated with `az role assignment list --include-inherited`
- [ ] Bicep template compiles (`az bicep build --file ./main.bicep`)
- [ ] Parameter file selected correctly (`main.dev.bicepparam` or `main.prod.bicepparam`)
- [ ] `az deployment group validate` completed successfully
- [ ] `az deployment group what-if` reviewed and approved
- [ ] Required runtime inputs are ready (principal IDs, webhook URIs, email receiver addresses)
- [ ] RBAC propagation delay accounted for if roles were assigned recently (wait and re-check)

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
| `grafanaName` | Managed Grafana resource name |
| `oncallCriticalActionGroupId` | Resource ID of critical Action Group |
| `baselineDcrId` | Resource ID of baseline Data Collection Rule |
| `connectionMonitorResourceId` | Resource ID of baseline Connection Monitor |
| `m365TableResourceId` | Resource ID of baseline M365 custom table |

## Next Steps

After successful deployment:

1. **Onboard Applications**: Use the Application Insights instrumentation key to instrument HTTP applications (see Phase 2 of [IMPLEMENTATION_PLAN.md](../IMPLEMENTATION_PLAN.md))

2. **Configure Agents**: Deploy Azure Monitor Agent to Azure VMs and Arc-enabled on-premises servers using the Log Analytics Workspace ID (retrieve shared key via Azure CLI if needed)

3. **Set Up Grafana**: Configure Azure Monitor data source and dashboards in the provisioned Grafana instance

4. **Configure Alerts**: Populate Action Group receivers and tune baseline alert thresholds

5. **Enable Workload Integrations**: Complete SaaS and M365 telemetry pipelines as documented in phase 4

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

- **Template validation**: Run `az bicep build --file ./main.bicep` to validate syntax
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

**Version**: 1.1.0  
**Last Updated**: April 8, 2026  
**Maintained By**: Platform Engineering Team
