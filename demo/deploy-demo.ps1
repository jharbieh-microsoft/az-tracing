# Demo Solution Deployment Script
# Prerequisites: Azure CLI 2.50+, PowerShell 7+, jq (for JSON parsing)
# Usage: ./deploy-demo.ps1 -ResourceGroup "rg-demo-monitoring" -Location "eastus"

param(
    [string]$ResourceGroup = "rg-demo-monitoring",
    [string]$Location = "eastus",
    [string]$ResourcePrefix = "demotrace",
    [string]$Environment = "dev"
)

$ErrorActionPreference = "Stop"

Write-Host "=== Azure Monitor Demo Solution Deployment ===" -ForegroundColor Cyan
Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Green
Write-Host "Location: $Location" -ForegroundColor Green
Write-Host "Prefix: $ResourcePrefix" -ForegroundColor Green

# 1. Create Resource Group
Write-Host "`n[1/6] Creating Resource Group..." -ForegroundColor Yellow
az group create -n $ResourceGroup -l $Location

# 2. Deploy Infrastructure
Write-Host "`n[2/6] Deploying Bicep Infrastructure (Log Analytics, App Insights, Web App, Function App)..." -ForegroundColor Yellow
$deployment = az deployment group create `
  --name "demo-infrastructure" `
  --resource-group $ResourceGroup `
  --template-file "demo-infrastructure.bicep" `
  --parameters `
    resourcePrefix=$ResourcePrefix `
    environment=$Environment `
    location=$Location `
  --output json | ConvertFrom-Json

$workspaceId = $deployment.properties.outputs.workspaceId.value
$workspaceName = $deployment.properties.outputs.workspaceName.value
$appInsightsKey = $deployment.properties.outputs.appInsightsKey.value
$webAppUrl = $deployment.properties.outputs.webAppUrl.value
$functionAppName = ($deployment.properties.outputs.functionAppUrl.value -split '/')[-2]

Write-Host "✓ Infrastructure deployed successfully!" -ForegroundColor Green
Write-Host "  - Workspace: $workspaceName" -ForegroundColor Gray
Write-Host "  - App Insights Key: $($appInsightsKey.Substring(0,8))..." -ForegroundColor Gray
Write-Host "  - Web App URL: $webAppUrl" -ForegroundColor Gray

# 3. Deploy Data Collection Rules to Azure
Write-Host "`n[3/6] Deploying Data Collection Rules..." -ForegroundColor Yellow

# Azure VM DCR
az deployment group create `
  --name "dcr-azure-vm" `
  --resource-group $ResourceGroup `
  --template-file "dcr-azure-vm.json" `
  --output none

# Data Center VM DCR
az deployment group create `
  --name "dcr-datadc-vm" `
  --resource-group $ResourceGroup `
  --template-file "dcr-datadc-vm.json" `
  --output none

Write-Host "✓ Data Collection Rules deployed!" -ForegroundColor Green

# 4. Deploy Azure VM with AMA
Write-Host "`n[4/6] Deploying Azure VM with Azure Monitor Agent..." -ForegroundColor Yellow

# Create VM
az vm create `
  -g $ResourceGroup `
  -n "vm-azure-demo" `
  --image Win2022Datacenter `
  --size Standard_B2s `
  --admin-username "azureuser" `
  --generate-ssh-keys `
  --output none

# Deploy AMA extension
az vm extension set `
  --resource-group $ResourceGroup `
  --vm-name "vm-azure-demo" `
  --name "AzureMonitorWindowsAgent" `
  --publisher "Microsoft.Azure.Monitor" `
  --version "1.12" `
  --output none

# Associate DCR with VM
$vmResourceId = az vm show -g $ResourceGroup -n "vm-azure-demo" --query id -o tsv
$dcrResourceId = az resource list -g $ResourceGroup --resource-type "Microsoft.Insights/dataCollectionRules" --query "[0].id" -o tsv

az monitor data-collection rule association create `
  --name "dcr-azure-vm-assoc" `
  --rule-id $dcrResourceId `
  --resource $vmResourceId `
  --output none

Write-Host "✓ Azure VM deployed and configured!" -ForegroundColor Green
Write-Host "  - VM Name: vm-azure-demo" -ForegroundColor Gray
Write-Host "  - Agent will be ready in ~10 minutes" -ForegroundColor Gray

# 5. Configure Function App for GitHub Metrics
Write-Host "`n[5/6] Configuring Azure Function for GitHub API Polling..." -ForegroundColor Yellow

# Get workspace shared key
$workspaceKey = az monitor log-analytics workspace get-shared-keys `
  -g $ResourceGroup `
  -n $workspaceName `
  --query "primarySharedKey" -o tsv

# Set Function App settings
az functionapp config appsettings set `
  -g $ResourceGroup `
  -n $functionAppName `
  --settings `
    WORKSPACE_ID=$workspaceId `
    SHARED_KEY=$($workspaceKey) `
    GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxx" `
  --output none

Write-Host "✓ Function App configured!" -ForegroundColor Green
Write-Host "  - TODO: Update GITHUB_TOKEN in Azure Portal" -ForegroundColor Yellow
Write-Host "  - Function: GitHubMetrics" -ForegroundColor Gray

# 6. Import Workbook
Write-Host "`n[6/6] Importing Sample Workbook..." -ForegroundColor Yellow

$workbookId = New-Guid
az resource create `
  -g $ResourceGroup `
  --resource-type "microsoft.insights/workbooks" `
  --name "demo-dashboard-$($workbookId.ToString().Substring(0,8))" `
  -p "@workbook-template.json" `
  --output none

Write-Host "✓ Workbook imported!" -ForegroundColor Green

# Summary
Write-Host "`n" -ForegroundColor Cyan
Write-Host "╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  DEPLOYMENT COMPLETE - NEXT STEPS                        ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

Write-Host @"

1. CONFIGURE GITHUB TOKEN
   - Go to: Azure Portal → $functionAppName → Configuration
   - Update GITHUB_TOKEN with your GitHub personal access token
   - Function will start collecting metrics in 5 minutes

2. TEST DATA COLLECTION (after 10 minutes)
   Run these queries in Log Analytics:
   
   - Web App metrics: AppRequests | summarize count() by bin(TimeGenerated, 5m)
   - VM metrics: Perf | where Computer == 'vm-azure-demo' | summarize avg(CounterValue) by ObjectName
   - GitHub metrics: GitHubMetrics_CL | summarize count()

3. GENERATE LOAD (optional)
   npm install -g artillery
   artillery run load-test.yml

4. VIEW DASHBOARD
   - Go to Azure Portal → Log Analytics → Workbooks → "demo-dashboard"
   - Monitor unified telemetry across all sources

5. CONFIGURE ALERTS (see demo-alerts.json)
   Create email/webhook alerts for:
   - High response time (> 2s)
   - High CPU (> 80%)
   - High memory (> 85%)
   - Errors in event log

6. ON-PREMISES VM (Optional)
   To add your data center VM:
   
   a) Run on data center server:
      Invoke-WebRequest -Uri "https://aka.ms/arcagentwinscript" -OutFile "AzureConnectedMachineAgent.msi"
      msiexec.exe /i AzureConnectedMachineAgent.msi
      
   b) Register with Azure Arc:
      & "$env:ProgramFiles\AzureConnectedMachineAgent\azcmagent.exe" connect `
        --service-principal-id "<sp-id>" `
        --service-principal-secret "<sp-secret>" `
        --resource-group "$ResourceGroup" `
        --tenant-id "<tenant-id>" `
        --location "$Location"

   c) Verify connection:
      & "$env:ProgramFiles\AzureConnectedMachineAgent\azcmagent.exe" show

RESOURCE IDS:
───────────────────────────────────────────────────────────
Workspace ID: $workspaceId
Workspace Name: $workspaceName
Web App URL: $webAppUrl
Function App: $functionAppName
───────────────────────────────────────────────────────────

For detailed instructions, see: DEMO_SOLUTION.md
"@

Write-Host "Deployment completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Green
