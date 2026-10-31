#Requires -Version 5.1
<#
.SYNOPSIS
    Validates VERSION, CHANGELOG.md, TEMPLATE_MANIFEST.json and the path-safety rules.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../scripts/lib/Template.Core.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'TestHelpers.psm1') -Force

$repositoryRoot = Get-RepositoryRoot

function Assert-ManifestRejected {
    # Applies Mutate to a fresh copy of the manifest and asserts validation fails with Pattern.
    param([scriptblock]$Mutate, [string]$Pattern)
    $template = New-TestTemplate
    $manifest = Get-TestManifest -TemplateRoot $template
    & $Mutate $manifest $template
    Save-TestManifest -TemplateRoot $template -Manifest $manifest
    Assert-Throws -Body { Read-TemplateManifest -TemplateRoot $template } -ExpectedMessagePattern $Pattern
}

Invoke-TestCase 'VERSION is a MAJOR.MINOR.PATCH semantic version' {
    Assert-True ((Get-TemplateVersion -TemplateRoot $repositoryRoot) -match '^\d+\.\d+\.\d+$') 'VERSION format'
}

Invoke-TestCase 'CHANGELOG.md has a dated section for VERSION' {
    $version = Get-TemplateVersion -TemplateRoot $repositoryRoot
    $changelog = [IO.File]::ReadAllText((Join-Path $repositoryRoot 'CHANGELOG.md'))
    Assert-True ($changelog -match ('(?m)^## \[' + [regex]::Escape($version) + '\] - \d{4}-\d{2}-\d{2}\s*$')) "CHANGELOG section for $version"
}

Invoke-TestCase 'repository manifest passes validation' {
    $manifest = Read-TemplateManifest -TemplateRoot $repositoryRoot
    Assert-True ($manifest.Entries.Count -gt 0) 'manifest has entries'
}

Invoke-TestCase 'every file under distribution/ is listed in the manifest' {
    $listed = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    foreach ($entry in (Read-TemplateManifest -TemplateRoot $repositoryRoot).Entries) { [void]$listed.Add($entry.Source) }
    $distributionRoot = Join-Path $repositoryRoot 'distribution'
    $unlisted = foreach ($file in Get-ChildItem -LiteralPath $distributionRoot -Recurse -File -Force) {
        $relative = 'distribution/' + $file.FullName.Substring($distributionRoot.Length + 1).Replace('\', '/')
        if (-not $listed.Contains($relative)) { $relative }
    }
    Assert-Equal 0 @($unlisted).Count "files missing from the manifest: $(@($unlisted) -join ', ')"
}

Invoke-TestCase 'manifest distributes every required agent, skill and scaffold document' {
    $destinations = @((Read-TemplateManifest -TemplateRoot $repositoryRoot).Entries | ForEach-Object { $_.Destination })
    $agents = 'eng-project-architect', 'eng-architecture-reviewer', 'eng-security-reviewer', 'eng-frontend-engineer', 'eng-backend-engineer',
    'eng-database-engineer', 'eng-qa-engineer', 'eng-release-reviewer', 'eng-frontend-design-reviewer'
    $skills = 'eng-project-bootstrap', 'eng-project-resume', 'eng-security-audit', 'eng-responsive-audit', 'eng-frontend-design', 'eng-prepare-pr', 'eng-template-update'
    $documents = 'PROJECT_REQUIREMENTS', 'TECH_STACK', 'ARCHITECTURE', 'SECURITY', 'IMPLEMENTATION_PLAN', 'DESIGN_SYSTEM', 'TESTING', 'DEPLOYMENT', 'CURRENT_STATE'
    $required = @($agents | ForEach-Object { ".claude/agents/$_.md" }) + @($skills | ForEach-Object { ".claude/skills/$_/SKILL.md" }) +
    @($documents | ForEach-Object { "docs/engineering/$_.md" }) + @('CLAUDE.md')
    foreach ($path in $required) { Assert-True ($destinations -contains $path) "manifest includes $path" }
}

Invoke-TestCase 'unsafe relative paths are rejected' {
    $unsafe = @('', ' ', '/etc/passwd', 'C:/Windows/x.md', '..\x', '../x', 'a/../b', 'a/./b', 'a//b', 'a\b', 'a/b.', 'a/ b', "a/b`tc", 'a/b:c', 'a/*', 'a/b/')
    foreach ($path in $unsafe) { Assert-True ([bool](Get-RelativePathError -RelativePath $path)) "'$path' should be rejected" }
}

Invoke-TestCase 'ordinary relative paths are accepted' {
    foreach ($path in @('CLAUDE.md', '.claude/rules/eng-security.md', 'docs/engineering/TECH_STACK.md', '.claude/skills/eng-x/SKILL.md')) {
        Assert-Equal $null (Get-RelativePathError -RelativePath $path) "'$path' should be accepted"
    }
}

Invoke-TestCase 'Resolve-ContainedPath refuses to leave its root' {
    $root = New-TestDirectory
    Assert-Throws -Body { Resolve-ContainedPath -Root $root -RelativePath '../outside.md' } -ExpectedMessagePattern 'Unsafe path'
}

Invoke-TestCase 'rejects a destination that traverses outside the project' {
    Assert-ManifestRejected -Mutate { param($m) $m.files[0].destination = '../outside.md' } -Pattern "contains a '\.\.' segment"
}

Invoke-TestCase 'rejects an absolute destination' {
    Assert-ManifestRejected -Mutate { param($m) $m.files[0].destination = 'C:/Windows/evil.md' } -Pattern 'unsafe'
}

Invoke-TestCase 'rejects a managed file aimed at project settings' {
    Assert-ManifestRejected -Mutate { param($m) $m.files[0].destination = '.claude/settings.json' } -Pattern 'not an allowed location for managed files'
}

Invoke-TestCase 'rejects a project file aimed at application source' {
    Assert-ManifestRejected -Mutate {
        param($m)
        $entry = @($m.files | Where-Object { $_.ownership -eq 'project' })[0]
        $entry.destination = 'src/index.js'
    } -Pattern 'not an allowed location for project files'
}

Invoke-TestCase 'rejects project files placed where Claude Code would load them as instructions' {
    foreach ($destination in @('docs/engineering/CLAUDE.md', 'docs/engineering/.claude/skills/x/SKILL.md')) {
        Assert-ManifestRejected -Mutate {
            param($m)
            $entry = @($m.files | Where-Object { $_.ownership -eq 'project' -and $_.destination -ne 'CLAUDE.md' })[0]
            $entry.destination = $destination
        } -Pattern 'would be loaded by Claude Code'
    }
}

Invoke-TestCase 'rejects an install behavior that does not match ownership' {
    Assert-ManifestRejected -Mutate { param($m) $m.files[0].install = 'ifMissing' } -Pattern "install must be 'always'"
}

Invoke-TestCase 'rejects an unknown ownership' {
    Assert-ManifestRejected -Mutate { param($m) $m.files[0].ownership = 'shared' } -Pattern 'ownership must be one of'
}

Invoke-TestCase 'rejects duplicate destinations, ignoring case' {
    Assert-ManifestRejected -Mutate {
        param($m)
        $copy = $m.files[1] | Select-Object *
        $copy.destination = $m.files[0].destination.ToUpperInvariant()
        $m.files = @($m.files) + $copy
    } -Pattern 'duplicate destination'
}

Invoke-TestCase 'rejects a missing source file' {
    Assert-ManifestRejected -Mutate { param($m) $m.files[0].source = 'distribution/managed/.claude/rules/does-not-exist.md' } -Pattern 'does not exist'
}

Invoke-TestCase 'rejects a source outside distribution/' {
    Assert-ManifestRejected -Mutate { param($m) $m.files[0].source = 'scripts/Install-EngineeringTemplate.ps1' } -Pattern 'must be inside distribution/'
}

Invoke-TestCase 'rejects unknown entry properties' {
    Assert-ManifestRejected -Mutate { param($m) $m.files[0] | Add-Member -NotePropertyName 'overwrite' -NotePropertyValue $true } -Pattern "unknown property 'overwrite'"
}

Invoke-TestCase 'rejects an unsupported schema version and template id' {
    Assert-ManifestRejected -Mutate { param($m) $m.manifestSchemaVersion = 2 } -Pattern 'manifestSchemaVersion must be 1'
    Assert-ManifestRejected -Mutate { param($m) $m.templateId = 'something-else' } -Pattern 'templateId must be'
}

Invoke-TestCase 'rejects a manifest with no files' {
    Assert-ManifestRejected -Mutate { param($m) $m.files = @() } -Pattern 'at least one entry'
}

Invoke-TestCase 'rejects malformed JSON' {
    $template = New-TestTemplate
    [IO.File]::WriteAllText((Join-Path $template 'TEMPLATE_MANIFEST.json'), '{ "files": [ ')
    Assert-Throws -Body { Read-TemplateManifest -TemplateRoot $template } -ExpectedMessagePattern 'not valid JSON'
}

Invoke-TestCase 'rejects an invalid VERSION' {
    $template = New-TestTemplate
    Set-TestTemplateVersion -TemplateRoot $template -Version '1.0'
    Assert-Throws -Body { Get-TemplateVersion -TemplateRoot $template } -ExpectedMessagePattern 'not a MAJOR.MINOR.PATCH'
}

exit (Complete-TestRun)
