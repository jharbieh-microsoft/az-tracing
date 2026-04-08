param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$Location,

    [ValidateSet('dev', 'prod')]
    [string]$Environment = 'dev',

    [ValidateSet('validate', 'whatif', 'both')]
    [string]$Mode = 'both'
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptDir '..\..\..\..')
$bicepDir = Join-Path $repoRoot 'bicep'
$mainTemplate = Join-Path $bicepDir 'main.bicep'
$paramFile = Join-Path $bicepDir ("main.$Environment.bicepparam")

if (-not (Test-Path $mainTemplate)) {
    throw "main.bicep not found at $mainTemplate"
}

if (-not (Test-Path $paramFile)) {
    throw "Parameter file not found at $paramFile"
}

Write-Host "Setting Azure subscription context..."
az account set --subscription $SubscriptionId | Out-Null

Write-Host "Compiling Bicep template..."
az bicep build --file $mainTemplate | Out-Null

if ($Mode -eq 'validate' -or $Mode -eq 'both') {
    Write-Host "Running deployment validation..."
    az deployment group validate `
        --name "az-tracing-validate-$Environment" `
        --resource-group $ResourceGroupName `
        --template-file $mainTemplate `
        --parameters "@$paramFile" `
        --location $Location `
        --output table
}

if ($Mode -eq 'whatif' -or $Mode -eq 'both') {
    Write-Host "Running deployment what-if..."
    az deployment group what-if `
        --name "az-tracing-whatif-$Environment" `
        --resource-group $ResourceGroupName `
        --template-file $mainTemplate `
        --parameters "@$paramFile" `
        --location $Location `
        --output table
}

Write-Host "Bicep validation workflow completed."
