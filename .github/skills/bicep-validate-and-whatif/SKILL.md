---
name: bicep-validate-and-whatif
description: 'Validates Bicep templates and runs what-if previews for az-tracing environments - Brought to you by jharbieh/az-tracing'
---
# Bicep Validate and What-If

## Overview
Use this skill to validate the Bicep deployment in this repository before any platform deployment. It compiles templates, validates parameterized deployments, and optionally runs what-if to preview resource changes.

## Prerequisites
- Azure CLI installed and authenticated (`az login` completed).
- Bicep CLI available through Azure CLI.
- Deployment scope resource group exists.
- Required permissions at subscription and target resource group scope.

## Quick Start
1. Select target environment (`dev` or `prod`) and confirm the matching parameter file exists under `bicep/`.
2. Run the platform-specific script:
   - Bash: `scripts/run.sh --subscription <subscription-id> --resource-group <rg-name> --location <azure-region> --environment dev --mode both`
   - PowerShell: `scripts/run.ps1 -SubscriptionId <subscription-id> -ResourceGroupName <rg-name> -Location <azure-region> -Environment dev -Mode both`
3. Review output and resolve validation or what-if differences before deployment.

## Parameters Reference
| Parameter | Required | Default | Description |
|---|---|---|---|
| `subscription` / `SubscriptionId` | Yes | None | Azure subscription ID used for validation context. |
| `resource-group` / `ResourceGroupName` | Yes | None | Target resource group for deployment validation. |
| `location` / `Location` | Yes | None | Azure region for the deployment command. |
| `environment` / `Environment` | No | `dev` | Chooses `main.<environment>.bicepparam`. Supported values: `dev`, `prod`. |
| `mode` / `Mode` | No | `both` | Validation mode: `validate`, `whatif`, or `both`. |

## Script Reference
- Bash command:

```bash
scripts/run.sh --subscription <subscription-id> --resource-group <rg-name> --location <azure-region> --environment dev --mode both
```

- PowerShell command:

```powershell
scripts/run.ps1 -SubscriptionId <subscription-id> -ResourceGroupName <rg-name> -Location <azure-region> -Environment dev -Mode both
```

## Troubleshooting
- `Parameter file not found`: confirm `bicep/main.dev.bicepparam` or `bicep/main.prod.bicepparam` exists.
- `AuthorizationFailed`: verify current principal has required `Microsoft.Resources/deployments/*` actions and target service permissions.
- `Bicep build failed`: run `az bicep build --file bicep/main.bicep` directly and fix module or type errors first.

## Attribution
> Brought to you by jharbieh/az-tracing
