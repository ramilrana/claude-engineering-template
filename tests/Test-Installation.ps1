#Requires -Version 5.1
<#
.SYNOPSIS
    Tests Install-EngineeringTemplate.ps1 against temporary projects.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../scripts/lib/Template.Core.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'TestHelpers.psm1') -Force

$template = New-TestTemplate
$version = Get-TemplateVersion -TemplateRoot $template
$managedEntries = @(Get-TestManifestEntries -TemplateRoot $template -Ownership 'managed')
$projectEntries = @(Get-TestManifestEntries -TemplateRoot $template -Ownership 'project')
$exampleEntries = @(Get-TestManifestEntries -TemplateRoot $template -Ownership 'example')
$lockPath = '.claude/engineering-template.lock.json'

function Install-Template {
    param([string]$ProjectRoot, [string[]]$Arguments = @(), [string]$TemplateRoot = $template)
    return Invoke-TemplateScript -TemplateRoot $TemplateRoot -Script 'Install-EngineeringTemplate.ps1' -Arguments (@('-ProjectRoot', $ProjectRoot) + $Arguments)
}

function Get-SourceHash {
    param($Entry, [string]$TemplateRoot = $template)
    return Get-FileSha256 -Path (Get-TestPath -Root $TemplateRoot -RelativePath $Entry.source)
}

Invoke-TestCase 'installs managed and scaffold files into an empty project' {
    $project = New-TestProject
    Assert-ExitCode 0 (Install-Template -ProjectRoot $project) 'install'

    foreach ($entry in $managedEntries) {
        $target = Get-TestPath -Root $project -RelativePath $entry.destination
        Assert-FileExists $target
        Assert-Equal (Get-SourceHash $entry) (Get-FileSha256 -Path $target) "content of $($entry.destination)"
    }
    foreach ($entry in $projectEntries) { Assert-FileExists (Get-TestPath -Root $project -RelativePath $entry.destination) }
    foreach ($entry in $exampleEntries) { Assert-FileMissing (Get-TestPath -Root $project -RelativePath $entry.destination) }

    $expected = @($managedEntries + $projectEntries | ForEach-Object { $_.destination }) + $lockPath
    $actual = @((Get-DirectorySnapshot -Root $project).Keys)
    Assert-Equal $expected.Count $actual.Count 'number of files written'
    foreach ($path in $actual) { Assert-True ($expected -contains $path) "unexpected file '$path'" }
}

Invoke-TestCase 'records version, ownership and hashes in the lock file' {
    $project = New-TestProject
    Assert-ExitCode 0 (Install-Template -ProjectRoot $project) 'install'
    $lock = Get-TestLock -ProjectRoot $project
    Assert-Equal 1 $lock.lockSchemaVersion 'lock schema'
    Assert-Equal 'claude-engineering-template' $lock.templateId 'template id'
    Assert-Equal $version $lock.installedVersion 'installed version'
    Assert-True ([bool]$lock.installedAt) 'installedAt recorded'
    Assert-True ([bool]$lock.sourceRevision) 'sourceRevision recorded'
    foreach ($entry in $managedEntries) {
        $record = Get-TestLockEntry -ProjectRoot $project -Destination $entry.destination
        Assert-Equal 'managed' $record.ownership "ownership of $($entry.destination)"
        Assert-Equal 'active' $record.status "status of $($entry.destination)"
        Assert-Equal (Get-SourceHash $entry) $record.sha256 "hash of $($entry.destination)"
        Assert-Equal $version $record.templateVersion "templateVersion of $($entry.destination)"
    }
    foreach ($entry in $projectEntries) {
        $record = Get-TestLockEntry -ProjectRoot $project -Destination $entry.destination
        Assert-Equal 'created' $record.status "status of $($entry.destination)"
    }
}

Invoke-TestCase '-WhatIf previews without writing anything' {
    $project = New-TestProject -Files @{ 'README.md' = 'app' }
    $before = Get-DirectorySnapshot -Root $project
    $result = Install-Template -ProjectRoot $project -Arguments @('-WhatIf')
    Assert-ExitCode 0 $result 'install -WhatIf'
    Assert-True ($result.Output -match 'What if') 'WhatIf message shown'
    Assert-SnapshotUnchanged -Before $before -After (Get-DirectorySnapshot -Root $project) -Context 'install -WhatIf'
}

Invoke-TestCase 'installs examples only with -IncludeExamples' {
    Assert-True ($exampleEntries.Count -gt 0) 'manifest has examples'
    $project = New-TestProject
    Assert-ExitCode 0 (Install-Template -ProjectRoot $project -Arguments @('-IncludeExamples')) 'install -IncludeExamples'
    foreach ($entry in $exampleEntries) { Assert-FileExists (Get-TestPath -Root $project -RelativePath $entry.destination) }
    Assert-FileMissing (Get-TestPath -Root $project -RelativePath '.claude/settings.json')
}

Invoke-TestCase 'preserves an existing root CLAUDE.md and project documentation' {
    $project = New-TestProject -Files @{
        'CLAUDE.md'                         = "# My project`nOwn instructions.`n"
        'docs/engineering/CURRENT_STATE.md' = "Phase: build`n"
    }
    $before = Get-DirectorySnapshot -Root $project
    Assert-ExitCode 0 (Install-Template -ProjectRoot $project) 'install'
    $after = Get-DirectorySnapshot -Root $project
    foreach ($path in $before.Keys) { Assert-Equal $before[$path] $after[$path] "$path unchanged" }
    Assert-Equal 'preserved' (Get-TestLockEntry -ProjectRoot $project -Destination 'CLAUDE.md').status 'CLAUDE.md status'
}

Invoke-TestCase 'adopts an identical existing managed file' {
    $entry = $managedEntries[0]
    $project = New-TestProject -Files @{ $entry.destination = (Get-TestFileText -Root $template -RelativePath $entry.source) }
    Assert-ExitCode 0 (Install-Template -ProjectRoot $project) 'install'
    Assert-Equal 'active' (Get-TestLockEntry -ProjectRoot $project -Destination $entry.destination).status 'adopted status'
}

Invoke-TestCase 'reports conflicts for different existing rules, agents and skills without overwriting them' {
    $rule = @($managedEntries | Where-Object { $_.destination -like '.claude/rules/*' })[0]
    $agent = @($managedEntries | Where-Object { $_.destination -like '.claude/agents/*' })[0]
    $skill = @($managedEntries | Where-Object { $_.destination -like '.claude/skills/*' })[0]
    $project = New-TestProject -Files @{
        $rule.destination  = "local rule`n"
        $agent.destination = "local agent`n"
        $skill.destination = "local skill`n"
    }
    $result = Install-Template -ProjectRoot $project
    Assert-ExitCode 2 $result 'install with conflicts'
    Assert-True ($result.Output -match 'CONFLICT') 'conflict reported'

    foreach ($entry in @($rule, $agent, $skill)) {
        $local = Get-TestFileText -Root $project -RelativePath $entry.destination
        Assert-True ($local -like 'local *') "$($entry.destination) left untouched"
        $candidate = '.template-update-candidates/{0}/{1}' -f $version, (ConvertTo-InertRelativePath -Destination $entry.destination -Suffix '.incoming')
        Assert-Equal (Get-SourceHash $entry) (Get-FileSha256 -Path (Get-TestPath -Root $project -RelativePath $candidate)) "candidate for $($entry.destination)"
        $record = Get-TestLockEntry -ProjectRoot $project -Destination $entry.destination
        Assert-Equal 'conflict' $record.status "lock status of $($entry.destination)"
        Assert-Equal $null $record.sha256 "no managed hash for unowned $($entry.destination)"
    }
}

Invoke-TestCase 'never touches existing settings, local settings or MCP configuration' {
    $files = @{
        '.claude/settings.json'       = '{ "permissions": { "allow": [] } }'
        '.claude/settings.local.json' = '{ "permissions": { "allow": ["Bash(npm test)"] } }'
        '.mcp.json'                   = '{ "mcpServers": {} }'
    }
    $project = New-TestProject -Files $files
    $before = Get-DirectorySnapshot -Root $project
    Assert-ExitCode 0 (Install-Template -ProjectRoot $project -Arguments @('-IncludeExamples')) 'install'
    $after = Get-DirectorySnapshot -Root $project
    foreach ($path in $files.Keys) { Assert-Equal $before[$path] $after[$path] "$path unchanged" }
}

Invoke-TestCase 'rejects an invalid manifest without writing' {
    $brokenTemplate = New-TestTemplate
    [IO.File]::WriteAllText((Join-Path $brokenTemplate 'TEMPLATE_MANIFEST.json'), '{ not json')
    $project = New-TestProject -Files @{ 'README.md' = 'app' }
    $before = Get-DirectorySnapshot -Root $project
    $result = Install-Template -ProjectRoot $project -TemplateRoot $brokenTemplate
    Assert-ExitCode 1 $result 'install with invalid manifest'
    Assert-True ($result.Output -match 'not valid JSON') 'error explains the problem'
    Assert-SnapshotUnchanged -Before $before -After (Get-DirectorySnapshot -Root $project) -Context 'failed install'
}

Invoke-TestCase 'rejects a manifest whose source file is missing without writing' {
    $brokenTemplate = New-TestTemplate
    Remove-Item -LiteralPath (Get-TestPath -Root $brokenTemplate -RelativePath $managedEntries[-1].source)
    $project = New-TestProject -Files @{ 'README.md' = 'app' }
    $before = Get-DirectorySnapshot -Root $project
    $result = Install-Template -ProjectRoot $project -TemplateRoot $brokenTemplate
    Assert-ExitCode 1 $result 'install with missing source'
    Assert-True ($result.Output -match 'does not exist') 'error names the missing source'
    Assert-SnapshotUnchanged -Before $before -After (Get-DirectorySnapshot -Root $project) -Context 'failed install'
}

Invoke-TestCase 'repeated installation of the same version changes nothing' {
    $project = New-TestProject
    Assert-ExitCode 0 (Install-Template -ProjectRoot $project) 'first install'
    $before = Get-DirectorySnapshot -Root $project
    $result = Install-Template -ProjectRoot $project
    Assert-ExitCode 0 $result 'second install'
    Assert-True ($result.Output -match 'Nothing changed') 'reports no changes'
    Assert-SnapshotUnchanged -Before $before -After (Get-DirectorySnapshot -Root $project) -Context 'repeated install'
}

Invoke-TestCase 'refuses to install a different version over an existing installation' {
    $project = New-TestProject
    $otherTemplate = New-TestTemplate
    Assert-ExitCode 0 (Install-Template -ProjectRoot $project -TemplateRoot $otherTemplate) 'first install'
    Set-TestTemplateVersion -TemplateRoot $otherTemplate -Version (Get-NextTestVersion -Version $version -Part Major)
    $result = Install-Template -ProjectRoot $project -TemplateRoot $otherTemplate
    Assert-ExitCode 1 $result 'install over a different version'
    Assert-True ($result.Output -match 'Update-EngineeringTemplate') 'points to the updater'
}

Invoke-TestCase 'refuses to install into the template repository itself' {
    $result = Install-Template -ProjectRoot $template
    Assert-ExitCode 1 $result 'install into template'
    Assert-FileMissing (Get-TestPath -Root $template -RelativePath $lockPath)
}

Invoke-TestCase 'fails clearly when the project directory does not exist' {
    $missing = Join-Path (New-TestDirectory) 'missing'
    $result = Install-Template -ProjectRoot $missing
    Assert-ExitCode 1 $result 'install into missing directory'
    Assert-True ($result.Output -match 'does not exist') 'error names the problem'
}

Invoke-TestCase 'records exclusions and skips excluded files' {
    $excluded = @($managedEntries[0].destination, $managedEntries[1].destination)
    $project = New-TestProject
    Assert-ExitCode 0 (Install-Template -ProjectRoot $project -Arguments @('-Exclude', ($excluded -join ','))) 'install with exclusions'
    foreach ($path in $excluded) { Assert-FileMissing (Get-TestPath -Root $project -RelativePath $path) }
    $lock = Get-TestLock -ProjectRoot $project
    foreach ($path in $excluded) {
        Assert-True (@($lock.excluded) -contains $path) "$path recorded as excluded"
        Assert-Equal 'excluded' (Get-TestLockEntry -ProjectRoot $project -Destination $path).status "$path status"
    }
}

Invoke-TestCase 'rejects excluding a file that is not template-managed' {
    $project = New-TestProject
    $result = Install-Template -ProjectRoot $project -Arguments @('-Exclude', 'CLAUDE.md')
    Assert-ExitCode 1 $result 'install excluding a project file'
    Assert-FileMissing (Get-TestPath -Root $project -RelativePath $lockPath)
}

exit (Complete-TestRun)
