#Requires -Version 5.1
<#
.SYNOPSIS
    Validates the repository and creates a local, annotated release tag for the version in VERSION.

.DESCRIPTION
    Release gates, in order:
      1. git is available and the working tree is clean;
      2. the current branch is main;
      3. VERSION is a valid semantic version and its tag does not exist yet;
      4. CHANGELOG.md has a dated section for the version;
      5. the full test suite passes.
    Then it prints the release notes and, after confirmation through ShouldProcess, creates the
    tag locally. It never pushes, publishes or creates a remote release; it prints the commands
    for a maintainer to run after approval.

.EXAMPLE
    .\scripts\New-EngineeringTemplateRelease.ps1 -WhatIf

.EXAMPLE
    .\scripts\New-EngineeringTemplateRelease.ps1
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'lib/Template.Core.psm1') -Force

$repositoryRoot = Split-Path -Parent $PSScriptRoot

function Invoke-Git {
    param([string[]]$Arguments)
    $result = Invoke-NativeCommand -FilePath $script:Git -ArgumentList (@('-C', $repositoryRoot) + $Arguments)
    if ($result.ExitCode -ne 0) { throw "git $($Arguments -join ' ') failed: $($result.StandardError.Trim())" }
    return $result.StandardOutput.Trim()
}

function Get-ChangelogSection {
    param([string]$Version)
    $lines = [IO.File]::ReadAllLines((Join-Path $repositoryRoot 'CHANGELOG.md'))
    $headingPattern = '^## \[' + [regex]::Escape($Version) + '\] - \d{4}-\d{2}-\d{2}\s*$'
    $start = -1
    for ($index = 0; $index -lt $lines.Length; $index++) {
        if ($lines[$index] -match $headingPattern) { $start = $index; break }
    }
    if ($start -lt 0) { return $null }
    $end = $lines.Length
    for ($index = $start + 1; $index -lt $lines.Length; $index++) {
        if ($lines[$index] -match '^## \[') { $end = $index; break }
    }
    return ($lines[$start..($end - 1)] -join "`n").Trim()
}

try {
    $script:Git = Get-GitExecutable
    if (-not $script:Git) { throw 'git is required to create a release.' }

    if (Invoke-Git @('status', '--porcelain')) { throw 'The working tree has uncommitted changes. Commit or stash them first.' }
    $branch = Invoke-Git @('rev-parse', '--abbrev-ref', 'HEAD')
    if ($branch -ne 'main') { throw "Releases are created from main; the current branch is '$branch'." }

    $version = Get-TemplateVersion -TemplateRoot $repositoryRoot
    $tag = "v$version"
    if (Invoke-Git @('tag', '--list', $tag)) { throw "Tag $tag already exists. Bump VERSION and CHANGELOG.md in a pull request first." }

    $notes = Get-ChangelogSection -Version $version
    if (-not $notes) { throw "CHANGELOG.md has no '## [$version] - YYYY-MM-DD' section." }

    Write-Host "Running the full test suite for $tag ..."
    $powerShell = (Get-Process -Id $PID).Path
    & $powerShell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Test-EngineeringTemplate.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'Tests failed; no tag was created.' }

    Write-Host ''
    Write-Host "Release notes for ${tag}:" -ForegroundColor Cyan
    Write-Host $notes
    Write-Host ''

    if ($PSCmdlet.ShouldProcess($repositoryRoot, "Create annotated tag $tag at $(Invoke-Git @('rev-parse', '--short', 'HEAD'))")) {
        $notesFile = [IO.Path]::GetTempFileName()
        try {
            [IO.File]::WriteAllText($notesFile, "claude-engineering-template $version`n`n$notes`n", (New-Object Text.UTF8Encoding($false)))
            Invoke-Git @('tag', '--annotate', $tag, '--file', $notesFile) | Out-Null
        }
        finally { Remove-Item -LiteralPath $notesFile -Force }
        Write-Host "Created local tag $tag. Nothing was pushed." -ForegroundColor Green
        Write-Host 'After approval, publish with:'
        Write-Host '  git push origin main'
        Write-Host "  git push origin $tag"
    }
    exit 0
}
catch {
    $Host.UI.WriteErrorLine("ERROR: $($_.Exception.Message)")
    exit 1
}
