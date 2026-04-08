param(
    [Parameter(Mandatory = $true)]
    [string]$PrincipalId,

    [Parameter(Mandatory = $true)]
    [string]$Scope,

    [Parameter(Mandatory = $true)]
    [string]$ExpectedRoles
)

$ErrorActionPreference = 'Stop'

$expected = $ExpectedRoles.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
if ($expected.Count -eq 0) {
    throw 'ExpectedRoles must contain at least one role name.'
}

$assigned = az role assignment list --assignee $PrincipalId --scope $Scope --query "[].roleDefinitionName" -o tsv
$assignedRoles = @()
if ($assigned) {
    $assignedRoles = $assigned -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
}

Write-Host 'Assigned roles at scope:'
if ($assignedRoles.Count -eq 0) {
    Write-Host '  (none)'
} else {
    $assignedRoles | Sort-Object -Unique | ForEach-Object { Write-Host "  $_" }
}

$missing = @()
foreach ($role in $expected) {
    if (-not ($assignedRoles -contains $role)) {
        $missing += $role
    }
}

if ($missing.Count -gt 0) {
    Write-Host 'Missing required roles:'
    $missing | ForEach-Object { Write-Host "  $_" }
    exit 2
}

Write-Host 'All expected roles are assigned at the target scope.'
