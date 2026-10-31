#Requires -Version 5.1
<#
.SYNOPSIS
    Runs the template's validation and test suites.

.DESCRIPTION
    Each tests/Test-*.ps1 file runs in its own PowerShell process using the same edition as
    this script, so running this script under Windows PowerShell 5.1 and under PowerShell 7
    validates both. Tests only touch isolated temporary directories.

    Exit code 0 when every suite passes, 1 otherwise.

.PARAMETER Name
    Run only the named suites, e.g. -Name Manifest,Updates.

.EXAMPLE
    .\scripts\Test-EngineeringTemplate.ps1

.EXAMPLE
    pwsh -NoProfile -File .\scripts\Test-EngineeringTemplate.ps1 -Name Installation
#>
[CmdletBinding()]
param([string[]]$Name = @())
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$requestedNames = @($Name | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$suites = @(Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'tests') -Filter 'Test-*.ps1' | Sort-Object -Property Name)
if ($requestedNames.Count -gt 0) {
    $suites = @($suites | Where-Object { $requestedNames -contains ($_.BaseName -replace '^Test-', '') })
    if ($suites.Count -ne $requestedNames.Count) { throw "Unknown suite name in: $($requestedNames -join ', ')" }
}

$powerShell = (Get-Process -Id $PID).Path
Write-Host ("PowerShell {0} ({1}) on {2}" -f $PSVersionTable.PSVersion, $PSVersionTable.PSEdition, [Environment]::OSVersion.VersionString)

$failedSuites = New-Object System.Collections.Generic.List[string]
foreach ($suite in $suites) {
    Write-Host ''
    Write-Host "=== $($suite.BaseName) ===" -ForegroundColor Cyan
    & $powerShell -NoProfile -ExecutionPolicy Bypass -File $suite.FullName
    if ($LASTEXITCODE -ne 0) { $failedSuites.Add($suite.BaseName) }
}

Write-Host ''
if ($failedSuites.Count -gt 0) {
    Write-Host ("FAILED: {0} of {1} suite(s): {2}" -f $failedSuites.Count, $suites.Count, ($failedSuites -join ', ')) -ForegroundColor Red
    exit 1
}
Write-Host ("PASSED: all {0} suite(s)" -f $suites.Count) -ForegroundColor Green
exit 0
