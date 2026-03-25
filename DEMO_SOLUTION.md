# Unified Monitoring Solution Demo

End-to-end demonstration of the Azure Monitor hybrid observability platform with sample components for Web App, Azure VM, Data Center VM, and SaaS integration.

## Demo Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                   │
│  Azure Subscription                                              │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                                                             │  │
│  │  ┌─────────────────────┐    ┌──────────────────────┐     │  │
│  │  │  Azure App Service  │    │  Azure Virtual       │     │  │
│  │  │  (Web Application)  │    │  Machine             │     │  │
│  │  │  - Sample .NET App  │    │  - Windows Server    │     │  │
│  │  │  - App Insights SDK │    │  - IIS Web Server    │     │  │
│  │  └─────────┬───────────┘    │  - AMA + DCR         │     │  │
│  │            │                 └──────────┬───────────┘     │  │
│  │            │                            │                  │  │
│  │            └────────────┬───────────────┘                  │  │
│  │                         ↓                                   │  │
│  │            ┌─────────────────────────┐                     │  │
│  │            │  Log Analytics          │                     │  │
│  │            │  Workspace              │                     │  │
│  │            │  ├─ AppRequests         │                     │  │
│  │            │  ├─ Perf                │                     │  │
│  │            │  ├─ Event               │                     │  │
│  │            │  └─ CustomMetrics_CL    │                     │  │
│  │            └────────────┬────────────┘                     │  │
│  │                         │                                   │  │
│  │            ┌────────────┴────────────┐                     │  │
│  │            ↓                         ↓                      │  │
│  │     ┌────────────────┐      ┌───────────────┐              │  │
│  │     │   Workbooks    │      │  Alerts       │              │  │
│  │     │   & Dashboards │      │  & Action     │              │  │
│  │     │                │      │  Groups       │              │  │
│  │     └────────────────┘      └───────────────┘              │  │
│  │                                                             │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  On-Premises Data Center                                         │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                                                             │  │
│  │  ┌─────────────────────────────────────────────────┐      │  │
│  │  │  Virtual Machine (Windows Server)               │      │  │
│  │  │  - Sample ASP.NET App                           │      │  │
│  │  │  - IIS Web Server                               │      │  │
│  │  │  - Azure Arc Agent                              │      │  │
│  │  │  - Azure Monitor Agent (DCR-based)              │      │  │
│  │  │  - Sends telemetry via HTTPS to Azure           │      │  │
│  │  └──────────────────┬───────────────────────────────┘      │  │
│  │                     │                                       │  │
│  │                     │ (Outbound HTTPS only)                │  │
│  │                     │ to Log Analytics                     │  │
│  │                     │                                       │  │
│  └─────────────────────┼───────────────────────────────────────┘  │
│                        │                                           │
└────────────────────────┼───────────────────────────────────────────┘
                         │
        ┌────────────────┴────────────────┐
        │                                 │
        ↓                                 ↓
┌──────────────────┐         ┌─────────────────────┐
│  SaaS APIs       │         │  Azure Services     │
│  ├─ GitHub API   │         │  ├─ Event Hubs      │
│  ├─ Stripe API   │         │  ├─ Functions       │
│  └─ Other APIs   │         │  └─ Logic Apps      │
└──────────────────┘         └─────────────────────┘
        ↑                            ↓
        └────────────────┬───────────┘
                         ↓
                [HTTP Data Collector API]
                         ↓
              Log Analytics Workspace
                (Centralized data store)
```

---

## Components & Demo Files

### 1. Infrastructure Setup (Bicep)

The `demo-infrastructure.bicep` deploys:
- Log Analytics Workspace
- Application Insights
- Azure App Service Plan
- Action Group for alerts
- Sample diagnostic settings

### 2. Sample Web Application

A simple .NET Core web application with Application Insights instrumentation that:
- Records HTTP request/response telemetry
- Tracks custom events (user actions, business metrics)
- Logs exceptions
- Sends data to Application Insights

### 3. Azure VM Setup

A Windows Server VM in Azure with:
- IIS installed
- Sample ASP.NET application deployed
- Azure Monitor Agent with Data Collection Rules
- Collects: IIS logs, performance counters, application events

### 4. Data Center VM Setup

A Windows Server VM (on-premises or SCVMM) with:
- Azure Arc Agent registered
- Azure Monitor Agent deployed via Arc policy
- Data Collection Rule for on-premises monitoring
- Demonstrates hybrid connectivity (no inbound required)

### 5. SaaS Integration

Azure Function + Timer Trigger that:
- Polls a public SaaS API (example: GitHub API)
- Sends metrics to Log Analytics via HTTP Data Collector API
- Simulates real-world SaaS data ingestion

---

## Demo Steps

### Prerequisite: Setup

1. **Azure Subscription**: Subscription with Contributor access
2. **Resource Group**: `rg-demo-monitoring`
3. **Region**: `eastus`
4. **Local Tools**:
   - Azure CLI (version 2.50+)
   - PowerShell 7+
   - Git
   - .NET 8 SDK (if building sample app locally)

### Step 1: Deploy Foundation (5 minutes)

Deploy the Bicep infrastructure:

```bash
# Create resource group
az group create -n rg-demo-monitoring -l eastus

# Deploy infrastructure
az deployment group create \
  --name demo-monitoring \
  --resource-group rg-demo-monitoring \
  --template-file ./bicep/demo-infrastructure.bicep \
  --parameters \
    resourcePrefix=demotrace \
    environment=dev \
    logAnalyticsRetentionInDays=30
```

**Output**:
```
Workspace ID: 12345678-1234-5678-1234-567812345678
Instrumentation Key: a1b2c3d4-e5f6-7890-1234-5678901234567
```

### Step 2: Deploy Azure Web App (10 minutes)

Deploy a sample Node.js web app with Application Insights:

```bash
# Create App Service Plan
az appservice plan create \
  -g rg-demo-monitoring \
  -n plan-demo-trace \
  --sku B1 \
  --is-linux

# Create Web App
az webapp create \
  -g rg-demo-monitoring \
  -p plan-demo-trace \
  -n app-demo-trace-$(date +%s) \
  --runtime "node|18-lts"

# Configure Application Insights
APP_ID=$(az resource list -g rg-demo-monitoring \
  --resource-type "microsoft.insights/components" \
  -o tsv --query "[0].id")

az webapp config appsettings set \
  -g rg-demo-monitoring \
  -n app-demo-trace-* \
  --settings APPINSIGHTS_INSTRUMENTATIONKEY={your-key}

# Deploy sample app
git clone https://github.com/Azure-Samples/nodejs-docs-hello-world.git
cd nodejs-docs-hello-world
az webapp deployment source config-zip \
  -g rg-demo-monitoring \
  -n app-demo-trace-* \
  --src app.zip
```

**Verify**: Navigate to web app URL, verify requests appear in Application Insights.

### Step 3: Deploy Azure VM (15 minutes)

Deploy a Windows Server VM with IIS and monitoring:

```bash
# Create VM
az vm create \
  -g rg-demo-monitoring \
  -n vm-azure-demo \
  --image Win2022Datacenter \
  --size Standard_B2s \
  --admin-username azureuser \
  --admin-password '<secure-password>'

# Get VM resource ID
VM_ID=$(az vm show -g rg-demo-monitoring -n vm-azure-demo --query id -o tsv)

# Deploy Azure Monitor Agent extension
az vm extension set \
  --resource-group rg-demo-monitoring \
  --vm-name vm-azure-demo \
  --name AzureMonitorWindowsAgent \
  --publisher Microsoft.Azure.Monitor \
  --version 1.12

# Create Data Collection Rule for Azure VM
az monitor data-collection rule create \
  -g rg-demo-monitoring \
  -n dcr-azure-vm \
  --description "Monitor Azure VM with IIS and perf counters" \
  --rule-file dcr-azure-vm.json

# Associate DCR with VM
az monitor data-collection rule association create \
  --name dcr-azure-vm \
  --rule-id /subscriptions/{subId}/resourceGroups/rg-demo-monitoring/providers/Microsoft.Insights/dataCollectionRules/dcr-azure-vm \
  --resource /subscriptions/{subId}/resourceGroups/rg-demo-monitoring/providers/Microsoft.Compute/virtualMachines/vm-azure-demo
```

**Verify**: In 5 minutes, Perf and Event tables appear in Log Analytics.

### Step 4: Setup Data Center VM (20 minutes)

Simulate on-premises monitoring:

```powershell
# 1. On your data center server, run as Administrator:

# Download and install Arc Agent
$ProgressPreference = "SilentlyContinue"
Invoke-WebRequest -Uri "https://aka.ms/arcagentwinscript" -OutFile "AzureConnectedMachineAgent.msi"
msiexec.exe /i AzureConnectedMachineAgent.msi /l*v installationlog.txt

# 2. Register with Azure Arc
$ServicePrincipalId = "<your-sp-id>"
$ServicePrincipalSecret = "<your-sp-secret>"
$TenantId = "<your-tenant-id>"

& "$env:ProgramFiles\AzureConnectedMachineAgent\azcmagent.exe" connect `
  --service-principal-id $ServicePrincipalId `
  --service-principal-secret $ServicePrincipalSecret `
  --resource-group rg-demo-monitoring `
  --tenant-id $TenantId `
  --location eastus `
  --tags environment=demo application=datacenter

# 3. Verify connection
& "$env:ProgramFiles\AzureConnectedMachineAgent\azcmagent.exe" show

# 4. Deploy Azure Monitor Agent
az vm extension set \
  --resource-group rg-demo-monitoring `
  --machine-name vm-datadc-demo `
  --name AzureMonitorWindowsAgent `
  --publisher Microsoft.Azure.Monitor `
  --version 1.12 `
  --settings '{"authentication":{"managedIdentity":{"enabled":true}}}'

# 5. Create DCR for data center VM (same as Azure VM)
az monitor data-collection rule create \
  -g rg-demo-monitoring \
  -n dcr-datadc-vm \
  --rule-file dcr-datadc-vm.json
```

**Verify**: Arc machine appears in Azure Portal with "Connected" status.

### Step 5: Deploy SaaS Integration (10 minutes)

Create an Azure Function that polls GitHub API and sends metrics:

```bash
# Create Storage Account (required for Functions)
az storage account create \
  -g rg-demo-monitoring \
  -n stgdemotrace$(date +%s) \
  --sku Standard_LRS

# Create Function App
az functionapp create \
  -g rg-demo-monitoring \
  -n func-demo-saas \
  --storage-account stgdemotrace* \
  --runtime node \
  --runtime-version 18 \
  --functions-version 4

# Deploy function code
cd demo
func azure functionapp publish func-demo-saas --build remote

# Configure workspace credentials in Function App settings
az functionapp config appsettings set \
  -g rg-demo-monitoring \
  -n func-demo-saas \
  --settings \
    WORKSPACE_ID="{workspace-uuid}" \
    SHARED_KEY="{workspace-shared-key}" \
    GITHUB_TOKEN="{your-github-token}"
```

**Verify**: Check "GitHubMetrics_CL" table in Log Analytics after 5 minutes.

### Step 6: Create Dashboards & Alerts (10 minutes)

Create a sample Workbook:

```bash
# Deploy workbook from JSON template
az resource create \
  -g rg-demo-monitoring \
  --resource-type microsoft.insights/workbooks \
  --name demo-workbook \
  -p @workbook-template.json
```

Create sample alerts:

```bash
# Alert: High response time
az monitor metrics alert create \
  -g rg-demo-monitoring \
  -n alert-high-response-time \
  --description "Alert when avg response time > 2 seconds" \
  --scopes /subscriptions/{subId}/resourceGroups/rg-demo-monitoring/providers/microsoft.insights/components/appi-demotrace-dev \
  --condition "avg HttpResponseTime > 2000" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --action /subscriptions/{subId}/resourceGroups/rg-demo-monitoring/providers/microsoft.insights/actionGroups/ag-demotrace-dev

# Alert: VM CPU > 80%
az monitor metrics alert create \
  -g rg-demo-monitoring \
  -n alert-high-cpu \
  --description "Alert when VM CPU > 80% for 5 minutes" \
  --scopes /subscriptions/{subId}/resourceGroups/rg-demo-monitoring/providers/microsoft.compute/virtualMachines/vm-azure-demo \
  --condition "avg Percentage CPU > 80" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --action /subscriptions/{subId}/resourceGroups/rg-demo-monitoring/providers/microsoft.insights/actionGroups/ag-demotrace-dev
```

---

## Validate Data Flow

### Check Application Insights (Azure Web App)

```kusto
// Run in Log Analytics
AppRequests
| where TimeGenerated > ago(1h)
| summarize RequestCount = count(), AvgDuration = avg(DurationMs) by bin(TimeGenerated, 5m)
| render timechart
```

### Check Azure VM Telemetry

```kusto
// Performance data from Azure VM
Perf
| where Computer == "vm-azure-demo"
| where ObjectName == "Processor"
| summarize AvgCPU = avg(CounterValue) by bin(TimeGenerated, 5m)
| render timechart
```

### Check Data Center VM Telemetry

```kusto
// Performance data from Arc-connected on-premises VM
Perf
| where Computer == "vm-datadc-demo"
| where ObjectName == "LogicalDisk"
| summarize AvgDiskUtilization = avg(CounterValue) by bin(TimeGenerated, 5m)
| render timechart
```

### Check SaaS Integration

```kusto
// GitHub metrics from Azure Function
GitHubMetrics_CL
| summarize RepoCount = max(repo_count_d), TotalStars = max(total_stars_d) by timestamp_t
| render columnchart
```

### Unified Dashboard Query

```kusto
// Combine data from all sources
union
  (AppRequests | project TimeGenerated, Source="WebApp", Duration=DurationMs),
  (Perf | where Computer == "vm-azure-demo" | project TimeGenerated, Source="AzureVM", Duration=CounterValue),
  (Perf | where Computer == "vm-datadc-demo" | project TimeGenerated, Source="DataCenterVM", Duration=CounterValue),
  (GitHubMetrics_CL | project TimeGenerated, Source="GitHub", Duration=toreal(repo_count_d))
| summarize AvgValue = avg(Duration) by Source, bin(TimeGenerated, 5m)
| render timechart
```

---

## Demo Walkthrough (Live)

**Duration**: ~2 hours setup, ~30 minutes recurrence

### Timeline

| Time | Activity | Expected Outcome |
|------|----------|------------------|
| 0:00–0:05 | Deploy Bicep infrastructure | Workspace created, ready for data |
| 0:05–0:15 | Deploy Azure Web App | App Insights keys configured |
| 0:15–0:30 | Deploy Azure VM + AMA | VM shows in Portal as Arc-connected (if hybrid) |
| 0:30–0:50 | Setup Data Center VM | Arc Agent connects, shows "Connected" |
| 0:50–1:00 | Deploy SaaS Function | Timer trigger runs, posts to Log Analytics |
| 1:00–1:15 | Create Dashboards | Workbook displays unified data |
| 1:15–1:30 | Configure Alerts | Alert rules active, ready to fire |
| 1:30–2:00 | Generate Load & Test | Telemetry flows to all tables |

### Load Generation

Generate traffic to test the pipeline:

```bash
# Install load testing tool
npm install -g artillery

# Create load test config
cat > load-test.yml <<EOF
config:
  target: "https://app-demo-trace-*.azurewebsites.net"
  phases:
    - duration: 60
      arrivalRate: 10
      name: "Warm up"
    - duration: 120
      arrivalRate: 50
      name: "Ramp up"
scenarios:
  - name: "User Journey"
    flow:
      - get:
          url: "/"
      - get:
          url: "/api/products"
      - post:
          url: "/api/orders"
          json:
            product_id: 123
            quantity: 5
EOF

# Run load test
artillery run load-test.yml
```

**Result**: Watch telemetry appear in Log Analytics in real-time.

---

## Cleanup

Delete all demo resources:

```bash
# Delete entire resource group
az group delete -n rg-demo-monitoring --yes --no-wait

# Disconnect Arc machine (if data center VM is still accessible)
azcmagent disconnect --force-flag-all
```

---

## Key Learnings from Demo

1. **Multi-Source Ingestion**: All sources (web app, Azure VM, data center, SaaS) send to single workspace
2. **Unified Querying**: One KQL query correlates across all sources
3. **Zero Inbound Required**: Data center VM uses outbound HTTPS only
4. **Real-Time Visibility**: Dashboard updates every 5 minutes
5. **Cost Efficiency**: Only pay for ingested data, not number of agents
6. **Scalability**: Same pattern works for 10 or 1,000 sources

---

## Next Steps

After successful demo:

1. **Customize DCRs**: Adjust data collection per your actual VMs
2. **Extend SaaS Integration**: Add more API polling functions
3. **Build Custom Dashboards**: Create Workbooks for your KPIs
4. **Define SLOs**: Create alert rules based on business metrics
5. **Automate Response**: Add Logic Apps for incident response
6. **Scale to Production**: Migrate patterns to prod resource group

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Application Insights data missing | Verify instrumentation key in app config, restart app |
| Azure VM data gap | Check AMA status: `Get-Service -Name AzureMonitoringAgent` |
| Data Center VM not sending | Verify Arc agent: `azcmagent show`, check HTTPS routing |
| SaaS metrics not appearing | Check Function logs, verify shared key and workspace ID |
| High ingestion costs | Reduce performance counter frequency, filter event logs |

---

## Demo Files Provided

- `demo-infrastructure.bicep` — Complete IaC for all components
- `dcr-azure-vm.json` — Data Collection Rule for Azure VM
- `dcr-datadc-vm.json` — Data Collection Rule for Data Center VM
- `azure-function-github-metrics.js` — Function app implementation for GitHub API polling
- `function.json` — Timer trigger configuration for the SaaS demo function
- `package.json` — Node.js package manifest for the SaaS demo function
- `workbook-template.json` — Sample Workbook with unified queries
- `deploy-demo.ps1` — Automated deployment script for the demo environment
- `DEPLOYMENT_REFERENCE.md` — Quick deployment and validation reference
- `load-test.yml` — Artillery load test configuration
- `demo-alerts.json` — Sample alert rules (JSON)
- `TROUBLESHOOTING.md` — Diagnostic guide for deployment and data collection issues

---

**Demo Version**: 1.0.0  
**Last Updated**: March 25, 2026  
**Estimated Time to Complete**: 15-20 minutes (automated deployment), 2 hours (manual walkthrough)
