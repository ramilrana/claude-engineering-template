#Requires -Version 5.1
<#
.SYNOPSIS
    End-to-end acceptance scenario: install the real distribution into a realistic project, install
    again, then update to a newer release with one unchanged and one project-modified managed file.

.DESCRIPTION
    Unlike the other suites, these cases are sequential: each builds on the state left by the
    previous one, in the order a project experiences the template. A failure in an early case
    makes later cases fail too; read the first failure.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../scripts/lib/Template.Core.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'TestHelpers.psm1') -Force

$gitAvailable = [bool](Get-GitExecutable)
$lockPath = '.claude/engineering-template.lock.json'
$nextVersion = Get-NextTestVersion -Version (Get-TemplateVersion -TemplateRoot (Get-RepositoryRoot)) -Part Patch
$changedRule = '.claude/rules/eng-security.md'
$customizedAgent = '.claude/agents/eng-backend-engineer.md'

# The project's own files: code, configuration, instructions and customizations.
$projectFiles = [ordered]@{
    'src/index.ts'                           = "export const answer = 42;`n"
    'package.json'                           = '{ "name": "my-app" }'
    'CLAUDE.md'                              = "# my-app`nOur own instructions.`n"
    'docs/engineering/ARCHITECTURE.md'       = "# Our real architecture`n"
    '.claude/settings.json'                  = '{ "permissions": { "deny": ["Read(./.env)"] } }'
    '.claude/agents/project-reviewer.md'     = "---`nname: project-reviewer`ndescription: Project reviewer used by the acceptance test.`ntools: Read`n---`nReview.`n"
    '.claude/skills/project-deploy/SKILL.md' = "---`nname: project-deploy`ndescription: Project deploy workflow used by the acceptance test.`n---`nDeploy.`n"
    '.claude/rules/project-billing.md'       = "Billing rule.`n"
}

$template = New-TestTemplate -WithGit:$gitAvailable
$project = New-TestProject -Files $projectFiles
$managed = @(Get-TestManifestEntries -TemplateRoot $template -Ownership 'managed')
$scaffold = @(Get-TestManifestEntries -TemplateRoot $template -Ownership 'project')
$ownSnapshot = Get-DirectorySnapshot -Root $project
$state = @{}

function Get-Entry {
    param([string]$Destination)
    return @($managed | Where-Object { $_.destination -eq $Destination })[0]
}

function Assert-ProjectFilesUnchanged {
    param([string]$Context)
    $current = Get-DirectorySnapshot -Root $project
    foreach ($path in $ownSnapshot.Keys) { Assert-Equal $ownSnapshot[$path] $current[$path] "$path unchanged $Context" }
}

Invoke-TestCase 'the manifest lists exactly the managed files on disk' {
    $managedRoot = Join-Path (Get-RepositoryRoot) 'distribution/managed'
    $onDisk = @(Get-ChildItem -LiteralPath $managedRoot -Recurse -File -Force | ForEach-Object {
            'distribution/managed/' + $_.FullName.Substring($managedRoot.Length + 1).Replace('\', '/')
        })
    $listed = @($managed | ForEach-Object { $_.source })
    Assert-Equal $onDisk.Count $listed.Count 'managed files on disk vs manifest entries'
    foreach ($path in $onDisk) { Assert-True ($listed -contains $path) "$path is listed in the manifest" }
    foreach ($entry in $managed) {
        Assert-Equal $entry.source.Substring('distribution/managed/'.Length) $entry.destination "destination mirrors $($entry.source)"
    }
    foreach ($kind in @('rules', 'engineering-standards', 'agents', 'skills')) {
        Assert-True (@($managed | Where-Object { $_.destination -like ".claude/$kind/*" }).Count -gt 0) "managed $kind are distributed"
    }
}

Invoke-TestCase 'installs the release into an existing project' {
    Assert-ExitCode 0 (Invoke-TemplateScript -TemplateRoot $template -Script 'Install-EngineeringTemplate.ps1' -Arguments @('-ProjectRoot', $project)) 'install'
    foreach ($entry in $managed) {
        $installed = Get-TestPath -Root $project -RelativePath $entry.destination
        Assert-FileExists $installed
        Assert-Equal (Get-FileSha256 -Path (Get-TestPath -Root $template -RelativePath $entry.source)) (Get-FileSha256 -Path $installed) "$($entry.destination) installed byte-identical"
    }
    foreach ($entry in $scaffold) { Assert-FileExists (Get-TestPath -Root $project -RelativePath $entry.destination) }
    $lock = Get-TestLock -ProjectRoot $project
    Assert-Equal (Get-TemplateVersion -TemplateRoot $template) $lock.installedVersion 'installed version'
    Assert-Equal ($scaffold.Count - 2) @($lock.files | Where-Object { $_.status -eq 'created' }).Count 'scaffold documents created (CLAUDE.md and ARCHITECTURE.md already existed)'
    Assert-Equal 'preserved' (Get-TestLockEntry -ProjectRoot $project -Destination 'CLAUDE.md').status 'CLAUDE.md recorded as preserved'
}

Invoke-TestCase 'installation leaves every project-owned file byte-identical' {
    Assert-ProjectFilesUnchanged -Context 'after install'
}

Invoke-TestCase 'a second installation changes nothing' {
    $before = Get-DirectorySnapshot -Root $project
    $result = Invoke-TemplateScript -TemplateRoot $template -Script 'Install-EngineeringTemplate.ps1' -Arguments @('-ProjectRoot', $project)
    Assert-ExitCode 0 $result 'second install'
    Assert-True ($result.Output -match 'Nothing changed') 'reports nothing changed'
    Assert-SnapshotUnchanged -Before $before -After (Get-DirectorySnapshot -Root $project) -Context 'second install'
}

Invoke-TestCase "updating to $nextVersion replaces an unchanged managed file after backing it up" {
    # Release the next version: one rule and one agent change centrally.
    $state.OldRuleHash = Get-FileSha256 -Path (Get-TestPath -Root $project -RelativePath $changedRule)
    $state.OldAgentHash = Get-FileSha256 -Path (Get-TestPath -Root $project -RelativePath $customizedAgent)
    Add-TestFileContent -Root $template -RelativePath (Get-Entry $changedRule).source -Content "`n- Clarification released in $nextVersion.`n"
    Add-TestFileContent -Root $template -RelativePath (Get-Entry $customizedAgent).source -Content "`nAddition released in $nextVersion.`n"
    Set-TestTemplateVersion -TemplateRoot $template -Version $nextVersion
    if ($gitAvailable) { Save-TestTemplateRevision -TemplateRoot $template }

    # The project customizes the agent before updating.
    Add-TestFileContent -Root $project -RelativePath $customizedAgent -Content "`nOur project-specific instruction.`n"
    $state.CustomizedAgentHash = Get-FileSha256 -Path (Get-TestPath -Root $project -RelativePath $customizedAgent)
    $state.BeforeUpdate = Get-DirectorySnapshot -Root $project
    $state.Update = Invoke-TemplateScript -TemplateRoot $template -Script 'Update-EngineeringTemplate.ps1' -Arguments @('-ProjectRoot', $project)
    Assert-ExitCode 2 $state.Update 'update with one customized file'

    $newRuleHash = Get-FileSha256 -Path (Get-TestPath -Root $template -RelativePath (Get-Entry $changedRule).source)
    Assert-Equal $newRuleHash (Get-FileSha256 -Path (Get-TestPath -Root $project -RelativePath $changedRule)) 'unchanged rule now has the new content'
    $index = @(Get-ChildItem -LiteralPath (Get-TestPath -Root $project -RelativePath '.template-update-backups') -Recurse -Filter 'backup.json')
    Assert-Equal 1 $index.Count 'one backup index'
    $record = @((Read-JsonFile -Path $index[0].FullName).files | Where-Object { $_.destination -eq $changedRule })[0]
    Assert-Equal $state.OldRuleHash (Get-FileSha256 -Path (Get-TestPath -Root $project -RelativePath $record.backup)) 'backup holds the previous content'
    $lock = Get-TestLock -ProjectRoot $project
    Assert-Equal $nextVersion $lock.installedVersion 'lock records the new version'
    Assert-Equal $newRuleHash (Get-TestLockEntry -ProjectRoot $project -Destination $changedRule).sha256 'lock records the new hash'
}

Invoke-TestCase 'updating keeps a project-modified file and saves conflict candidates' {
    Assert-Equal $state.CustomizedAgentHash (Get-FileSha256 -Path (Get-TestPath -Root $project -RelativePath $customizedAgent)) 'customized agent byte-identical'
    $candidate = '.template-update-candidates/{0}/{1}' -f $nextVersion, (ConvertTo-InertRelativePath -Destination $customizedAgent -Suffix '.incoming')
    $incoming = Get-TestPath -Root $project -RelativePath $candidate
    Assert-Equal (Get-FileSha256 -Path (Get-TestPath -Root $template -RelativePath (Get-Entry $customizedAgent).source)) (Get-FileSha256 -Path $incoming) 'incoming candidate holds the new central version'
    if ($gitAvailable) {
        $base = $candidate -replace '\.incoming$', '.base'
        Assert-Equal $state.OldAgentHash (Get-FileSha256 -Path (Get-TestPath -Root $project -RelativePath $base)) 'base candidate holds the previously installed version'
    }
    $record = Get-TestLockEntry -ProjectRoot $project -Destination $customizedAgent
    Assert-Equal 'conflict' $record.status 'lock marks the conflict'
    Assert-Equal $state.OldAgentHash $record.sha256 'lock keeps the last installed hash'
    foreach ($path in @((Get-DirectorySnapshot -Root $project).Keys | Where-Object { $_ -like '.template-update-*' })) {
        Assert-True ($path -notmatch '(^|/)\.claude/' -and $path -notmatch '\.md$') "'$path' cannot be loaded as instructions"
    }
}

Invoke-TestCase 'the update changed only the unchanged managed file and the lock' {
    Assert-ProjectFilesUnchanged -Context 'after update'
    $after = Get-DirectorySnapshot -Root $project
    $changed = @($state.BeforeUpdate.Keys | Where-Object { $after[$_] -ne $state.BeforeUpdate[$_] } | Sort-Object)
    Assert-Equal (@($changedRule, $lockPath | Sort-Object) -join ', ') ($changed -join ', ') 'modified files'
}

Invoke-TestCase 'a second update changes nothing and still reports the open conflict' {
    $before = Get-DirectorySnapshot -Root $project
    $result = Invoke-TemplateScript -TemplateRoot $template -Script 'Update-EngineeringTemplate.ps1' -Arguments @('-ProjectRoot', $project)
    Assert-ExitCode 2 $result 'second update'
    Assert-SnapshotUnchanged -Before $before -After (Get-DirectorySnapshot -Root $project) -Context 'second update'
}

exit (Complete-TestRun)
