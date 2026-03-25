# Deployment Reference Card

## One-Liner: Fastest Path to Demo

```powershell
cd demo; ./deploy-demo.ps1 -ResourceGroup "rg-demo-monitoring" -Location "eastus"
```

**Duration:** 15-20 minutes  
**Next Steps:** Update GITHUB_TOKEN, wait 15 minutes for data, run load test

---

## Step-by-Step Timeline

| Step | Command | Duration |
|------|---------|----------|
| 1 | Create Resource Group | 1 min |
| 2 | Deploy Infrastructure (Bicep) | 5 min |
| 3 | Deploy Data Collection Rules | 2 min |
| 4 | Create Azure VM + AMA | 8 min |
| 5 | Configure Function App | 2 min |
| 6 | Import Workbook | 1 min |
| **Total** | **All automated** | **~20 min** |

---

## Validation Timeline

| Time | Action | Expected Result |
|------|--------|-----------------|
| T+0 | Start deployment script | Script running |
| T+20 | Script completes | All resources created |
| T+21 | Update GITHUB_TOKEN | Token set in Function App |
| T+35 | Check Perf data | Perf table has ~5-10 rows from vm-azure-demo |
| T+40 | Run load test | artillery CLI running |
| T+45 | View dashboard | Workbook shows 4 data sources |

---

## Key Commands (if Manual)

### Check what data is flowing

```bash
# Check Log Analytics workspace exists
az monitor log-analytics workspace list -g "rg-demo-monitoring" -o table

# Workspace ID and name
WORKSPACE=$(az monitor log-analytics workspace show -g "rg-demo-monitoring" \
  -w "law-demotrace-dev" --query customerId -o tsv)
echo "Workspace ID: $WORKSPACE"

# Test web app
curl -I "https://web-demotrace-dev.azurewebsites.net"

# Count records by table (in Log Analytics Portal):
# Perf | count
# AppRequests | count
# GitHubMetrics_CL | count
# Event | count
```

### Update Function App credentials

```bash
# Get workspace credentials
WID=$(az monitor log-analytics workspace show -g "rg-demo-monitoring" \
  -w "law-demotrace-dev" --query customerId -o tsv)

WKEY=$(az monitor log-analytics workspace get-shared-keys \
  -g "rg-demo-monitoring" -w "law-demotrace-dev" --query primarySharedKey -o tsv)

# Update Function App
az functionapp config appsettings set \
  -g "rg-demo-monitoring" \
  -n "func-demotrace-dev" \
  --settings \
    WORKSPACE_ID="$WID" \
    SHARED_KEY="$WKEY" \
    GITHUB_TOKEN="ghp_YOUR_TOKEN_HERE"
```

### Run load test

```bash
# Install artillery (first time only)
npm install -g artillery

# Get web app URL
WEB_URL=$(az webapp show -g "rg-demo-monitoring" -n "web-demotrace-dev" \
  --query defaultHostName -o tsv)

# Run 5-minute load test
artillery quick --count 10 --duration 5 --rate 2 "https://$WEB_URL"
```

### View Workbook

```bash
# List all workbooks
az resource list -g "rg-demo-monitoring" \
  --resource-type "microsoft.insights/workbooks" -o table

# Go to Azure Portal → Resource Group (rg-demo-monitoring) → Click workbook name
```

---

## Troubleshooting Flowchart

```
"No data in Log Analytics after 30 minutes?"

├─ YES: AMA extension installed on vm-azure-demo?
│  └─ NO → Go to demo/ and run: ./manual-setup-scripts/install-ama.ps1
│  └─ YES → Check if service running: azcmagent show
│           └─ NOT RUNNING → Restart-Service AzureMonitorAgent (from VM)
│
├─ YES: DCR associated with VM?
│  └─ NO → See TROUBLESHOOTING.md "Issue 1: Data Collection Rule not attached"
│  └─ YES → Check DCR syntax: az monitor data-collection rule show
│
├─ YES: GitHub token set in Function App?
│  └─ NO → Update in Portal or: deploy-demo.ps1 will prompt
│  └─ YES → Check Function logs: az monitor log-analytics query -w law-demotrace-dev \
│           --analytics-query 'FunctionAppLogs | where FunctionName == "GitHubMetrics"'
│
└─ Still broken? → See demo/TROUBLESHOOTING.md for all diagnostics
```

---

## Resource Cleanup

```bash
# Delete everything (permanent!)
az group delete -n "rg-demo-monitoring" --yes

# Verify (should return: false)
az group exists -n "rg-demo-monitoring"
```

---

## Important File Locations

```
workout-az-tracing/
├── REQUIREMENTS.md                    ← INDEX (start here)
├── TECHNICAL_ARCHITECTURE.md          ← Reference design
├── IMPLEMENTATION_PLAN.md             ← Phased rollout
├── INGESTION_PIPELINE.md              ← All data flows
├── DATA_CENTER_MONITORING.md          ← Arc + AMA setup
├── SAAS_INTEGRATION.md                ← SaaS patterns
│
└── demo/                              ← ALL DEPLOYMENT FILES
    ├── deploy-demo.ps1                ← RUN THIS FIRST!
    ├── TROUBLESHOOTING.md             ← If anything breaks
    ├── load-test.yml                  ← Generate traffic (artillery)
    ├── demo-infrastructure.bicep      ← IaC
    ├── dcr-azure-vm.json              ← Data collection rules
    ├── dcr-datadc-vm.json
    ├── azure-function-github-metrics.js
    ├── functions/
    │   ├── function.json
    │   └── package.json
    └── workbook-template.json         ← Dashboard
```

---

## Support Reference

- **Stuck?** → See `demo/TROUBLESHOOTING.md` (5 test levels, specific diagnostics)
- **Questions?** → Check the main architecture docs in REQUIREMENTS.md
- **Azure docs** → Links in DEMO_SOLUTION.md and TECHNICAL_ARCHITECTURE.md
