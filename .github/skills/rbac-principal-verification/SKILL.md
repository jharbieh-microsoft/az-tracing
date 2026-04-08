---
name: rbac-principal-verification
description: 'Verifies principal role assignments against expected platform RBAC scopes - Brought to you by jharbieh/az-tracing'
---
# RBAC Principal Verification

## Overview
Use this skill to verify that a deployment principal already has required RBAC assignments before running Bicep deployments. It compares actual role assignments at a target scope with an expected role set and reports missing permissions.

## Prerequisites
- Azure CLI installed and authenticated.
- Access to query role assignments at target scope.
- Principal identifier available (object ID, app ID, or UPN as applicable).

## Quick Start
1. Define the deployment scope and required roles from the platform RBAC matrix.
2. Run the verification script for your shell:
   - Bash: `scripts/verify-principal.sh --principal <principal-id> --scope <scope-id> --roles "Contributor,Monitoring Contributor,Log Analytics Contributor"`
   - PowerShell: `scripts/verify-principal.ps1 -PrincipalId <principal-id> -Scope <scope-id> -ExpectedRoles "Contributor,Monitoring Contributor,Log Analytics Contributor"`
3. Block deployment if any role appears in the missing list.

## Parameters Reference
| Parameter | Required | Default | Description |
|---|---|---|---|
| `principal` / `PrincipalId` | Yes | None | Principal identifier for assignment lookup. |
| `scope` / `Scope` | Yes | None | RBAC scope, usually subscription or resource group ID. |
| `roles` / `ExpectedRoles` | Yes | None | Comma-separated role names required for deployment operations. |

## Script Reference
- Bash command:

```bash
scripts/verify-principal.sh --principal <principal-id> --scope <scope-id> --roles "Contributor,Monitoring Contributor,Log Analytics Contributor"
```

- PowerShell command:

```powershell
scripts/verify-principal.ps1 -PrincipalId <principal-id> -Scope <scope-id> -ExpectedRoles "Contributor,Monitoring Contributor,Log Analytics Contributor"
```

## Troubleshooting
- `Principal not found`: verify the principal exists in the tenant and use object ID for deterministic lookup.
- Empty assignment list: confirm scope is correct and caller can read RBAC assignments.
- Role name mismatch: use exact built-in role names as displayed by `az role definition list --name <role-name>`.

## Attribution
> Brought to you by jharbieh/az-tracing
