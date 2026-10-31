#Requires -Version 5.1
<#
.SYNOPSIS
    Validates distributed agents, skills, rules, standards and examples against the Claude Code
    formats this template targets (see docs/AGENT_AND_MODEL_ROUTING.md), plus repository hygiene.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../scripts/lib/Template.Core.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'TestHelpers.psm1') -Force

$repositoryRoot = Get-RepositoryRoot
$managedRoot = Join-Path $repositoryRoot 'distribution/managed/.claude'
$manifestEntries = @((Read-TemplateManifest -TemplateRoot $repositoryRoot).Entries)

$validModels = @('opus', 'sonnet', 'haiku', 'fable', 'inherit')
$validEfforts = @('low', 'medium', 'high', 'xhigh', 'max')
$knownTools = @('Read', 'Grep', 'Glob', 'Edit', 'Write', 'Bash', 'PowerShell', 'WebFetch', 'WebSearch', 'NotebookEdit')
$writeCapableTools = @('Edit', 'Write', 'NotebookEdit', 'Bash', 'PowerShell')
$validBooleans = @('true', 'false')

$expectedAgents = [ordered]@{
    'eng-project-architect'        = @{ Model = 'opus'; ReadOnly = $true }
    'eng-architecture-reviewer'    = @{ Model = 'opus'; ReadOnly = $true }
    'eng-security-reviewer'        = @{ Model = 'opus'; ReadOnly = $true }
    'eng-release-reviewer'         = @{ Model = 'opus'; ReadOnly = $true }
    'eng-frontend-design-reviewer' = @{ Model = 'opus'; ReadOnly = $true }
    'eng-frontend-engineer'        = @{ Model = 'sonnet'; ReadOnly = $false }
    'eng-backend-engineer'         = @{ Model = 'sonnet'; ReadOnly = $false }
    'eng-database-engineer'        = @{ Model = 'sonnet'; ReadOnly = $false }
    'eng-qa-engineer'              = @{ Model = 'sonnet'; ReadOnly = $false }
}
$manualOnlySkills = @('eng-project-bootstrap', 'eng-prepare-pr', 'eng-template-update')

function Get-ListValue {
    # Frontmatter lists may be written as a YAML list or a comma-separated string.
    param($Value)
    return @(@($Value) | ForEach-Object { "$_" -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

function Assert-ValidAgent {
    param([IO.FileInfo]$File, [switch]$Distributed)
    $parsed = Read-Frontmatter -Path $File.FullName
    $name = $File.BaseName
    Assert-True $parsed.HasFrontmatter "$name has frontmatter"
    Assert-Equal 0 @($parsed.Errors).Count "$name frontmatter errors: $(@($parsed.Errors) -join '; ')"
    $values = $parsed.Values
    Assert-Equal $name $values['name'] "$name name matches file name"
    Assert-True ($name -match '^[a-z0-9]+(-[a-z0-9]+)*$') "$name uses lowercase-hyphen naming"
    if ($Distributed) { Assert-True ($name.StartsWith('eng-')) "$name uses the reserved eng- prefix" }
    Assert-True (([string]$values['description']).Length -ge 40) "$name has a meaningful description"
    Assert-True ($validModels -contains $values['model']) "$name model '$($values['model'])' is a supported alias"
    if ($values.Contains('effort')) { Assert-True ($validEfforts -contains $values['effort']) "$name effort is valid" }
    Assert-True ($values.Contains('tools')) "$name declares tools explicitly instead of inheriting all tools"
    foreach ($tool in (Get-ListValue $values['tools'])) { Assert-True ($knownTools -contains $tool) "$name tool '$tool' is known" }
    Assert-True ($values.Contains('permissionMode') -eq $false) "$name does not override the project's permission mode"
    Assert-True (@($parsed.Body.Split("`n")).Count -ge 20) "$name has substantive instructions"
}

Invoke-TestCase 'every distributed agent has valid frontmatter and instructions' {
    $agents = @(Get-ChildItem -LiteralPath (Join-Path $managedRoot 'agents') -Filter '*.md')
    Assert-Equal $expectedAgents.Count $agents.Count 'number of distributed agents'
    foreach ($agent in $agents) { Assert-ValidAgent -File $agent -Distributed }
}

Invoke-TestCase 'agents use the planned model routing and reviewers are technically read-only' {
    foreach ($name in $expectedAgents.Keys) {
        $parsed = Read-Frontmatter -Path (Join-Path $managedRoot "agents/$name.md")
        Assert-Equal $expectedAgents[$name].Model $parsed.Values['model'] "$name model"
        $tools = Get-ListValue $parsed.Values['tools']
        if ($expectedAgents[$name].ReadOnly) {
            foreach ($tool in $tools) { Assert-True ($writeCapableTools -notcontains $tool) "$name must not have write-capable tool '$tool'" }
            Assert-Equal 'high' $parsed.Values['effort'] "$name analysis effort"
        }
        else {
            Assert-True ($tools -contains 'Edit') "$name can edit files"
        }
    }
}

Invoke-TestCase 'every distributed skill has valid frontmatter and stays focused' {
    $skillDirectories = @(Get-ChildItem -LiteralPath (Join-Path $managedRoot 'skills') -Directory)
    Assert-Equal 7 $skillDirectories.Count 'number of distributed skills'
    foreach ($directory in $skillDirectories) {
        $skillFile = Join-Path $directory.FullName 'SKILL.md'
        Assert-FileExists $skillFile
        $parsed = Read-Frontmatter -Path $skillFile
        $name = $directory.Name
        Assert-Equal 0 @($parsed.Errors).Count "$name frontmatter errors: $(@($parsed.Errors) -join '; ')"
        Assert-Equal $name $parsed.Values['name'] "$name name matches directory"
        Assert-True ($name.StartsWith('eng-')) "$name uses the reserved eng- prefix"
        $listingText = [string]$parsed.Values['description'] + [string]$parsed.Values['when_to_use']
        Assert-True ($listingText.Length -ge 40 -and $listingText.Length -le 1536) "$name description length $($listingText.Length) within 40-1536"
        Assert-True (@($parsed.Body.Split("`n")).Count -lt 500) "$name body under 500 lines"
        foreach ($flag in @('disable-model-invocation', 'user-invocable')) {
            if ($parsed.Values.Contains($flag)) { Assert-True ($validBooleans -contains $parsed.Values[$flag]) "$name $flag is a boolean" }
        }
        $manualOnly = $parsed.Values.Contains('disable-model-invocation') -and $parsed.Values['disable-model-invocation'] -eq 'true'
        Assert-Equal ($manualOnlySkills -contains $name) $manualOnly "$name manual-only invocation"
    }
}

Invoke-TestCase 'rules are focused, use only supported frontmatter and keep always-loaded context small' {
    $alwaysLoadedLines = 0
    foreach ($rule in Get-ChildItem -LiteralPath (Join-Path $managedRoot 'rules') -Filter '*.md') {
        Assert-True ($rule.BaseName.StartsWith('eng-')) "$($rule.Name) uses the reserved eng- prefix"
        $parsed = Read-Frontmatter -Path $rule.FullName
        Assert-Equal 0 @($parsed.Errors).Count "$($rule.Name) frontmatter errors: $(@($parsed.Errors) -join '; ')"
        foreach ($key in $parsed.Values.Keys) { Assert-Equal 'paths' $key "$($rule.Name) frontmatter key" }
        $lineCount = @($parsed.Body.Split("`n")).Count
        Assert-True ($lineCount -ge 10 -and $lineCount -le 120) "$($rule.Name) has $lineCount lines (10-120)"
        if (-not $parsed.Values.Contains('paths')) { $alwaysLoadedLines += $lineCount }
    }
    Assert-True ($alwaysLoadedLines -le 500) "always-loaded rules total $alwaysLoadedLines lines (limit 500)"
}

Invoke-TestCase 'referenced standards and project documents are distributed' {
    $destinations = @($manifestEntries | ForEach-Object { $_.Destination })
    $pattern = '(\.claude/engineering-standards/[A-Z_]+\.md|docs/engineering/[A-Z_]+\.md)'
    foreach ($file in Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'distribution') -Recurse -File -Filter '*.md') {
        $text = [IO.File]::ReadAllText($file.FullName)
        foreach ($match in [regex]::Matches($text, $pattern)) {
            Assert-True ($destinations -contains $match.Value) "$($file.Name) references '$($match.Value)', which is not distributed"
        }
    }
}

Invoke-TestCase 'managed content has no unfinished placeholders' {
    foreach ($file in Get-ChildItem -LiteralPath $managedRoot -Recurse -File) {
        $text = [IO.File]::ReadAllText($file.FullName)
        Assert-True ($text -notmatch '\b(TODO|TBD|FIXME|lorem ipsum)\b') "$($file.FullName) contains a placeholder"
    }
}

Invoke-TestCase 'the recommended settings example is safe and valid' {
    $settingsPath = Join-Path $repositoryRoot 'distribution/examples/settings.recommended.json'
    $settings = Read-JsonFile -Path $settingsPath
    Assert-Equal 'https://json.schemastore.org/claude-code-settings.json' $settings.'$schema' 'settings schema'
    $permissions = $settings.permissions
    Assert-True ($null -eq $permissions.PSObject.Properties['defaultMode'] -or @('default', 'acceptEdits', 'plan') -contains $permissions.defaultMode) 'no permissive default mode'
    foreach ($rule in @($permissions.allow)) {
        Assert-True (@('Bash', 'Bash(*)', 'PowerShell', 'PowerShell(*)', 'Edit', 'Write') -notcontains $rule) "allow rule '$rule' is unrestricted"
    }
    Assert-True (@($permissions.deny) -contains 'Read(./.env)') 'denies reading .env'
    Assert-True (@($permissions.deny | Where-Object { $_ -like 'Bash(git push --force*' }).Count -gt 0) 'denies force push'
    $text = [IO.File]::ReadAllText($settingsPath)
    Assert-True ($text -notmatch 'bypassPermissions|dangerously') 'no bypass settings'
}

Invoke-TestCase 'the example guard hook blocks destructive commands and allows ordinary ones' {
    $guard = Join-Path $repositoryRoot 'distribution/examples/hooks/guard-destructive-commands.ps1'
    $powerShell = (Get-Process -Id $PID).Path
    $cases = [ordered]@{
        'git push --force origin main'       = 2
        'git push origin +main'              = 2
        'git reset --hard HEAD~1'            = 2
        'git clean -fd'                      = 2
        'rm -rf build'                       = 2
        'Remove-Item -Recurse -Force .\dist' = 2
        'psql -c "DROP TABLE users"'         = 2
        'git commit --no-verify -m x'        = 2
        'git branch -D old-feature'          = 2
        'git branch -d merged-feature'       = 0
        'git status'                         = 0
        'git push origin feature/x'          = 0
        'npm test'                           = 0
    }
    $inputFile = Join-Path (New-TestDirectory) 'hook-input.json'
    foreach ($command in $cases.Keys) {
        $hookInput = ConvertTo-Json -InputObject @{ hook_event_name = 'PreToolUse'; tool_name = 'Bash'; tool_input = @{ command = $command } } -Depth 5
        [IO.File]::WriteAllText($inputFile, $hookInput)
        $process = Start-Process -FilePath $powerShell -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$guard`"") `
            -RedirectStandardInput $inputFile -RedirectStandardError ($inputFile + '.err') -NoNewWindow -Wait -PassThru
        Assert-Equal $cases[$command] $process.ExitCode "guard exit code for '$command'"
    }
}

Invoke-TestCase 'repository-maintenance agent and skill are valid' {
    Assert-ValidAgent -File (Get-Item -LiteralPath (Join-Path $repositoryRoot '.claude/agents/template-maintainer.md'))
    $parsed = Read-Frontmatter -Path (Join-Path $repositoryRoot '.claude/skills/template-validation/SKILL.md')
    Assert-Equal 0 @($parsed.Errors).Count "template-validation frontmatter errors: $(@($parsed.Errors) -join '; ')"
    Assert-Equal 'template-validation' $parsed.Values['name'] 'skill name'
}

Invoke-TestCase 'PowerShell sources are ASCII so Windows PowerShell 5.1 parses them correctly' {
    $sources = Get-ChildItem -LiteralPath $repositoryRoot -Recurse -File |
        Where-Object { @('.ps1', '.psm1') -contains $_.Extension -and $_.FullName -notmatch '[\\/]\.git[\\/]' }
    Assert-True (@($sources).Count -ge 10) 'PowerShell sources found'
    foreach ($file in $sources) {
        $bytes = [IO.File]::ReadAllBytes($file.FullName)
        Assert-True (-not ($bytes | Where-Object { $_ -gt 127 } | Select-Object -First 1)) "$($file.Name) contains non-ASCII bytes"
    }
}

Invoke-TestCase 'distributed files use LF line endings so hashes match on every platform' {
    foreach ($file in Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'distribution') -Recurse -File) {
        $bytes = [IO.File]::ReadAllBytes($file.FullName)
        Assert-True ([Array]::IndexOf($bytes, [byte]13) -lt 0) "$($file.FullName) contains CR characters"
        Assert-True ($bytes.Length -gt 0 -and $bytes[-1] -eq 10) "$($file.FullName) ends with a newline"
    }
}

exit (Complete-TestRun)
