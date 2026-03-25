# Demo Solution - Troubleshooting Guide

## Quick Test Commands

### 1. Verify Infrastructure Deployed Successfully

```bash
# Check all resources in resource group
az resource list --resource-group "rg-demo-monitoring" -o table

# Check Log Analytics workspace
az monitor log-analytics workspace list -g "rg-demo-monitoring" -o table

# Test Log Analytics connectivity
az monitor log-analytics workspace data-export list -g "rg-demo-monitoring" -w "law-demotrace-dev"
```

### 2. Verify Data Collection

If no data appears in Log Analytics after 15 minutes, run these diagnostics:

#### For Azure VM:

```bash
# 1. Check if AMA extension is installed
az vm extension list -g "rg-demo-monitoring" --vm-name "vm-azure-demo" -o table

# 2. Check if DCR is associated
az monitor data-collection rule association list --resource "/subscriptions/{subId}/resourceGroups/rg-demo-monitoring/providers/Microsoft.Compute/virtualMachines/vm-azure-demo"

# 3. RDP into VM and check AMA service status
# From Windows VM:
# a) Check service running: Get-Service AzureMonitorAgent
# b) Check logs: Get-WinEvent -LogName "Application" -FilterXPath "*[System[Provider[@Name='AzureMonitorAgent']]]" -MaxEvents 10

# 4. Verify DCR syntax (if still blank after service check)
az monitor data-collection rule list -g "rg-demo-monitoring" -o json | jq -r '.[].id'
```

#### For Function App (GitHub Metrics):

```bash
# 1. Check Function App configuration
az functionapp config appsettings list -g "rg-demo-monitoring" -n "func-demotrace-dev" | grep -E "WORKSPACE|SHARED|GITHUB"

# 2. Check deployment status
az functionapp deployment list -g "rg-demo-monitoring" -n "func-demotrace-dev"

# 3. View function execution logs
az monitor log-analytics query -w "law-demotrace-dev" \
  --analytics-query 'FunctionAppLogs | where FunctionName == "GitHubMetrics" | top 20 by TimeGenerated'

# 4. Verify GitHub token is valid (test HTTP call)
curl -H "Authorization: token YOUR_GITHUB_TOKEN" https://api.github.com/user
```

#### For Web App:

```bash
# 1. Check App Insights instrumentation
az webapp config appsettings list -g "rg-demo-monitoring" -n "web-demotrace-dev" | grep -i "instrumentation"

# 2. Test web app endpoint
curl -I "https://web-demotrace-dev.azurewebsites.net"

# 3. Check for AppRequests in Log Analytics
az monitor log-analytics query -w "law-demotrace-dev" \
  --analytics-query 'AppRequests | top 20 by TimeGenerated'
```

## Common Issues and Solutions

### Issue 1: "No data appearing in Log Analytics"

**Cause 1a: Data Collection Rule not attached to VM**
```bash
# Check if DCR is associated
$vm = az vm show -g "rg-demo-monitoring" -n "vm-azure-demo" --query id -o tsv
az monitor data-collection rule association list --resource $vm

# If empty, manually create association
$dcrId = az resource show -g "rg-demo-monitoring" --name "dcr-azure-vm" --resource-type "Microsoft.Insights/dataCollectionRules" --query id -o tsv
az monitor data-collection rule association create \
  --name "dcr-azure-vm-bind" \
  --rule-id $dcrId \
  --resource $vm
```

**Cause 1b: AMA extension not installed**
```bash
# Install extension
az vm extension set \
  --resource-group "rg-demo-monitoring" \
  --vm-name "vm-azure-demo" \
  --name "AzureMonitorWindowsAgent" \
  --publisher "Microsoft.Azure.Monitor" \
  --version "1.12"

# Wait 5 minutes for agent to initialize, then verify:
# RDP to VM and run: Get-Service AzureMonitorAgent | Select Status
```

**Cause 1c: AMA service not running in VM**
```powershell
# From inside VM (PowerShell as Admin):

# Start the service
Start-Service AzureMonitorAgent

# Check status
Get-Service AzureMonitorAgent

# View recent errors
Get-WinEvent -LogName "Application" | Where-Object {$_.ProviderName -eq "AzureMonitorAgent"} | Select TimeCreated, Message | head -20

# If stopped, check why
Get-WinEvent -LogName "Application" | Where-Object {$_.EventID -eq 1000} | head -5
```

### Issue 2: "GITHUB_TOKEN not found in Function App"

```bash
# Check if environment variable is set
az functionapp config appsettings list -g "rg-demo-monitoring" -n "func-demotrace-dev"

# If missing, add it
az functionapp config appsettings set \
  -g "rg-demo-monitoring" \
  -n "func-demotrace-dev" \
  --settings GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# Verify it's set
az functionapp config appsettings list -g "rg-demo-monitoring" -n "func-demotrace-dev" | grep GITHUB_TOKEN
```

### Issue 3: "Function fails with 401 Unauthorized"

This means workspace credentials are wrong:

```bash
# Get correct workspace ID and key
$workspaceId = az monitor log-analytics workspace show -g "rg-demo-monitoring" -n "law-demotrace-dev" --query customerId -o tsv
$workspaceKey = az monitor log-analytics workspace get-shared-keys -g "rg-demo-monitoring" -n "law-demotrace-dev" --query primarySharedKey -o tsv

# Update Function App settings
az functionapp config appsettings set \
  -g "rg-demo-monitoring" \
  -n "func-demotrace-dev" \
  --settings \
    WORKSPACE_ID="$workspaceId" \
    SHARED_KEY="$workspaceKey"

# Verify
az functionapp config appsettings list -g "rg-demo-monitoring" -n "func-demotrace-dev" | grep -E "WORKSPACE|SHARED"
```

### Issue 4: "Workbook shows empty visualizations"

Check if KQL queries are valid:

```bash
# Test each query manually
$workspaceName = "law-demotrace-dev"

# Query 1: Web app requests
az monitor log-analytics query -w $workspaceName --analytics-query 'AppRequests | summarize count() by bin(TimeGenerated, 5m)'

# Query 2: VM performance
az monitor log-analytics query -w $workspaceName --analytics-query 'Perf | where Computer == "vm-azure-demo" | summarize avg(CounterValue) by ObjectName'

# Query 3: GitHub metrics
az monitor log-analytics query -w $workspaceName --analytics-query 'GitHubMetrics_CL | top 10 by TimeGenerated'

# Query 4: Combined
az monitor log-analytics query -w $workspaceName --analytics-query '
union AppRequests, Perf, GitHubMetrics_CL |
summarize count() by SourceSystem
'
```

### Issue 5: "Function App deployment failed"

```bash
# Check deployment logs
az functionapp deployment list -g "rg-demo-monitoring" -n "func-demotrace-dev" --output table

# If failed, view detailed error
$deploymentId = az functionapp deployment list -g "rg-demo-monitoring" -n "func-demotrace-dev" --query "[0].id" -o tsv
az functionapp deployment show --deployment-id $deploymentId -g "rg-demo-monitoring" -n "func-demotrace-dev"

# Redeploy
func azure functionapp publish func-demotrace-dev
```

## Validation Test Sequence

Run these 5 checks in order to validate entire demo:

### Test 1: Infrastructure Exists (2 minutes)
```bash
$rg = "rg-demo-monitoring"

# All 5 core resources should exist
az resource list -g $rg --query "length([].id)"  # Should be ~5

# Workspace is accessible
az monitor log-analytics workspace show -g $rg -n "law-demotrace-dev"

# Function App is running
az functionapp show -g $rg -n "func-demotrace-dev" | grep state
```

**Expected Output:** `state: Running`

### Test 2: AMA Deployed and Connected (10 minutes)
```bash
# Check extension installed
az vm extension list -g "rg-demo-monitoring" --vm-name "vm-azure-demo" | grep AzureMonitor

# RDP to VM and verify service
# Get-Service AzureMonitorAgent | Select Status

# Should show: Status: Running
```

### Test 3: Data Flowing to Log Analytics (15 minutes)

```bash
$workspaceName = "law-demotrace-dev"

# Check for Perf data (from VM)
az monitor log-analytics query -w $workspaceName --analytics-query 'Perf | where Computer == "vm-azure-demo" | summarize count()'

# Should return: count_ > 0

# Check for GitHub data (from Function)
az monitor log-analytics query -w $workspaceName --analytics-query 'GitHubMetrics_CL | summarize count()'

# Should return: count_ > 0
```

### Test 4: Workbook Renders (15 minutes)

Go to Azure Portal:
1. Enter resource group "rg-demo-monitoring"
2. Click on workbook name (starts with "demo-dashboard")
3. Each visualization should show:
   - Web App chart: Line graph with requests over time
   - VM CPU: Line graph with CPU % over time
   - VM Memory: Line graph with memory % over time
   - GitHub Metrics: Table with recent GitHub data

### Test 5: Load Test Works (Optional)

```bash
# Install artillery
npm install -g artillery

# Get web app URL
$webAppUrl = az webapp show -g "rg-demo-monitoring" -n "web-demotrace-dev" --query defaultHostName -o tsv

# Run load test (5 minutes)
artillery quick --count 10 --duration 5 --rate 2 "https://$webAppUrl"

# Should show:
# - Requests: 100+
# - Response times: 50-500ms
# - Success rate: 95%+
```

After 5 minutes, check workbook - you should see traffic spike in AppRequests chart.

## Resource Cleanup

To delete all resources and stop incurring costs:

```bash
# Delete entire resource group (permanent!)
az group delete -n "rg-demo-monitoring" --yes

# Verify deletion
az group exists -n "rg-demo-monitoring"  # Should return: false
```

## Support Resources

- **Azure Monitor Agent docs**: https://learn.microsoft.com/en-us/azure/azure-monitor/agents/azure-monitor-agent-overview
- **Data Collection Rules**: https://learn.microsoft.com/en-us/azure/azure-monitor/essentials/data-collection-rule-overview
- **Log Analytics Query language**: https://learn.microsoft.com/en-us/azure/kusto/query/
- **Function App troubleshooting**: https://learn.microsoft.com/en-us/azure/azure-functions/functions-diagnostics
