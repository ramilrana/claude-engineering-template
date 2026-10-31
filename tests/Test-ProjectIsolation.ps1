#Requires -Version 5.1
<#
.SYNOPSIS
    Verifies that installs and updates never modify application files or write outside the project,
    and that conflict candidates and backups can never become active Claude Code instructions.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../scripts/lib/Template.Core.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'TestHelpers.psm1') -Force

$applicationFiles = @{
    'src/index.ts'                         = "export const answer = 42;`n"
    'package.json'                         = '{ "name": "sample-app" }'
    '.env'                                 = "DATABASE_URL=postgres://test-only`n"
    'README.md'                            = "# Sample app`n"
    'CLAUDE.md'                            = "# Sample app instructions`n"
    '.claude/settings.json'                = '{ "permissions": { "deny": ["Read(./.env)"] } }'
    '.claude/settings.local.json'          = '{ "permissions": { "allow": [] } }'
    '.claude/agents/project-reviewer.md'   = "---`nname: project-reviewer`ndescription: Project specific`n---`nReview.`n"
    '.claude/skills/project-skill/SKILL.md' = "---`nname: project-skill`ndescription: Project specific`n---`nDo it.`n"
    '.claude/rules/project-rule.md'        = "Project rule.`n"
    'docs/engineering/CURRENT_STATE.md'    = "Phase: build`n"
}

function Invoke-InstallThenUpdate {
    # Installs, upgrades the template to 1.1.0 with the first four managed files and the CLAUDE.md
    # scaffold changed, then updates. With git available the template is tagged, so conflicts get
    # .base candidates.
    param([string]$ProjectRoot, [scriptblock]$BeforeUpgrade)
    $template = New-TestTemplate -WithGit:([bool](Get-GitExecutable))
    $install = Invoke-TemplateScript -TemplateRoot $template -Script 'Install-EngineeringTemplate.ps1' -Arguments @('-ProjectRoot', $ProjectRoot, '-IncludeExamples')
    Assert-True (@(0, 2) -contains $install.ExitCode) "install exit code $($install.ExitCode): $($install.Output)"
    if ($BeforeUpgrade) { & $BeforeUpgrade $template }
    $changed = @(Get-TestManifestEntries -TemplateRoot $template -Ownership 'managed')[0..3]
    $changed += @(Get-TestManifestEntries -TemplateRoot $template -Ownership 'project' | Where-Object { $_.destination -eq 'CLAUDE.md' })
    foreach ($entry in $changed) { Add-TestFileContent -Root $template -RelativePath $entry.source -Content "`nChanged for isolation test.`n" }
    Set-TestTemplateVersion -TemplateRoot $template -Version '1.1.0'
    if (Get-GitExecutable) { Save-TestTemplateRevision -TemplateRoot $template }
    $update = Invoke-TemplateScript -TemplateRoot $template -Script 'Update-EngineeringTemplate.ps1' -Arguments @('-ProjectRoot', $ProjectRoot)
    Assert-True (@(0, 2) -contains $update.ExitCode) "update exit code $($update.ExitCode): $($update.Output)"
    return $template
}

Invoke-TestCase 'install and update never change existing application or project files' {
    $project = New-TestProject -Files $applicationFiles
    $before = Get-DirectorySnapshot -Root $project
    $template = Invoke-InstallThenUpdate -ProjectRoot $project
    $after = Get-DirectorySnapshot -Root $project

    foreach ($path in $before.Keys) { Assert-Equal $before[$path] $after[$path] "$path unchanged" }
    $destinations = @(Get-TestManifestEntries -TemplateRoot $template | ForEach-Object { $_.destination })
    foreach ($path in (Compare-DirectorySnapshot -Before $before -After $after).Added) {
        $allowed = ($destinations -contains $path) -or $path -eq '.claude/engineering-template.lock.json' -or
        $path -like '.template-update-candidates/*' -or $path -like '.template-update-backups/*'
        Assert-True $allowed "unexpected new file '$path'"
    }
}

Invoke-TestCase 'writes nothing outside the project directory' {
    $workspace = New-TestDirectory -Prefix 'cet-workspace'
    Set-TestFile -Root $workspace -RelativePath 'sibling/keep.txt' -Content "sibling`n"
    Set-TestFile -Root $workspace -RelativePath 'sentinel.txt' -Content "sentinel`n"
    $project = Join-Path $workspace 'project'
    [void][IO.Directory]::CreateDirectory($project)
    $before = Get-DirectorySnapshot -Root $workspace

    [void](Invoke-InstallThenUpdate -ProjectRoot $project)
    $after = Get-DirectorySnapshot -Root $workspace
    $outside = { param($snapshot) @($snapshot.Keys | Where-Object { $_ -notlike 'project/*' } | Sort-Object) }
    Assert-Equal ((& $outside $before) -join '|') ((& $outside $after) -join '|') 'files outside the project'
    foreach ($path in (& $outside $before)) { Assert-Equal $before[$path] $after[$path] "$path unchanged" }
}

Invoke-TestCase 'rejects a manifest destination outside the project' {
    $workspace = New-TestDirectory -Prefix 'cet-workspace'
    $project = Join-Path $workspace 'project'
    [void][IO.Directory]::CreateDirectory($project)
    $template = New-TestTemplate
    $manifest = Get-TestManifest -TemplateRoot $template
    $manifest.files[0].destination = '../escaped.md'
    Save-TestManifest -TemplateRoot $template -Manifest $manifest

    $result = Invoke-TemplateScript -TemplateRoot $template -Script 'Install-EngineeringTemplate.ps1' -Arguments @('-ProjectRoot', $project)
    Assert-ExitCode 1 $result 'install with an escaping destination'
    Assert-FileMissing (Join-Path $workspace 'escaped.md')
    Assert-Equal 0 @(Get-ChildItem -LiteralPath $project -Force).Count 'project left empty'
}

Invoke-TestCase 'refuses to write through a junction or symbolic link' {
    $workspace = New-TestDirectory -Prefix 'cet-workspace'
    $outside = Join-Path $workspace 'outside'
    $project = Join-Path $workspace 'project'
    [void][IO.Directory]::CreateDirectory($outside)
    [void][IO.Directory]::CreateDirectory($project)
    # .claude is a real directory, so the lock path is fine and the destination check must catch the link.
    [void][IO.Directory]::CreateDirectory((Join-Path $project '.claude'))
    $link = Join-Path $project '.claude/rules'
    if (Test-IsWindows) { New-Item -ItemType Junction -Path $link -Target $outside | Out-Null }
    else { New-Item -ItemType SymbolicLink -Path $link -Target $outside | Out-Null }
    try {
        $result = Invoke-TemplateScript -TemplateRoot (New-TestTemplate) -Script 'Install-EngineeringTemplate.ps1' -Arguments @('-ProjectRoot', $project)
        Assert-ExitCode 1 $result 'install through a link'
        Assert-True ($result.Output -match 'symbolic link or junction') 'link reported'
        Assert-Equal 0 @(Get-ChildItem -LiteralPath $outside -Force -Recurse).Count 'nothing written through the link'
    }
    finally {
        [IO.Directory]::Delete($link)
    }
}

Invoke-TestCase 'candidates and backups can never be loaded as Claude Code instructions' {
    # Managed files 1-3 are customized after installation (conflicts with .base when git exists);
    # managed file 0 is unchanged, so it is backed up and replaced.
    $project = New-TestProject -Files @{ 'CLAUDE.md' = "Project instructions`n" }
    [void](Invoke-InstallThenUpdate -ProjectRoot $project -BeforeUpgrade {
            param($template)
            foreach ($entry in @(Get-TestManifestEntries -TemplateRoot $template -Ownership 'managed')[1..3]) {
                Add-TestFileContent -Root $project -RelativePath $entry.destination -Content "`nlocal edit`n"
            }
        })

    $inactive = @((Get-DirectorySnapshot -Root $project).Keys | Where-Object { $_ -like '.template-update-*' })
    Assert-True (@($inactive | Where-Object { $_ -like '*.incoming' }).Count -ge 4) 'incoming candidates were produced'
    Assert-True (@($inactive | Where-Object { $_ -like '*.bak' }).Count -ge 1) 'backups were produced'
    Assert-True (@($inactive | Where-Object { $_ -like '*/backup.json' }).Count -eq 1) 'backup index was produced'
    if (Get-GitExecutable) { Assert-True (@($inactive | Where-Object { $_ -like '*.base' }).Count -ge 3) 'base candidates were produced' }
    foreach ($path in $inactive) {
        $segments = $path.Split('/')
        Assert-True (-not ($segments | Where-Object { $_ -eq '.claude' })) "'$path' contains a .claude directory"
        Assert-True ($segments[-1] -notmatch '\.md$') "'$path' could be read as Markdown instructions"
    }
}

Invoke-TestCase 'the lock file contains only relative paths and no machine-specific data' {
    $project = New-TestProject
    [void](Invoke-InstallThenUpdate -ProjectRoot $project)
    $text = Get-TestFileText -Root $project -RelativePath '.claude/engineering-template.lock.json'
    Assert-True ($text.IndexOf([IO.Path]::GetTempPath().TrimEnd('\', '/'), [StringComparison]::OrdinalIgnoreCase) -lt 0) 'no absolute temp paths'
    Assert-True ($text -notmatch '[A-Za-z]:\\\\') 'no Windows absolute paths'
    $userName = [Environment]::UserName
    if ($userName.Length -ge 3) { Assert-True ($text.IndexOf($userName, [StringComparison]::OrdinalIgnoreCase) -lt 0) 'no user name' }
}

exit (Complete-TestRun)
