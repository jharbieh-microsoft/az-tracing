param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [string]$Title = '',

    [double]$FontSize = 11,

    [double]$LineSpacing = 1.3
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$pythonScript = Join-Path $scriptDir 'generate_pdf.py'

if (-not (Test-Path $pythonScript)) {
    throw "Python generator script not found: $pythonScript"
}

$arguments = @(
    '--input', $InputPath,
    '--output', $OutputPath,
    '--font-size', $FontSize,
    '--line-spacing', $LineSpacing
)

if ($Title -ne '') {
    $arguments += @('--title', $Title)
}

python $pythonScript @arguments
