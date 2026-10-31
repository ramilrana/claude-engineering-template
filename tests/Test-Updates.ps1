#Requires -Version 5.1
<#
.SYNOPSIS
    Tests Update-EngineeringTemplate.ps1: safe replacement, conflicts, deprecation, invalid locks and rollback.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../scripts/lib/Template.Core.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'TestHelpers.psm1') -Force

$gitAvailable = [bool](Get-GitExecutable)
$lockPath = '.claude/engineering-template.lock.json'
$baseVersion = Get-TemplateVersion -TemplateRoot (Get-RepositoryRoot)
$newVersion = Get-NextTestVersion -Version $baseVersion
$laterVersion = Get-NextTestVersion -Version $newVersion
# Lives in a different directory from ChangedA and ChangedB, so the Unix rollback test can block
# ChangedB's directory without also blocking this earlier write.
$newFile = '.claude/engineering-standards/ADDED_IN_TEST.md'

function Invoke-Update {
    param([string]$TemplateRoot, [string]$ProjectRoot, [string[]]$Arguments = @())
    return Invoke-TemplateScript -TemplateRoot $TemplateRoot -Script 'Update-EngineeringTemplate.ps1' -Arguments (@('-ProjectRoot', $ProjectRoot) + $Arguments)
}

function New-UpdateScenario {
    <#
    .SYNOPSIS
        Installs the current template into a new project, then turns the template into version 1.1.0 with:
        two changed managed files (ChangedA, a rule, before ChangedB, an agent, in manifest order), one
        new managed file (first in manifest order), one managed file removed from the manifest and one
        changed scaffold file.
    #>
    param([string[]]$InstallArguments = @(), [scriptblock]$BeforeUpgrade)
    $template = New-TestTemplate -WithGit:$gitAvailable
    $project = New-TestProject -Files @{ 'src/app.txt' = "application code`n" }
    $install = Invoke-TemplateScript -TemplateRoot $template -Script 'Install-EngineeringTemplate.ps1' -Arguments (@('-ProjectRoot', $project) + $InstallArguments)
    Assert-ExitCode 0 $install 'scenario install'

    $managed = @(Get-TestManifestEntries -TemplateRoot $template -Ownership 'managed')
    $scaffold = @(Get-TestManifestEntries -TemplateRoot $template -Ownership 'project' | Where-Object { $_.destination -eq 'docs/engineering/TESTING.md' })[0]
    $scenario = [pscustomobject]@{
        Template       = $template
        Project        = $project
        ChangedA       = $managed[0]
        ChangedB       = @($managed | Where-Object { $_.destination -like '.claude/agents/*' })[0]
        Removed        = $managed[2]
        Untouched      = $managed[3]
        Scaffold       = $scaffold
        OldHashA       = Get-FileSha256 -Path (Get-TestPath -Root $template -RelativePath $managed[0].source)
    }
    if ($BeforeUpgrade) { & $BeforeUpgrade $scenario }

    Set-TestTemplateVersion -TemplateRoot $template -Version $newVersion
    Add-TestFileContent -Root $template -RelativePath $scenario.ChangedA.source -Content "`nChanged in $newVersion (A).`n"
    Add-TestFileContent -Root $template -RelativePath $scenario.ChangedB.source -Content "`nChanged in $newVersion (B).`n"
    Add-TestFileContent -Root $template -RelativePath $scenario.Scaffold.source -Content "`nNew scaffold guidance in $newVersion.`n"
    Add-TestManifestEntry -TemplateRoot $template -Source 'distribution/managed/.claude/engineering-standards/ADDED_IN_TEST.md' -Destination $newFile -Prepend
    Remove-TestManifestEntry -TemplateRoot $template -Destination $scenario.Removed.destination
    if ($gitAvailable) { Save-TestTemplateRevision -TemplateRoot $template }
    return $scenario
}

function Get-CandidatePath {
    param([string]$Destination, [string]$Suffix)
    return '.template-update-candidates/{0}/{1}' -f $newVersion, (ConvertTo-InertRelativePath -Destination $Destination -Suffix $Suffix)
}

function Assert-MatchesTemplate {
    param($Scenario, $Entry)
    $expected = Get-FileSha256 -Path (Get-TestPath -Root $Scenario.Template -RelativePath $Entry.source)
    $actual = Get-FileSha256 -Path (Get-TestPath -Root $Scenario.Project -RelativePath $Entry.destination)
    Assert-Equal $expected $actual "$($Entry.destination) matches the template"
}

Invoke-TestCase 'updates unchanged managed files, adds new files and records the new version' {
    $s = New-UpdateScenario
    $result = Invoke-Update -TemplateRoot $s.Template -ProjectRoot $s.Project
    Assert-ExitCode 0 $result 'update'
    Assert-MatchesTemplate $s $s.ChangedA
    Assert-MatchesTemplate $s $s.ChangedB
    Assert-MatchesTemplate $s $s.Untouched
    Assert-FileExists (Get-TestPath -Root $s.Project -RelativePath $newFile)
    Assert-Equal "application code`n" (Get-TestFileText -Root $s.Project -RelativePath 'src/app.txt') 'application file unchanged'

    $lock = Get-TestLock -ProjectRoot $s.Project
    Assert-Equal $newVersion $lock.installedVersion 'installed version'
    Assert-Equal $newVersion (Get-TestLockEntry -ProjectRoot $s.Project -Destination $s.ChangedA.destination).templateVersion 'templateVersion of A'
}

Invoke-TestCase 'backs up replaced files before updating them' {
    $s = New-UpdateScenario
    Assert-ExitCode 0 (Invoke-Update -TemplateRoot $s.Template -ProjectRoot $s.Project) 'update'
    $backupRoot = Get-TestPath -Root $s.Project -RelativePath '.template-update-backups'
    $backupDirectory = @(Get-ChildItem -LiteralPath $backupRoot -Directory)
    Assert-Equal 1 $backupDirectory.Count 'one backup directory'
    $index = Read-JsonFile -Path (Join-Path $backupDirectory[0].FullName 'backup.json')
    $recordA = @($index.files | Where-Object { $_.destination -eq $s.ChangedA.destination })[0]
    Assert-Equal $s.OldHashA (Get-FileSha256 -Path (Get-TestPath -Root $s.Project -RelativePath $recordA.backup)) 'backup holds the previous content'
}

Invoke-TestCase 'marks files removed from the manifest as deprecated and keeps them' {
    $s = New-UpdateScenario
    $result = Invoke-Update -TemplateRoot $s.Template -ProjectRoot $s.Project
    Assert-ExitCode 0 $result 'update'
    Assert-FileExists (Get-TestPath -Root $s.Project -RelativePath $s.Removed.destination)
    Assert-Equal 'deprecated' (Get-TestLockEntry -ProjectRoot $s.Project -Destination $s.Removed.destination).status 'lock status'
    Assert-True ($result.Output -match 'DEPRECATED') 'deprecation reported'
}

Invoke-TestCase 'preserves project-owned scaffold files and offers the new template for reference' {
    $s = New-UpdateScenario -BeforeUpgrade { param($scenario) Set-TestFile -Root $scenario.Project -RelativePath $scenario.Scaffold.destination -Content "Our testing plan`n" }
    Assert-ExitCode 0 (Invoke-Update -TemplateRoot $s.Template -ProjectRoot $s.Project) 'update'
    Assert-Equal "Our testing plan`n" (Get-TestFileText -Root $s.Project -RelativePath $s.Scaffold.destination) 'scaffold file preserved'
    $reference = Get-TestPath -Root $s.Project -RelativePath (Get-CandidatePath -Destination $s.Scaffold.destination -Suffix '.incoming')
    Assert-Equal (Get-FileSha256 -Path (Get-TestPath -Root $s.Template -RelativePath $s.Scaffold.source)) (Get-FileSha256 -Path $reference) 'reference candidate'
}

Invoke-TestCase 'keeps a locally modified managed file and saves a conflict candidate' {
    $s = New-UpdateScenario -BeforeUpgrade { param($scenario) Add-TestFileContent -Root $scenario.Project -RelativePath $scenario.ChangedA.destination -Content "`nProject customization.`n" }
    $customized = Get-FileSha256 -Path (Get-TestPath -Root $s.Project -RelativePath $s.ChangedA.destination)
    $result = Invoke-Update -TemplateRoot $s.Template -ProjectRoot $s.Project
    Assert-ExitCode 2 $result 'update with a conflict'
    Assert-Equal $customized (Get-FileSha256 -Path (Get-TestPath -Root $s.Project -RelativePath $s.ChangedA.destination)) 'customized file untouched'
    Assert-MatchesTemplate $s $s.ChangedB

    $incoming = Get-TestPath -Root $s.Project -RelativePath (Get-CandidatePath -Destination $s.ChangedA.destination -Suffix '.incoming')
    Assert-Equal (Get-FileSha256 -Path (Get-TestPath -Root $s.Template -RelativePath $s.ChangedA.source)) (Get-FileSha256 -Path $incoming) 'incoming candidate'
    if ($gitAvailable) {
        $base = Get-TestPath -Root $s.Project -RelativePath (Get-CandidatePath -Destination $s.ChangedA.destination -Suffix '.base')
        Assert-Equal $s.OldHashA (Get-FileSha256 -Path $base) 'base candidate is the previously installed version'
    }
    $record = Get-TestLockEntry -ProjectRoot $s.Project -Destination $s.ChangedA.destination
    Assert-Equal 'conflict' $record.status 'lock status'
    Assert-Equal $s.OldHashA $record.sha256 'lock keeps the last installed hash'
}

Invoke-TestCase 'a conflict persists across updates until reconciled, then is recorded' {
    $s = New-UpdateScenario -BeforeUpgrade { param($scenario) Add-TestFileContent -Root $scenario.Project -RelativePath $scenario.ChangedA.destination -Content "`nProject customization.`n" }
    Assert-ExitCode 2 (Invoke-Update -TemplateRoot $s.Template -ProjectRoot $s.Project) 'first update'
    Assert-ExitCode 2 (Invoke-Update -TemplateRoot $s.Template -ProjectRoot $s.Project) 'repeated update'

    $incoming = Get-TestPath -Root $s.Project -RelativePath (Get-CandidatePath -Destination $s.ChangedA.destination -Suffix '.incoming')
    Copy-Item -LiteralPath $incoming -Destination (Get-TestPath -Root $s.Project -RelativePath $s.ChangedA.destination) -Force
    Assert-ExitCode 0 (Invoke-Update -TemplateRoot $s.Template -ProjectRoot $s.Project) 'update after reconciliation'
    $record = Get-TestLockEntry -ProjectRoot $s.Project -Destination $s.ChangedA.destination
    Assert-Equal 'active' $record.status 'reconciled status'
    Assert-Equal (Get-FileSha256 -Path $incoming) $record.sha256 'reconciled hash'
}

Invoke-TestCase 'keeps a customized file quietly when its central version did not change' {
    $s = New-UpdateScenario -BeforeUpgrade { param($scenario) Add-TestFileContent -Root $scenario.Project -RelativePath $scenario.Untouched.destination -Content "`nProject customization.`n" }
    $customized = Get-FileSha256 -Path (Get-TestPath -Root $s.Project -RelativePath $s.Untouched.destination)
    $result = Invoke-Update -TemplateRoot $s.Template -ProjectRoot $s.Project
    Assert-ExitCode 0 $result 'update'
    Assert-Equal $customized (Get-FileSha256 -Path (Get-TestPath -Root $s.Project -RelativePath $s.Untouched.destination)) 'customization kept'
    Assert-FileMissing (Get-TestPath -Root $s.Project -RelativePath (Get-CandidatePath -Destination $s.Untouched.destination -Suffix '.incoming'))
    $record = Get-TestLockEntry -ProjectRoot $s.Project -Destination $s.Untouched.destination
    Assert-Equal 'active' $record.status 'lock status'
    Assert-Equal (Get-FileSha256 -Path (Get-TestPath -Root $s.Template -RelativePath $s.Untouched.source)) $record.sha256 'lock keeps the central hash'
}

Invoke-TestCase 'reinstalls a managed file that was deleted locally' {
    $s = New-UpdateScenario -BeforeUpgrade { param($scenario) Remove-Item -LiteralPath (Get-TestPath -Root $scenario.Project -RelativePath $scenario.Untouched.destination) }
    Assert-ExitCode 0 (Invoke-Update -TemplateRoot $s.Template -ProjectRoot $s.Project) 'update'
    Assert-MatchesTemplate $s $s.Untouched
}

Invoke-TestCase 'keeps a deleted scaffold file deleted' {
    $s = New-UpdateScenario -BeforeUpgrade { param($scenario) Remove-Item -LiteralPath (Get-TestPath -Root $scenario.Project -RelativePath $scenario.Scaffold.destination) }
    Assert-ExitCode 0 (Invoke-Update -TemplateRoot $s.Template -ProjectRoot $s.Project) 'update'
    Assert-FileMissing (Get-TestPath -Root $s.Project -RelativePath $s.Scaffold.destination)
    Assert-Equal 'removed' (Get-TestLockEntry -ProjectRoot $s.Project -Destination $s.Scaffold.destination).status 'lock status'
}

Invoke-TestCase 'respects exclusions and lets -Include re-enable them' {
    $template = New-TestTemplate
    $excluded = @(Get-TestManifestEntries -TemplateRoot $template -Ownership 'managed')[4]
    $project = New-TestProject
    Assert-ExitCode 0 (Invoke-TemplateScript -TemplateRoot $template -Script 'Install-EngineeringTemplate.ps1' -Arguments @('-ProjectRoot', $project, '-Exclude', $excluded.destination)) 'install'
    Assert-ExitCode 0 (Invoke-Update -TemplateRoot $template -ProjectRoot $project) 'update'
    Assert-FileMissing (Get-TestPath -Root $project -RelativePath $excluded.destination)
    Assert-ExitCode 0 (Invoke-Update -TemplateRoot $template -ProjectRoot $project -Arguments @('-Include', $excluded.destination)) 'update -Include'
    Assert-FileExists (Get-TestPath -Root $project -RelativePath $excluded.destination)
    Assert-Equal 0 @((Get-TestLock -ProjectRoot $project).excluded).Count 'no exclusions remain'
}

Invoke-TestCase 'repeated update changes nothing' {
    $s = New-UpdateScenario
    Assert-ExitCode 0 (Invoke-Update -TemplateRoot $s.Template -ProjectRoot $s.Project) 'first update'
    $before = Get-DirectorySnapshot -Root $s.Project
    Assert-ExitCode 0 (Invoke-Update -TemplateRoot $s.Template -ProjectRoot $s.Project) 'second update'
    Assert-SnapshotUnchanged -Before $before -After (Get-DirectorySnapshot -Root $s.Project) -Context 'repeated update'
}

Invoke-TestCase '-WhatIf previews an update without writing' {
    $s = New-UpdateScenario
    $before = Get-DirectorySnapshot -Root $s.Project
    $result = Invoke-Update -TemplateRoot $s.Template -ProjectRoot $s.Project -Arguments @('-WhatIf')
    Assert-ExitCode 0 $result 'update -WhatIf'
    Assert-True ($result.Output -match 'What if') 'WhatIf message shown'
    Assert-SnapshotUnchanged -Before $before -After (Get-DirectorySnapshot -Root $s.Project) -Context 'update -WhatIf'
}

Invoke-TestCase 'stops on a corrupt lock file without writing' {
    $s = New-UpdateScenario
    Set-TestFile -Root $s.Project -RelativePath $lockPath -Content '{ "lockSchemaVersion": 1, '
    $before = Get-DirectorySnapshot -Root $s.Project
    $result = Invoke-Update -TemplateRoot $s.Template -ProjectRoot $s.Project
    Assert-ExitCode 1 $result 'update with corrupt lock'
    Assert-True ($result.Output -match 'not valid JSON') 'error explains the problem'
    Assert-SnapshotUnchanged -Before $before -After (Get-DirectorySnapshot -Root $s.Project) -Context 'failed update'
}

Invoke-TestCase 'stops when the lock contains a path traversal or an invalid hash' {
    foreach ($corruption in @(
            @{ Field = 'destination'; Value = '../outside.md'; Pattern = 'unsafe destination' },
            @{ Field = 'sha256'; Value = 'not-a-hash'; Pattern = 'not a lowercase SHA-256' }
        )) {
        $s = New-UpdateScenario
        $lock = Get-TestLock -ProjectRoot $s.Project
        $record = @($lock.files | Where-Object { $_.ownership -eq 'managed' })[0]
        $record.($corruption.Field) = $corruption.Value
        Set-TestFile -Root $s.Project -RelativePath $lockPath -Content (ConvertTo-Json -InputObject $lock -Depth 10)
        $before = Get-DirectorySnapshot -Root $s.Project
        $result = Invoke-Update -TemplateRoot $s.Template -ProjectRoot $s.Project
        Assert-ExitCode 1 $result "update with corrupted $($corruption.Field)"
        Assert-True ($result.Output -match $corruption.Pattern) "error mentions $($corruption.Pattern)"
        Assert-SnapshotUnchanged -Before $before -After (Get-DirectorySnapshot -Root $s.Project) -Context 'failed update'
    }
}

Invoke-TestCase 'stops when a file changes ownership between versions' {
    $template = New-TestTemplate
    $example = @(Get-TestManifestEntries -TemplateRoot $template -Ownership 'example')[0]
    $project = New-TestProject
    Assert-ExitCode 0 (Invoke-TemplateScript -TemplateRoot $template -Script 'Install-EngineeringTemplate.ps1' -Arguments @('-ProjectRoot', $project, '-IncludeExamples')) 'install'

    $entries = @(Get-TestManifestEntries -TemplateRoot $template)
    foreach ($entry in $entries) {
        if ($entry.destination -eq $example.destination) { $entry.ownership = 'project'; $entry.install = 'ifMissing' }
    }
    Set-TestManifestEntries -TemplateRoot $template -Entries $entries
    Set-TestTemplateVersion -TemplateRoot $template -Version $newVersion
    $result = Invoke-Update -TemplateRoot $template -ProjectRoot $project
    Assert-ExitCode 1 $result 'update with an ownership change'
    Assert-True ($result.Output -match 'Ownership of') 'ownership change reported'
}

Invoke-TestCase 'refuses a downgrade unless -AllowDowngrade is given' {
    $s = New-UpdateScenario
    Assert-ExitCode 0 (Invoke-Update -TemplateRoot $s.Template -ProjectRoot $s.Project) 'update'
    Set-TestTemplateVersion -TemplateRoot $s.Template -Version $baseVersion
    $result = Invoke-Update -TemplateRoot $s.Template -ProjectRoot $s.Project
    Assert-ExitCode 1 $result 'downgrade'
    Assert-True ($result.Output -match 'older') 'downgrade explained'
    Assert-ExitCode 0 (Invoke-Update -TemplateRoot $s.Template -ProjectRoot $s.Project -Arguments @('-AllowDowngrade')) 'explicit downgrade'
    Assert-Equal $baseVersion (Get-TestLock -ProjectRoot $s.Project).installedVersion 'downgraded version recorded'
}

Invoke-TestCase 'requires an existing installation' {
    $result = Invoke-Update -TemplateRoot (New-TestTemplate) -ProjectRoot (New-TestProject)
    Assert-ExitCode 1 $result 'update without a lock'
    Assert-True ($result.Output -match 'Install-EngineeringTemplate') 'points to the installer'
}

Invoke-TestCase 'deprecating an excluded file keeps the lock valid for later runs' {
    $template = New-TestTemplate
    $excluded = @(Get-TestManifestEntries -TemplateRoot $template -Ownership 'managed')[4]
    $project = New-TestProject
    Assert-ExitCode 0 (Invoke-TemplateScript -TemplateRoot $template -Script 'Install-EngineeringTemplate.ps1' -Arguments @('-ProjectRoot', $project, '-Exclude', $excluded.destination)) 'install'
    Remove-TestManifestEntry -TemplateRoot $template -Destination $excluded.destination
    Set-TestTemplateVersion -TemplateRoot $template -Version $newVersion
    Assert-ExitCode 0 (Invoke-Update -TemplateRoot $template -ProjectRoot $project) 'update that deprecates the excluded file'
    Assert-ExitCode 0 (Invoke-Update -TemplateRoot $template -ProjectRoot $project) 'next update reads the lock'
    Assert-Equal 'deprecated' (Get-TestLockEntry -ProjectRoot $project -Destination $excluded.destination).status 'lock status'
}

Invoke-TestCase 'a deprecated file that returns in a later release is updated when unchanged' {
    $s = New-UpdateScenario
    Assert-ExitCode 0 (Invoke-Update -TemplateRoot $s.Template -ProjectRoot $s.Project) 'update that deprecates'
    Add-TestManifestEntry -TemplateRoot $s.Template -Source $s.Removed.source -Destination $s.Removed.destination -Content "Returned in $laterVersion`n"
    Set-TestTemplateVersion -TemplateRoot $s.Template -Version $laterVersion
    Assert-ExitCode 0 (Invoke-Update -TemplateRoot $s.Template -ProjectRoot $s.Project) 'update that brings the file back'
    Assert-Equal "Returned in $laterVersion`n" (Get-TestFileText -Root $s.Project -RelativePath $s.Removed.destination) 'file updated'
    Assert-Equal 'active' (Get-TestLockEntry -ProjectRoot $s.Project -Destination $s.Removed.destination).status 'lock status'
}

Invoke-TestCase 'a stale conflict candidate is renamed aside, never deleted' {
    $s = New-UpdateScenario -BeforeUpgrade { param($scenario) Add-TestFileContent -Root $scenario.Project -RelativePath $scenario.ChangedA.destination -Content "`nProject customization.`n" }
    Assert-ExitCode 2 (Invoke-Update -TemplateRoot $s.Template -ProjectRoot $s.Project) 'first update'
    $candidate = Get-CandidatePath -Destination $s.ChangedA.destination -Suffix '.incoming'
    Add-TestFileContent -Root $s.Project -RelativePath $candidate -Content "`nReviewer notes.`n"
    Add-TestFileContent -Root $s.Template -RelativePath $s.ChangedA.source -Content "`nSecond change in $newVersion.`n"
    Assert-ExitCode 2 (Invoke-Update -TemplateRoot $s.Template -ProjectRoot $s.Project) 'second update'
    $candidateDirectory = Split-Path -Parent (Get-TestPath -Root $s.Project -RelativePath $candidate)
    $superseded = @(Get-ChildItem -LiteralPath $candidateDirectory -Filter '*.incoming.superseded-*')
    Assert-Equal 1 $superseded.Count 'superseded candidate kept'
    Assert-True ([IO.File]::ReadAllText($superseded[0].FullName) -match 'Reviewer notes') 'annotations preserved'
}

Invoke-TestCase 'rolls back every change and keeps the lock when a write fails' {
    $s = New-UpdateScenario
    $before = Get-DirectorySnapshot -Root $s.Project
    $blocked = Block-FileReplacement -Path (Get-TestPath -Root $s.Project -RelativePath $s.ChangedB.destination)
    try { $result = Invoke-Update -TemplateRoot $s.Template -ProjectRoot $s.Project }
    finally { & $blocked.Release }

    Assert-ExitCode 1 $result 'update with a failing write'
    Assert-True ($result.Output -match 'rolled back') 'rollback reported'
    $after = Get-DirectorySnapshot -Root $s.Project
    $difference = Compare-DirectorySnapshot -Before $before -After $after
    Assert-Equal 0 @($difference.Changed).Count "changed files after rollback: $($difference.Changed -join ', ')"
    Assert-Equal 0 @($difference.Removed).Count "removed files after rollback: $($difference.Removed -join ', ')"
    foreach ($path in $difference.Added) {
        Assert-True ($path -like '.template-update-backups/*') "only backups may remain after rollback, found '$path'"
    }
    Assert-FileMissing (Get-TestPath -Root $s.Project -RelativePath $newFile)
}

exit (Complete-TestRun)
