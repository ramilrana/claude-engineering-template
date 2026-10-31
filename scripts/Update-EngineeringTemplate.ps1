#Requires -Version 5.1
<#
.SYNOPSIS
    Updates a project to the template version in the template checkout, preserving customizations.

.DESCRIPTION
    Uses the hashes recorded in .claude/engineering-template.lock.json to decide, per file:
      - missing managed file            -> installed
      - identical to the incoming file  -> skipped
      - unchanged since last install    -> backed up, then replaced
      - modified locally                -> kept; incoming version saved as a conflict candidate
      - removed from the new manifest   -> marked deprecated; never deleted
      - project-owned scaffold file     -> kept; a changed template is offered for reference
    Invalid or ambiguous lock data stops the update before anything is written. If any write
    fails, completed changes are rolled back and the lock file is left unchanged.

    Exit codes: 0 success, 1 failure (nothing changed), 2 completed with conflicts to review.

.PARAMETER ProjectRoot
    The project directory that already has the template installed.

.PARAMETER TemplateRoot
    The template checkout to update from. Defaults to the repository containing this script.
    Check out the release tag you want (for example v1.1.0) before running the update.

.PARAMETER IncludeExamples
    Also install example files that the project has not received yet.

.PARAMETER Exclude
    Managed destinations to opt out of from now on. Existing files are left in place.

.PARAMETER Include
    Previously excluded managed destinations to manage again.

.PARAMETER AllowDowngrade
    Permit moving to an older template version than the one installed.

.EXAMPLE
    .\scripts\Update-EngineeringTemplate.ps1 -ProjectRoot C:\Projects\my-app -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [string]$TemplateRoot,
    [switch]$IncludeExamples,
    [string[]]$Exclude = @(),
    [string[]]$Include = @(),
    [switch]$AllowDowngrade
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'lib/Template.Core.psm1') -Force

if (-not $TemplateRoot) { $TemplateRoot = Split-Path -Parent $PSScriptRoot }

$exitCode = Invoke-TemplateSyncCommand -Mode Update -ProjectRoot $ProjectRoot -TemplateRoot $TemplateRoot `
    -IncludeExamples:$IncludeExamples -Exclude $Exclude -Include $Include -AllowDowngrade:$AllowDowngrade `
    -WhatIf:$WhatIfPreference
exit $exitCode
