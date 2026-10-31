#Requires -Version 5.1
<#
.SYNOPSIS
    Minimal, dependency-free test helpers for the template test suites.

.DESCRIPTION
    Pester is deliberately not used: Windows PowerShell ships Pester 3.4, which is incompatible
    with Pester 5, and the template must not require installing modules. Each suite registers
    cases with Invoke-TestCase and finishes with Complete-TestRun, which returns the exit code.
    Every test works in its own temporary directory and never touches real projects.
#>
Set-StrictMode -Version Latest
Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts/lib/Template.Core.psm1')

$script:Results = New-Object System.Collections.Generic.List[object]
$script:TemporaryDirectories = New-Object System.Collections.Generic.List[string]
$script:RepositoryRoot = Split-Path -Parent $PSScriptRoot

#region Test runner and assertions

function Invoke-TestCase {
    param([Parameter(Mandatory = $true)][string]$Name, [Parameter(Mandatory = $true)][scriptblock]$Body)
    try {
        & $Body
        $script:Results.Add([pscustomobject]@{ Name = $Name; Passed = $true; Message = $null })
        Write-Host "  PASS  $Name" -ForegroundColor Green
    }
    catch {
        $location = $_.InvocationInfo.PositionMessage
        $script:Results.Add([pscustomobject]@{ Name = $Name; Passed = $false; Message = $_.Exception.Message })
        Write-Host "  FAIL  $Name" -ForegroundColor Red
        Write-Host "        $($_.Exception.Message)" -ForegroundColor Red
        if ($location) { Write-Host ("        " + ($location -split "`n")[0]) -ForegroundColor DarkGray }
    }
}

function Complete-TestRun {
    Remove-TestDirectories
    $failed = @($script:Results | Where-Object { -not $_.Passed })
    Write-Host ("  {0} passed, {1} failed" -f ($script:Results.Count - $failed.Count), $failed.Count)
    if ($failed.Count -gt 0) { return 1 }
    return 0
}

function Assert-True {
    param([bool]$Condition, [Parameter(Mandatory = $true)][string]$Message)
    if (-not $Condition) { throw "Assertion failed: $Message" }
}

function Assert-Equal {
    param($Expected, $Actual, [Parameter(Mandatory = $true)][string]$Message)
    if ($Expected -ne $Actual) { throw "Assertion failed: $Message (expected '$Expected', actual '$Actual')" }
}

function Assert-FileExists {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not [IO.File]::Exists($Path)) { throw "Assertion failed: expected file '$Path' to exist" }
}

function Assert-FileMissing {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ([IO.File]::Exists($Path)) { throw "Assertion failed: expected file '$Path' not to exist" }
}

function Assert-Throws {
    param([Parameter(Mandatory = $true)][scriptblock]$Body, [Parameter(Mandatory = $true)][string]$ExpectedMessagePattern)
    try { & $Body }
    catch {
        if ($_.Exception.Message -notmatch $ExpectedMessagePattern) {
            throw "Assertion failed: expected an error matching '$ExpectedMessagePattern' but got '$($_.Exception.Message)'"
        }
        return
    }
    throw "Assertion failed: expected an error matching '$ExpectedMessagePattern' but nothing was thrown"
}

#endregion

#region Temporary workspaces

function New-TestDirectory {
    param([string]$Prefix = 'cet-test')
    $path = Join-Path ([IO.Path]::GetTempPath()) ('{0}-{1}' -f $Prefix, [guid]::NewGuid().ToString('N').Substring(0, 12))
    [void][IO.Directory]::CreateDirectory($path)
    $script:TemporaryDirectories.Add($path)
    return $path
}

function Remove-TestDirectories {
    foreach ($path in $script:TemporaryDirectories) {
        if (-not [IO.Directory]::Exists($path)) { continue }
        # Restore write permission removed by Block-FileReplacement before cleaning up.
        if (-not (Test-IsWindows)) { & chmod -R u+w $path 2>$null }
        Get-ChildItem -LiteralPath $path -Recurse -Force -Attributes ReparsePoint -ErrorAction SilentlyContinue |
            ForEach-Object { [IO.Directory]::Delete($_.FullName) }
        Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue
    }
    $script:TemporaryDirectories.Clear()
}

function Test-IsWindows {
    [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
}

function Get-RepositoryRoot { $script:RepositoryRoot }

function New-TestTemplate {
    <#
    .SYNOPSIS
        Copies the distributable parts of this repository into a temporary template checkout.
    #>
    param([switch]$WithGit)
    $root = New-TestDirectory -Prefix 'cet-template'
    foreach ($item in @('VERSION', 'TEMPLATE_MANIFEST.json', 'CHANGELOG.md', 'distribution', 'scripts')) {
        Copy-Item -LiteralPath (Join-Path $script:RepositoryRoot $item) -Destination $root -Recurse -Force
    }
    if ($WithGit) {
        Invoke-TestGit -Root $root -Arguments @('init', '--quiet', '--initial-branch', 'main')
        Save-TestTemplateRevision -TemplateRoot $root
    }
    return $root
}

function Invoke-TestGit {
    param([string]$Root, [string[]]$Arguments)
    $settings = @('-C', $Root, '-c', 'user.name=Template Tests', '-c', 'user.email=tests@example.invalid', '-c', 'commit.gpgsign=false', '-c', 'tag.gpgsign=false', '-c', 'core.autocrlf=false')
    $result = Invoke-NativeCommand -FilePath (Get-GitExecutable) -ArgumentList ($settings + $Arguments)
    if ($result.ExitCode -ne 0) { throw "git $($Arguments -join ' ') failed: $($result.StandardError)" }
}

function Save-TestTemplateRevision {
    # Commits the template and tags it with its VERSION, as a real release would.
    param([Parameter(Mandatory = $true)][string]$TemplateRoot)
    Invoke-TestGit -Root $TemplateRoot -Arguments @('add', '--all')
    Invoke-TestGit -Root $TemplateRoot -Arguments @('commit', '--quiet', '--allow-empty', '-m', 'test revision')
    Invoke-TestGit -Root $TemplateRoot -Arguments @('tag', ('v' + (Get-TemplateVersion -TemplateRoot $TemplateRoot)))
}

function New-TestProject {
    param([hashtable]$Files = @{})
    $root = New-TestDirectory -Prefix 'cet-project'
    foreach ($relativePath in $Files.Keys) { Set-TestFile -Root $root -RelativePath $relativePath -Content $Files[$relativePath] }
    return $root
}

function Get-TestPath {
    param([Parameter(Mandatory = $true)][string]$Root, [Parameter(Mandatory = $true)][string]$RelativePath)
    return [IO.Path]::Combine($Root, $RelativePath.Replace('/', [IO.Path]::DirectorySeparatorChar))
}

function Set-TestFile {
    param([string]$Root, [string]$RelativePath, [string]$Content)
    $path = Get-TestPath -Root $Root -RelativePath $RelativePath
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path))
    [IO.File]::WriteAllText($path, $Content, (New-Object Text.UTF8Encoding($false)))
}

function Add-TestFileContent {
    param([string]$Root, [string]$RelativePath, [string]$Content)
    $path = Get-TestPath -Root $Root -RelativePath $RelativePath
    [IO.File]::AppendAllText($path, $Content, (New-Object Text.UTF8Encoding($false)))
}

function Get-TestFileText {
    param([string]$Root, [string]$RelativePath)
    return [IO.File]::ReadAllText((Get-TestPath -Root $Root -RelativePath $RelativePath))
}

#endregion

#region Template manipulation

function Get-TestManifest {
    param([string]$TemplateRoot)
    return Read-JsonFile -Path (Join-Path $TemplateRoot 'TEMPLATE_MANIFEST.json')
}

function Save-TestManifest {
    param([string]$TemplateRoot, $Manifest)
    $json = ConvertTo-Json -InputObject $Manifest -Depth 10
    [IO.File]::WriteAllText((Join-Path $TemplateRoot 'TEMPLATE_MANIFEST.json'), $json, (New-Object Text.UTF8Encoding($false)))
}

function Get-TestManifestEntries {
    param([string]$TemplateRoot, [string]$Ownership)
    return @((Get-TestManifest -TemplateRoot $TemplateRoot).files | Where-Object { -not $Ownership -or $_.ownership -eq $Ownership })
}

function Set-TestManifestEntries {
    param([string]$TemplateRoot, [object[]]$Entries)
    $manifest = Get-TestManifest -TemplateRoot $TemplateRoot
    $manifest.files = @($Entries)
    Save-TestManifest -TemplateRoot $TemplateRoot -Manifest $manifest
}

function Add-TestManifestEntry {
    param(
        [string]$TemplateRoot,
        [string]$Source,
        [string]$Destination,
        [string]$Ownership = 'managed',
        [string]$Content = "# Added in test`n",
        [switch]$Prepend
    )
    $install = @{ managed = 'always'; project = 'ifMissing'; example = 'optIn' }[$Ownership]
    Set-TestFile -Root $TemplateRoot -RelativePath $Source -Content $Content
    $newEntry = [pscustomobject]@{ source = $Source; destination = $Destination; ownership = $Ownership; install = $install }
    $entries = @(Get-TestManifestEntries -TemplateRoot $TemplateRoot)
    if ($Prepend) { $entries = @($newEntry) + $entries } else { $entries += $newEntry }
    Set-TestManifestEntries -TemplateRoot $TemplateRoot -Entries $entries
}

function Remove-TestManifestEntry {
    param([string]$TemplateRoot, [string]$Destination)
    $entries = @(Get-TestManifestEntries -TemplateRoot $TemplateRoot | Where-Object { $_.destination -ne $Destination })
    Set-TestManifestEntries -TemplateRoot $TemplateRoot -Entries $entries
}

function Get-NextTestVersion {
    <#
    .SYNOPSIS
        Returns a version above Version (default: the next MINOR).
    .DESCRIPTION
        Update scenarios must derive their "newer release" from the repository's real VERSION.
        A hard-coded version breaks the suites, and therefore the release gate, as soon as the
        repository itself reaches that version.
    #>
    param([Parameter(Mandatory = $true)][string]$Version, [ValidateSet('Major', 'Minor', 'Patch')][string]$Part = 'Minor')
    $current = [version]$Version
    switch ($Part) {
        'Major' { return '{0}.0.0' -f ($current.Major + 1) }
        'Minor' { return '{0}.{1}.0' -f $current.Major, ($current.Minor + 1) }
        'Patch' { return '{0}.{1}.{2}' -f $current.Major, $current.Minor, ($current.Build + 1) }
    }
}

function Set-TestTemplateVersion {
    param([string]$TemplateRoot, [string]$Version)
    [IO.File]::WriteAllText((Join-Path $TemplateRoot 'VERSION'), "$Version`n")
}

#endregion

#region Running scripts and inspecting results

function Invoke-TemplateScript {
    <#
    .SYNOPSIS
        Runs a template script in a child process of the current PowerShell edition.
    .OUTPUTS
        An object with ExitCode and Output (stdout and stderr combined as text).
    #>
    param([Parameter(Mandatory = $true)][string]$TemplateRoot, [Parameter(Mandatory = $true)][string]$Script, [string[]]$Arguments = @())
    $scriptPath = Join-Path (Join-Path $TemplateRoot 'scripts') $Script
    $powerShell = (Get-Process -Id $PID).Path
    $result = Invoke-NativeCommand -FilePath $powerShell -ArgumentList (@('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $scriptPath) + $Arguments)
    return [pscustomobject]@{ ExitCode = $result.ExitCode; Output = ($result.StandardOutput + $result.StandardError) }
}

function Assert-ExitCode {
    param([int]$Expected, $Result, [string]$Context)
    if ($Result.ExitCode -ne $Expected) {
        throw "Assertion failed: $Context exited with $($Result.ExitCode), expected $Expected. Output:`n$($Result.Output)"
    }
}

function Get-DirectorySnapshot {
    <#
    .SYNOPSIS
        Maps every file below Root (relative, forward-slash path) to its SHA-256 hash.
    #>
    param([Parameter(Mandatory = $true)][string]$Root)
    $snapshot = @{}
    $rootLength = $Root.TrimEnd('\', '/').Length + 1
    foreach ($file in Get-ChildItem -LiteralPath $Root -Recurse -Force -File) {
        $relative = $file.FullName.Substring($rootLength).Replace('\', '/')
        $snapshot[$relative] = Get-FileSha256 -Path $file.FullName
    }
    return $snapshot
}

function Compare-DirectorySnapshot {
    param([hashtable]$Before, [hashtable]$After)
    $added = @($After.Keys | Where-Object { -not $Before.ContainsKey($_) } | Sort-Object)
    $removed = @($Before.Keys | Where-Object { -not $After.ContainsKey($_) } | Sort-Object)
    $changed = @($Before.Keys | Where-Object { $After.ContainsKey($_) -and $After[$_] -ne $Before[$_] } | Sort-Object)
    return [pscustomobject]@{ Added = $added; Removed = $removed; Changed = $changed }
}

function Assert-SnapshotUnchanged {
    param([hashtable]$Before, [hashtable]$After, [string]$Context)
    $difference = Compare-DirectorySnapshot -Before $Before -After $After
    $all = @($difference.Added) + @($difference.Removed) + @($difference.Changed)
    if ($all.Count -gt 0) {
        throw "Assertion failed: $Context changed files. Added: [$($difference.Added -join ', ')] Removed: [$($difference.Removed -join ', ')] Changed: [$($difference.Changed -join ', ')]"
    }
}

function Get-TestLock {
    param([string]$ProjectRoot)
    return Read-JsonFile -Path (Get-TestPath -Root $ProjectRoot -RelativePath '.claude/engineering-template.lock.json')
}

function Get-TestLockEntry {
    param([string]$ProjectRoot, [string]$Destination)
    return @((Get-TestLock -ProjectRoot $ProjectRoot).files | Where-Object { $_.destination -eq $Destination })[0]
}

function Block-FileReplacement {
    <#
    .SYNOPSIS
        Makes replacing one file fail, to simulate a partial failure. Returns a handle to release.
    .DESCRIPTION
        Windows: holds the file open with read-only sharing, so it can still be hashed and backed
        up but not replaced. Unix: removes write permission from its directory, because Unix
        file locks are advisory and would not stop the replacement.
    #>
    param([Parameter(Mandatory = $true)][string]$Path)
    if (Test-IsWindows) {
        $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
        return [pscustomobject]@{ Release = { $stream.Dispose() }.GetNewClosure() }
    }
    $directory = [IO.Path]::GetDirectoryName($Path)
    & chmod a-w $directory
    return [pscustomobject]@{ Release = { & chmod u+w $directory }.GetNewClosure() }
}

#endregion

#region Markdown frontmatter

function Read-Frontmatter {
    <#
    .SYNOPSIS
        Parses the YAML subset used by this repository's agent, skill and rule files.
    .DESCRIPTION
        Supports 'key: value' pairs, quoted values and block lists ('key:' followed by '  - item').
        Anything else is reported as an error so files stay within what this validator understands.
        Returns Values (hashtable), Body (string), HasFrontmatter (bool) and Errors (string[]).
    #>
    param([Parameter(Mandatory = $true)][string]$Path)
    $text = [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8) -replace "`r`n", "`n"
    $values = [ordered]@{}
    $errors = New-Object System.Collections.Generic.List[string]
    if (-not $text.StartsWith("---`n")) {
        return [pscustomobject]@{ HasFrontmatter = $false; Values = $values; Body = $text; Errors = @() }
    }
    $end = $text.IndexOf("`n---`n", 3)
    if ($end -lt 0) {
        return [pscustomobject]@{ HasFrontmatter = $true; Values = $values; Body = ''; Errors = @('frontmatter is not closed with ---') }
    }
    $currentListKey = $null
    foreach ($line in $text.Substring(4, $end - 3).TrimEnd("`n").Split("`n")) {
        if ($line.Trim().Length -eq 0) { continue }
        if ($line -match '^\s+-\s+(.+)$' -and $currentListKey) {
            $values[$currentListKey] = @($values[$currentListKey]) + (ConvertFrom-YamlScalar $Matches[1])
            continue
        }
        if ($line -match '^([A-Za-z][A-Za-z0-9_-]*):\s*$') {
            $currentListKey = $Matches[1]
            $values[$currentListKey] = @()
            continue
        }
        if ($line -match '^([A-Za-z][A-Za-z0-9_-]*):\s+(.+)$') {
            $currentListKey = $null
            $key = $Matches[1]
            $raw = $Matches[2]
            if ($raw -notmatch '^["'']' -and ($raw -match ': ' -or $raw -match ' #' -or $raw -match '^[\[{>|&*!%@`]')) {
                $errors.Add("value of '$key' must be quoted (it contains YAML syntax characters)")
            }
            $values[$key] = ConvertFrom-YamlScalar $raw
            continue
        }
        $errors.Add("unsupported frontmatter line: '$line'")
    }
    return [pscustomobject]@{ HasFrontmatter = $true; Values = $values; Body = $text.Substring($end + 5); Errors = $errors.ToArray() }
}

function ConvertFrom-YamlScalar {
    param([string]$Raw)
    $value = $Raw.Trim()
    if ($value.Length -ge 2 -and (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'")))) {
        return $value.Substring(1, $value.Length - 2)
    }
    return $value
}

#endregion

Export-ModuleMember -Function *
