#Requires -Version 5.1
<#
.SYNOPSIS
    Installs the Claude Code engineering template into a project.

.DESCRIPTION
    Copies only the files listed in TEMPLATE_MANIFEST.json:
      - managed files (shared rules, agents, skills, standards) are installed;
      - project-owned scaffold files are created only when they do not exist;
      - examples are installed only with -IncludeExamples.
    Project-owned and locally modified files are never overwritten. A different file at a managed
    path is reported as a conflict and the incoming version is saved under
    .template-update-candidates/. Re-running at the same version refreshes only managed files that
    are unchanged since they were installed, after backing them up.
    The result is recorded in .claude/engineering-template.lock.json.

    Exit codes: 0 success, 1 failure (nothing changed), 2 completed with conflicts to review.

.PARAMETER ProjectRoot
    The project directory to install into. It must already exist.

.PARAMETER TemplateRoot
    The template checkout to install from. Defaults to the repository containing this script.
    Check out a release tag there (for example v1.0.0) to install that version.

.PARAMETER IncludeExamples
    Also copy the example settings and customization samples into docs/engineering/template-examples/.

.PARAMETER Exclude
    Managed destinations this project opts out of, e.g. .claude/agents/eng-database-engineer.md.
    Accepts several values or one comma-separated string. Recorded in the lock file.

.EXAMPLE
    .\scripts\Install-EngineeringTemplate.ps1 -ProjectRoot C:\Projects\my-app -WhatIf

.EXAMPLE
    .\scripts\Install-EngineeringTemplate.ps1 -ProjectRoot C:\Projects\my-app
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [string]$TemplateRoot,
    [switch]$IncludeExamples,
    [string[]]$Exclude = @()
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'lib/Template.Core.psm1') -Force

if (-not $TemplateRoot) { $TemplateRoot = Split-Path -Parent $PSScriptRoot }

$exitCode = Invoke-TemplateSyncCommand -Mode Install -ProjectRoot $ProjectRoot -TemplateRoot $TemplateRoot `
    -IncludeExamples:$IncludeExamples -Exclude $Exclude -WhatIf:$WhatIfPreference
exit $exitCode
