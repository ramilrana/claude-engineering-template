#Requires -Version 5.1
<#
.SYNOPSIS
    Core logic for installing and updating the Claude Code engineering template.

.DESCRIPTION
    Every file-system decision lives in this module so that the entry-point scripts
    stay thin and every rule can be tested in isolation. The flow is always:

        New-TemplateSyncPlan  -> pure analysis, no writes
        Invoke-TemplateSyncPlan -> applies the plan transactionally

    Compatible with Windows PowerShell 5.1 and PowerShell 7+. Keep this file ASCII-only:
    Windows PowerShell 5.1 reads BOM-less scripts using the legacy code page.
#>
Set-StrictMode -Version Latest

$script:TemplateId = 'claude-engineering-template'
$script:SupportedManifestSchemaVersion = 1
$script:SupportedLockSchemaVersion = 1
$script:LockRelativePath = '.claude/engineering-template.lock.json'
$script:CandidatesDirectoryName = '.template-update-candidates'
$script:BackupsDirectoryName = '.template-update-backups'
$script:Sha256Pattern = '^[0-9a-f]{64}$'
$script:SemVerPattern = '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$'

# Where each ownership class may be written and how it is installed. This policy is code,
# not manifest data, so that editing the manifest can never widen the set of project
# paths the installer is allowed to touch.
$script:OwnershipPolicy = @{
    managed = @{ Install = 'always'; AllowedDestinations = @('.claude/rules/', '.claude/agents/', '.claude/skills/', '.claude/engineering-standards/') }
    project = @{ Install = 'ifMissing'; AllowedDestinations = @('CLAUDE.md', 'docs/engineering/') }
    example = @{ Install = 'optIn'; AllowedDestinations = @('docs/engineering/template-examples/') }
}

$script:LockStatuses = @{
    managed = @('active', 'conflict', 'excluded', 'deprecated')
    project = @('created', 'preserved', 'removed', 'deprecated')
    example = @('created', 'preserved', 'removed', 'deprecated')
}

$script:ManifestTopLevelProperties = @('manifestSchemaVersion', 'templateId', 'description', 'minimumClaudeCodeVersion', 'files')
$script:ManifestEntryProperties = @('source', 'destination', 'ownership', 'install')
$script:WritingActions = @('Create', 'Update', 'Conflict', 'OfferReference')

#region Platform and general helpers

function Test-IsWindowsPlatform {
    [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
}

function Get-PathComparison {
    if (Test-IsWindowsPlatform) { return [StringComparison]::OrdinalIgnoreCase }
    return [StringComparison]::Ordinal
}

function New-CaseInsensitiveSet {
    New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
}

function Get-OptionalProperty {
    param($InputObject, [Parameter(Mandatory = $true)][string]$Name)
    if ($null -eq $InputObject -or $InputObject -isnot [System.Management.Automation.PSCustomObject]) { return $null }
    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Get-UtcTimestamp {
    (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm:ss'Z'", [Globalization.CultureInfo]::InvariantCulture)
}

function ConvertTo-IsoTimestamp {
    # PowerShell 7 turns ISO-8601 strings into DateTime while parsing JSON; 5.1 does not.
    param($Value)
    if ($Value -is [datetime]) {
        return $Value.ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm:ss'Z'", [Globalization.CultureInfo]::InvariantCulture)
    }
    return [string]$Value
}

function Get-SortedStrings {
    param([string[]]$Values)
    $array = @($Values | Where-Object { $_ })
    [Array]::Sort($array, [StringComparer]::Ordinal)
    return , $array
}

function Read-JsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)
    $text = [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
    return ($text | ConvertFrom-Json)
}

function Write-JsonFileAtomic {
    # Writes UTF-8 without BOM through a temporary file so readers never see a partial document.
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)]$Value)
    $json = ConvertTo-Json -InputObject $Value -Depth 10
    $temporaryPath = $Path + '.cet-tmp-' + [guid]::NewGuid().ToString('N')
    try {
        [IO.File]::WriteAllText($temporaryPath, $json + "`n", (New-Object Text.UTF8Encoding($false)))
        Move-FileReplacing -Source $temporaryPath -Destination $Path
    }
    catch {
        if ([IO.File]::Exists($temporaryPath)) { [IO.File]::Delete($temporaryPath) }
        throw
    }
}

function Move-FileReplacing {
    param([Parameter(Mandatory = $true)][string]$Source, [Parameter(Mandatory = $true)][string]$Destination)
    if ([IO.File]::Exists($Destination)) {
        # [NullString]::Value: PowerShell would otherwise pass "" for $null, which File.Replace rejects.
        [IO.File]::Replace($Source, $Destination, [NullString]::Value)
    }
    else {
        [IO.File]::Move($Source, $Destination)
    }
}

function Get-FileSha256 {
    # Uses .NET directly: in Windows PowerShell 5.1, Get-FileHash honors -WhatIf and returns
    # nothing during a dry run, which would break planning.
    param([Parameter(Mandatory = $true)][string]$Path)
    $stream = [IO.File]::OpenRead($Path)
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try { $hash = $algorithm.ComputeHash($stream) }
    finally {
        $algorithm.Dispose()
        $stream.Dispose()
    }
    return ([BitConverter]::ToString($hash) -replace '-', '').ToLowerInvariant()
}

#endregion

#region Native commands and git

function ConvertTo-QuotedArgument {
    # Quotes one argument using the Windows command-line convention, which .NET also uses on Unix.
    param([AllowEmptyString()][string]$Value)
    if ($Value.Length -gt 0 -and $Value -notmatch '[\s"]') { return $Value }
    $escaped = $Value -replace '(\\*)"', '$1$1\"'
    $escaped = $escaped -replace '(\\+)$', '$1$1'
    return '"' + $escaped + '"'
}

function Invoke-NativeCommand {
    <#
    .SYNOPSIS
        Runs an executable without the PowerShell native-command pipeline.
    .DESCRIPTION
        Windows PowerShell 5.1 can turn stderr output into terminating errors and re-encodes
        stdout as text. Using the process API keeps exit codes reliable and lets binary
        output be written byte-for-byte to a file.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$ArgumentList = @(),
        [string]$StandardOutputPath
    )
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $FilePath
    $startInfo.Arguments = (@($ArgumentList | ForEach-Object { ConvertTo-QuotedArgument $_ }) -join ' ')
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true

    $process = [System.Diagnostics.Process]::Start($startInfo)
    try {
        $standardErrorTask = $process.StandardError.ReadToEndAsync()
        $standardOutput = $null
        if ($StandardOutputPath) {
            $stream = [IO.File]::Create($StandardOutputPath)
            try { $process.StandardOutput.BaseStream.CopyTo($stream) }
            finally { $stream.Dispose() }
        }
        else {
            $standardOutput = $process.StandardOutput.ReadToEnd()
        }
        $process.WaitForExit()
        return [pscustomobject]@{
            ExitCode       = $process.ExitCode
            StandardOutput = $standardOutput
            StandardError  = $standardErrorTask.Result
        }
    }
    finally {
        $process.Dispose()
    }
}

function Get-GitExecutable {
    $command = Get-Command -Name git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $command) { return $null }
    return $command.Path
}

function Get-TemplateSourceRevision {
    <#
    .SYNOPSIS
        Describes the template checkout: tag, commit and whether it has uncommitted changes.
    #>
    param([Parameter(Mandatory = $true)][string]$TemplateRoot)
    $git = Get-GitExecutable
    if (-not $git) { return 'unknown (git not available)' }

    $head = Invoke-NativeCommand -FilePath $git -ArgumentList @('-C', $TemplateRoot, 'rev-parse', '--short=12', 'HEAD')
    if ($head.ExitCode -ne 0) { return 'unknown (not a git checkout)' }
    $revision = $head.StandardOutput.Trim()

    $tag = Invoke-NativeCommand -FilePath $git -ArgumentList @('-C', $TemplateRoot, 'describe', '--tags', '--exact-match', 'HEAD')
    if ($tag.ExitCode -eq 0) { $revision = '{0} ({1})' -f $tag.StandardOutput.Trim(), $revision }

    if (Test-GitWorkingTreeDirty -Root $TemplateRoot) { $revision += ' with uncommitted changes' }
    return $revision
}

function Test-GitWorkingTreeDirty {
    <#
    .SYNOPSIS
        Returns $true or $false for a git working tree, or $null when the path is not in one.
    #>
    param([Parameter(Mandatory = $true)][string]$Root)
    $git = Get-GitExecutable
    if (-not $git) { return $null }
    $status = Invoke-NativeCommand -FilePath $git -ArgumentList @('-C', $Root, 'status', '--porcelain')
    if ($status.ExitCode -ne 0) { return $null }
    return ($status.StandardOutput.Trim().Length -gt 0)
}

function Export-GitFileAtRevision {
    <#
    .SYNOPSIS
        Writes a file's exact bytes at a git revision to OutputPath. Returns $true on success.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$RepositoryRoot,
        [Parameter(Mandatory = $true)][string]$Revision,
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$OutputPath
    )
    $git = Get-GitExecutable
    if (-not $git) { return $false }
    $result = Invoke-NativeCommand -FilePath $git -ArgumentList @('-C', $RepositoryRoot, 'cat-file', 'blob', ('{0}:{1}' -f $Revision, $RelativePath)) -StandardOutputPath $OutputPath
    if ($result.ExitCode -ne 0) {
        if ([IO.File]::Exists($OutputPath)) { [IO.File]::Delete($OutputPath) }
        return $false
    }
    return $true
}

#endregion

#region Path safety

function Get-RelativePathError {
    <#
    .SYNOPSIS
        Returns a description of why a manifest or lock path is unsafe, or $null when it is safe.
    .DESCRIPTION
        Paths must be relative, use forward slashes and contain no traversal segments. The
        rules are deliberately stricter than any one filesystem requires so that a path
        means the same thing on Windows, macOS and Linux.
    #>
    param([AllowNull()][AllowEmptyString()][string]$RelativePath)
    if ([string]::IsNullOrWhiteSpace($RelativePath)) { return 'path is empty' }
    if ($RelativePath -match '[\x00-\x1f]') { return 'path contains control characters' }
    if ($RelativePath -match '[\\:*?"<>|]') { return 'path contains a backslash, colon or reserved character' }
    if ($RelativePath.StartsWith('/')) { return 'path must be relative' }
    foreach ($segment in $RelativePath.Split('/')) {
        if ($segment.Length -eq 0) { return 'path contains an empty segment' }
        if ($segment -eq '.' -or $segment -eq '..') { return "path contains a '$segment' segment" }
        if ($segment -ne $segment.Trim() -or $segment.EndsWith('.')) { return 'path segment has surrounding whitespace or a trailing dot' }
    }
    return $null
}

function Get-NormalizedRoot {
    param([Parameter(Mandatory = $true)][string]$Path)
    $fullPath = [IO.Path]::GetFullPath($Path)
    if ($fullPath -eq [IO.Path]::GetPathRoot($fullPath)) {
        throw "'$Path' is a filesystem root. Choose a project directory."
    }
    return $fullPath.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
}

function Get-PathAttributes {
    param([Parameter(Mandatory = $true)][string]$Path)
    try { return [IO.File]::GetAttributes($Path) }
    catch [IO.FileNotFoundException] { return $null }
    catch [IO.DirectoryNotFoundException] { return $null }
}

function Test-IsRedirectingLink {
    # Junctions and symbolic links redirect writes elsewhere. Other reparse points, such as cloud-file
    # placeholders (OneDrive) or deduplicated files, do not, and are allowed. When the link type
    # cannot be determined the path is treated as a link, failing safe.
    param([Parameter(Mandatory = $true)][string]$Path)
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if ($null -eq $item -or $null -eq $item.PSObject.Properties['LinkType']) { return $true }
    return @('Junction', 'SymbolicLink') -contains $item.LinkType
}

function Assert-NoReparsePoint {
    # Writing through a junction or symbolic link could escape the project directory even
    # when the textual path is contained, so every existing component below the root is checked.
    param([string]$Root, [string]$FullPath, [string]$RelativePath)
    $current = $FullPath
    while ($current.Length -gt $Root.Length) {
        $attributes = Get-PathAttributes -Path $current
        if ($null -ne $attributes -and ($attributes -band [IO.FileAttributes]::ReparsePoint) -and (Test-IsRedirectingLink -Path $current)) {
            throw "Refusing to use '$RelativePath': '$current' is a symbolic link or junction."
        }
        $current = [IO.Path]::GetDirectoryName($current)
    }
}

function Resolve-ContainedPath {
    <#
    .SYNOPSIS
        Converts a safe relative path to an absolute path that is guaranteed to stay inside Root.
    #>
    param([Parameter(Mandatory = $true)][string]$Root, [Parameter(Mandatory = $true)][string]$RelativePath)
    $pathError = Get-RelativePathError -RelativePath $RelativePath
    if ($pathError) { throw "Unsafe path '$RelativePath': $pathError." }

    $nativeRelativePath = $RelativePath.Replace('/', [IO.Path]::DirectorySeparatorChar)
    $fullPath = [IO.Path]::GetFullPath([IO.Path]::Combine($Root, $nativeRelativePath))
    if (-not $fullPath.StartsWith($Root + [IO.Path]::DirectorySeparatorChar, (Get-PathComparison))) {
        throw "Path '$RelativePath' resolves outside '$Root'."
    }
    Assert-NoReparsePoint -Root $Root -FullPath $fullPath -RelativePath $RelativePath
    return $fullPath
}

function Test-DestinationAllowed {
    param([string]$Destination, [string]$Ownership)
    foreach ($allowed in $script:OwnershipPolicy[$Ownership].AllowedDestinations) {
        if ($allowed.EndsWith('/')) {
            if ($Destination.Length -gt $allowed.Length -and $Destination.StartsWith($allowed, [StringComparison]::Ordinal)) { return $true }
        }
        elseif ($Destination -ceq $allowed) {
            return $true
        }
    }
    return $false
}

function ConvertTo-InertRelativePath {
    <#
    .SYNOPSIS
        Maps a destination to a path Claude Code will never load as an instruction file.
    .DESCRIPTION
        Claude Code discovers nested '.claude' directories and CLAUDE.md files, so candidate
        and backup copies replace dot-prefixed segments ('.claude' -> 'dot-claude') and always
        carry a suffix ('CLAUDE.md' -> 'CLAUDE.md.incoming').
    #>
    param([Parameter(Mandatory = $true)][string]$Destination, [Parameter(Mandatory = $true)][string]$Suffix)
    $segments = foreach ($segment in $Destination.Split('/')) {
        if ($segment.StartsWith('.')) { 'dot-' + $segment.Substring(1) } else { $segment }
    }
    return (@($segments) -join '/') + $Suffix
}

#endregion

#region Version, manifest and lock

function Get-TemplateVersion {
    param([Parameter(Mandatory = $true)][string]$TemplateRoot)
    $path = [IO.Path]::Combine($TemplateRoot, 'VERSION')
    if (-not [IO.File]::Exists($path)) { throw "VERSION file not found in '$TemplateRoot'." }
    $version = ([IO.File]::ReadAllText($path)).Trim()
    if ($version -notmatch $script:SemVerPattern) {
        throw "VERSION '$version' is not a MAJOR.MINOR.PATCH semantic version."
    }
    return $version
}

function Compare-TemplateVersion {
    param([Parameter(Mandatory = $true)][string]$Left, [Parameter(Mandatory = $true)][string]$Right)
    return ([version]$Left).CompareTo([version]$Right)
}

function Get-ManifestEntryErrors {
    param($Entry, [string]$TemplateRoot)
    if ($Entry -isnot [System.Management.Automation.PSCustomObject]) { return @('entry must be a JSON object') }

    $errors = New-Object System.Collections.Generic.List[string]
    foreach ($name in $Entry.PSObject.Properties.Name) {
        if ($script:ManifestEntryProperties -notcontains $name) { $errors.Add("unknown property '$name'") }
    }

    $source = Get-OptionalProperty $Entry 'source'
    $destination = Get-OptionalProperty $Entry 'destination'
    $ownership = Get-OptionalProperty $Entry 'ownership'
    $install = Get-OptionalProperty $Entry 'install'

    if ($source -isnot [string]) {
        $errors.Add('source must be a string')
    }
    elseif ($sourceError = Get-RelativePathError $source) {
        $errors.Add("source '$source' is unsafe: $sourceError")
    }
    elseif (-not $source.StartsWith('distribution/', [StringComparison]::Ordinal)) {
        $errors.Add("source '$source' must be inside distribution/")
    }
    else {
        try {
            if (-not [IO.File]::Exists((Resolve-ContainedPath -Root $TemplateRoot -RelativePath $source))) {
                $errors.Add("source '$source' does not exist")
            }
        }
        catch { $errors.Add($_.Exception.Message) }
    }

    if ($ownership -isnot [string] -or -not $script:OwnershipPolicy.ContainsKey($ownership)) {
        $errors.Add("ownership must be one of: $(@($script:OwnershipPolicy.Keys | Sort-Object) -join ', ')")
        return $errors
    }
    if ($install -ne $script:OwnershipPolicy[$ownership].Install) {
        $errors.Add("install must be '$($script:OwnershipPolicy[$ownership].Install)' for $ownership files")
    }

    if ($destination -isnot [string]) {
        $errors.Add('destination must be a string')
    }
    elseif ($destinationError = Get-RelativePathError $destination) {
        $errors.Add("destination '$destination' is unsafe: $destinationError")
    }
    elseif (-not (Test-DestinationAllowed -Destination $destination -Ownership $ownership)) {
        $errors.Add("destination '$destination' is not an allowed location for $ownership files ($($script:OwnershipPolicy[$ownership].AllowedDestinations -join ', '))")
    }
    elseif ($ownership -ne 'managed' -and $destination -ne 'CLAUDE.md' -and (Test-LoadableInstructionPath -Destination $destination)) {
        $errors.Add("destination '$destination' would be loaded by Claude Code as instructions; only managed files and the root CLAUDE.md may be")
    }
    return $errors
}

function Test-LoadableInstructionPath {
    # Claude Code discovers nested .claude directories and CLAUDE.md files anywhere in a project.
    param([string]$Destination)
    $segments = $Destination.Split('/')
    return (@($segments | Where-Object { $_ -eq '.claude' }).Count -gt 0) -or (@('CLAUDE.md', 'CLAUDE.local.md') -contains $segments[-1])
}

function Get-ManifestErrors {
    <#
    .SYNOPSIS
        Validates a parsed manifest and returns every problem found (empty when valid).
    #>
    param([Parameter(Mandatory = $true)]$Manifest, [Parameter(Mandatory = $true)][string]$TemplateRoot)
    $errors = New-Object System.Collections.Generic.List[string]
    if ($Manifest -isnot [System.Management.Automation.PSCustomObject]) {
        $errors.Add('manifest must be a JSON object')
        return $errors
    }
    foreach ($name in $Manifest.PSObject.Properties.Name) {
        if ($script:ManifestTopLevelProperties -notcontains $name) { $errors.Add("unknown top-level property '$name'") }
    }
    if ((Get-OptionalProperty $Manifest 'manifestSchemaVersion') -ne $script:SupportedManifestSchemaVersion) {
        $errors.Add("manifestSchemaVersion must be $script:SupportedManifestSchemaVersion")
    }
    if ((Get-OptionalProperty $Manifest 'templateId') -cne $script:TemplateId) {
        $errors.Add("templateId must be '$script:TemplateId'")
    }
    $minimumVersion = Get-OptionalProperty $Manifest 'minimumClaudeCodeVersion'
    if ($null -ne $minimumVersion -and ($minimumVersion -isnot [string] -or $minimumVersion -notmatch $script:SemVerPattern)) {
        $errors.Add('minimumClaudeCodeVersion must be a MAJOR.MINOR.PATCH string')
    }

    $entries = @(Get-OptionalProperty $Manifest 'files')
    if ($entries.Count -eq 0) {
        $errors.Add('files must contain at least one entry')
        return $errors
    }

    $destinations = New-CaseInsensitiveSet
    $sources = New-CaseInsensitiveSet
    for ($index = 0; $index -lt $entries.Count; $index++) {
        $entry = $entries[$index]
        foreach ($entryError in @(Get-ManifestEntryErrors -Entry $entry -TemplateRoot $TemplateRoot)) {
            $errors.Add("files[$index]: $entryError")
        }
        $destination = Get-OptionalProperty $entry 'destination'
        if ($destination -is [string] -and -not $destinations.Add($destination)) {
            $errors.Add("files[$index]: duplicate destination '$destination'")
        }
        $source = Get-OptionalProperty $entry 'source'
        if ($source -is [string] -and -not $sources.Add($source)) {
            $errors.Add("files[$index]: duplicate source '$source'")
        }
    }
    return $errors
}

function Read-TemplateManifest {
    <#
    .SYNOPSIS
        Reads and validates TEMPLATE_MANIFEST.json, returning normalized entries.
    #>
    param([Parameter(Mandatory = $true)][string]$TemplateRoot)
    $path = [IO.Path]::Combine($TemplateRoot, 'TEMPLATE_MANIFEST.json')
    if (-not [IO.File]::Exists($path)) { throw "Manifest not found: $path" }
    try { $manifest = Read-JsonFile -Path $path }
    catch { throw "Manifest is not valid JSON: $($_.Exception.Message)" }

    $errors = @(Get-ManifestErrors -Manifest $manifest -TemplateRoot $TemplateRoot)
    if ($errors.Count -gt 0) {
        throw ("Manifest validation failed:`n  - " + ($errors -join "`n  - "))
    }

    $entries = foreach ($entry in @($manifest.files)) {
        [pscustomobject]@{
            Source      = $entry.source
            Destination = $entry.destination
            Ownership   = $entry.ownership
        }
    }
    return [pscustomobject]@{
        MinimumClaudeCodeVersion = Get-OptionalProperty $manifest 'minimumClaudeCodeVersion'
        Entries                  = @($entries)
    }
}

function Get-LockErrors {
    param([Parameter(Mandatory = $true)]$Lock)
    $errors = New-Object System.Collections.Generic.List[string]
    if ($Lock -isnot [System.Management.Automation.PSCustomObject]) {
        $errors.Add('lock must be a JSON object')
        return $errors
    }
    if ((Get-OptionalProperty $Lock 'lockSchemaVersion') -ne $script:SupportedLockSchemaVersion) {
        $errors.Add("lockSchemaVersion must be $script:SupportedLockSchemaVersion")
    }
    if ((Get-OptionalProperty $Lock 'templateId') -cne $script:TemplateId) {
        $errors.Add("templateId must be '$script:TemplateId'")
    }
    $installedVersion = Get-OptionalProperty $Lock 'installedVersion'
    if ($installedVersion -isnot [string] -or $installedVersion -notmatch $script:SemVerPattern) {
        $errors.Add('installedVersion must be a MAJOR.MINOR.PATCH string')
    }

    foreach ($excluded in @(Get-OptionalProperty $Lock 'excluded')) {
        if ($excluded -isnot [string] -or (Get-RelativePathError $excluded)) {
            $errors.Add("excluded contains an unsafe path '$excluded'")
        }
    }

    $destinations = New-CaseInsensitiveSet
    $entries = @(Get-OptionalProperty $Lock 'files')
    for ($index = 0; $index -lt $entries.Count; $index++) {
        $entry = $entries[$index]
        $prefix = "files[$index]"
        $destination = Get-OptionalProperty $entry 'destination'
        $ownership = Get-OptionalProperty $entry 'ownership'
        $status = Get-OptionalProperty $entry 'status'

        if ($destination -isnot [string] -or (Get-RelativePathError $destination)) {
            $errors.Add("${prefix}: unsafe destination '$destination'")
            continue
        }
        if (-not $destinations.Add($destination)) { $errors.Add("${prefix}: duplicate destination '$destination'") }
        if ($ownership -isnot [string] -or -not $script:OwnershipPolicy.ContainsKey($ownership)) {
            $errors.Add("${prefix}: unknown ownership '$ownership' for '$destination'")
            continue
        }
        if (-not (Test-DestinationAllowed -Destination $destination -Ownership $ownership)) {
            $errors.Add("${prefix}: '$destination' is not an allowed location for $ownership files")
        }
        if ($script:LockStatuses[$ownership] -notcontains $status) {
            $errors.Add("${prefix}: status '$status' is not valid for $ownership files")
        }

        if ($ownership -eq 'managed') {
            $sha256 = Get-OptionalProperty $entry 'sha256'
            $templateVersion = Get-OptionalProperty $entry 'templateVersion'
            if ($null -eq $sha256) {
                # Files the template never installed (pre-existing conflicts, exclusions) have no hash,
                # and keep none when a later release deprecates them.
                if (@('conflict', 'excluded', 'deprecated') -notcontains $status) { $errors.Add("${prefix}: sha256 is required for '$destination'") }
            }
            elseif ($sha256 -isnot [string] -or $sha256 -notmatch $script:Sha256Pattern) {
                $errors.Add("${prefix}: sha256 for '$destination' is not a lowercase SHA-256 hex digest")
            }
            elseif ($templateVersion -isnot [string] -or $templateVersion -notmatch $script:SemVerPattern) {
                $errors.Add("${prefix}: templateVersion for '$destination' must be a MAJOR.MINOR.PATCH string")
            }
        }
        else {
            $templateSha256 = Get-OptionalProperty $entry 'templateSha256'
            if ($null -ne $templateSha256 -and ($templateSha256 -isnot [string] -or $templateSha256 -notmatch $script:Sha256Pattern)) {
                $errors.Add("${prefix}: templateSha256 for '$destination' is not a lowercase SHA-256 hex digest")
            }
        }
    }
    return $errors
}

function Read-TemplateLock {
    <#
    .SYNOPSIS
        Reads and validates the project's lock file. Returns $null when the project has none.
    #>
    param([Parameter(Mandatory = $true)][string]$ProjectRoot)
    $path = Resolve-ContainedPath -Root $ProjectRoot -RelativePath $script:LockRelativePath
    if (-not [IO.File]::Exists($path)) { return $null }

    try { $lock = Read-JsonFile -Path $path }
    catch { throw "Lock file '$script:LockRelativePath' is not valid JSON. Restore it from version control before continuing." }

    $errors = @(Get-LockErrors -Lock $lock)
    if ($errors.Count -gt 0) {
        throw ("Lock file '$script:LockRelativePath' is invalid; ownership cannot be determined safely:`n  - " + ($errors -join "`n  - "))
    }

    $entries = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($entry in @(Get-OptionalProperty $lock 'files')) {
        $entries[$entry.destination] = [pscustomobject]@{
            Destination     = $entry.destination
            Ownership       = $entry.ownership
            Status          = $entry.status
            Sha256          = Get-OptionalProperty $entry 'sha256'
            TemplateVersion = Get-OptionalProperty $entry 'templateVersion'
            TemplateSha256  = Get-OptionalProperty $entry 'templateSha256'
        }
    }
    $excluded = New-CaseInsensitiveSet
    foreach ($excludedPath in @(Get-OptionalProperty $lock 'excluded')) { [void]$excluded.Add($excludedPath) }

    return [pscustomobject]@{
        InstalledVersion = $lock.installedVersion
        SourceRevision   = Get-OptionalProperty $lock 'sourceRevision'
        InstalledAt      = ConvertTo-IsoTimestamp (Get-OptionalProperty $lock 'installedAt')
        Excluded         = $excluded
        Entries          = $entries
    }
}

#endregion

#region Planning

function Get-LockEntry {
    param($Lock, [string]$Destination)
    if ($null -eq $Lock -or -not $Lock.Entries.ContainsKey($Destination)) { return $null }
    return $Lock.Entries[$Destination]
}

function Assert-ModeMatchesLock {
    param([string]$Mode, $Lock, [string]$Version, [switch]$AllowDowngrade)
    if ($Mode -eq 'Install') {
        if ($null -ne $Lock -and $Lock.InstalledVersion -ne $Version) {
            throw "Template $($Lock.InstalledVersion) is already installed. Use Update-EngineeringTemplate.ps1 to move to $Version."
        }
        return
    }
    if ($null -eq $Lock) {
        throw "No '$script:LockRelativePath' found. Run Install-EngineeringTemplate.ps1 first."
    }
    if ((Compare-TemplateVersion -Left $Version -Right $Lock.InstalledVersion) -lt 0 -and -not $AllowDowngrade) {
        throw "Template $Version is older than the installed $($Lock.InstalledVersion). Re-run with -AllowDowngrade if this is intentional."
    }
}

function Assert-OwnershipConsistent {
    param($Lock, [object[]]$ManifestEntries)
    if ($null -eq $Lock) { return }
    foreach ($entry in $ManifestEntries) {
        $lockEntry = Get-LockEntry -Lock $Lock -Destination $entry.Destination
        if ($null -ne $lockEntry -and $lockEntry.Ownership -ne $entry.Ownership) {
            throw "Ownership of '$($entry.Destination)' changed from '$($lockEntry.Ownership)' to '$($entry.Ownership)'. Review this file manually before updating; the CHANGELOG migration notes explain the change."
        }
    }
}

function Resolve-Exclusions {
    param($Lock, [object[]]$ManifestEntries, [string[]]$Exclude, [string[]]$Include)
    $excluded = New-CaseInsensitiveSet
    if ($null -ne $Lock) { foreach ($path in $Lock.Excluded) { [void]$excluded.Add($path) } }

    $managedDestinations = New-CaseInsensitiveSet
    foreach ($entry in $ManifestEntries) {
        if ($entry.Ownership -eq 'managed') { [void]$managedDestinations.Add($entry.Destination) }
    }
    foreach ($path in $Exclude) {
        if (-not $managedDestinations.Contains($path)) {
            throw "Cannot exclude '$path': only managed files listed in the manifest can be excluded."
        }
        [void]$excluded.Add($path)
    }
    foreach ($path in $Include) {
        if (-not $excluded.Remove($path)) { throw "Cannot include '$path': it is not currently excluded." }
    }
    return , $excluded
}

function New-SyncOperation {
    param(
        [string]$Action,
        [string]$Destination,
        [string]$Ownership,
        [string]$Source,
        [string]$SourcePath,
        [string]$TargetPath,
        [string]$IncomingSha256,
        [string]$LocalSha256,
        $LockEntry,
        [string]$CandidatePath,
        [string]$Reason
    )
    [pscustomobject]@{
        Action         = $Action
        Destination    = $Destination
        Ownership      = $Ownership
        Source         = $Source
        SourcePath     = $SourcePath
        TargetPath     = $TargetPath
        IncomingSha256 = $IncomingSha256
        LocalSha256    = $LocalSha256
        LockEntry      = $LockEntry
        CandidatePath  = $CandidatePath
        Reason         = $Reason
    }
}

function Get-ManagedAction {
    # Implements the managed-file decision table documented in docs/DISTRIBUTION_AND_VERSIONING.md.
    param([bool]$IsExcluded, [bool]$Exists, [string]$LocalSha256, [string]$IncomingSha256, $LockEntry)
    if ($IsExcluded) { return @('Excluded', 'excluded by this project') }
    if (-not $Exists) { return @('Create', $null) }
    $recordedSha256 = $null
    if ($null -ne $LockEntry) { $recordedSha256 = $LockEntry.Sha256 }
    if ($LocalSha256 -eq $IncomingSha256) {
        if ($null -eq $LockEntry -or $LockEntry.Status -ne 'active') { return @('Adopt', 'identical file already present') }
        return @('Skip', $null)
    }
    # A file whose content the template never recorded is not ours to replace.
    if ($null -eq $recordedSha256) { return @('Conflict', 'a different file already exists at this path') }
    if ($recordedSha256 -eq $LocalSha256) { return @('Update', $null) }
    # A customization only needs a merge decision when the central version moved on.
    if ($recordedSha256 -eq $IncomingSha256) { return @('KeepCustomized', 'modified locally; central version unchanged') }
    return @('Conflict', 'modified locally since the last template install')
}

function Get-ProjectOwnedAction {
    param([string]$Mode, [bool]$Exists, [string]$IncomingSha256, $LockEntry)
    if (-not $Exists) {
        if ($null -ne $LockEntry -and $LockEntry.Status -ne 'deprecated') { return @('RemovedByProject', 'deleted by the project; not recreated') }
        return @('Create', $null)
    }
    $templateChanged = $null -ne $LockEntry -and $null -ne $LockEntry.TemplateSha256 -and $LockEntry.TemplateSha256 -ne $IncomingSha256
    if ($Mode -eq 'Update' -and $templateChanged) { return @('OfferReference', 'project-owned; the template version changed') }
    return @('Preserve', 'project-owned')
}

function New-TemplateSyncPlan {
    <#
    .SYNOPSIS
        Analyzes a project against the template and returns the operations an install or update would perform.
    .DESCRIPTION
        Performs no writes. Throws when the manifest, lock file, versions or ownership are
        invalid or ambiguous so that nothing is applied from an unsafe starting point.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$TemplateRoot,
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [Parameter(Mandatory = $true)][ValidateSet('Install', 'Update')][string]$Mode,
        [switch]$IncludeExamples,
        [string[]]$Exclude = @(),
        [string[]]$Include = @(),
        [switch]$AllowDowngrade
    )
    $templateRootPath = Get-NormalizedRoot -Path $TemplateRoot
    $projectRootPath = Get-NormalizedRoot -Path $ProjectRoot
    if (-not [IO.Directory]::Exists($projectRootPath)) { throw "Project directory '$projectRootPath' does not exist." }
    $comparison = Get-PathComparison
    if ($projectRootPath.Equals($templateRootPath, $comparison) -or $projectRootPath.StartsWith($templateRootPath + [IO.Path]::DirectorySeparatorChar, $comparison)) {
        throw 'The project directory must not be the template repository or inside it.'
    }

    $version = Get-TemplateVersion -TemplateRoot $templateRootPath
    $manifest = Read-TemplateManifest -TemplateRoot $templateRootPath
    $lock = Read-TemplateLock -ProjectRoot $projectRootPath
    Assert-ModeMatchesLock -Mode $Mode -Lock $lock -Version $version -AllowDowngrade:$AllowDowngrade
    Assert-OwnershipConsistent -Lock $lock -ManifestEntries $manifest.Entries
    $excluded = Resolve-Exclusions -Lock $lock -ManifestEntries $manifest.Entries -Exclude $Exclude -Include $Include

    $operations = New-Object System.Collections.Generic.List[object]
    $manifestDestinations = New-CaseInsensitiveSet
    foreach ($entry in $manifest.Entries) {
        [void]$manifestDestinations.Add($entry.Destination)
        $lockEntry = Get-LockEntry -Lock $lock -Destination $entry.Destination
        if ($entry.Ownership -eq 'example' -and -not $IncludeExamples -and $null -eq $lockEntry) { continue }

        $sourcePath = Resolve-ContainedPath -Root $templateRootPath -RelativePath $entry.Source
        $targetPath = Resolve-ContainedPath -Root $projectRootPath -RelativePath $entry.Destination
        if ([IO.Directory]::Exists($targetPath)) { throw "Destination '$($entry.Destination)' is a directory in the project; expected a file." }
        $exists = [IO.File]::Exists($targetPath)
        $incomingSha256 = Get-FileSha256 -Path $sourcePath
        $localSha256 = $null
        if ($exists) { $localSha256 = Get-FileSha256 -Path $targetPath }

        if ($entry.Ownership -eq 'managed') {
            $decision = Get-ManagedAction -IsExcluded $excluded.Contains($entry.Destination) -Exists $exists -LocalSha256 $localSha256 -IncomingSha256 $incomingSha256 -LockEntry $lockEntry
        }
        else {
            $decision = Get-ProjectOwnedAction -Mode $Mode -Exists $exists -IncomingSha256 $incomingSha256 -LockEntry $lockEntry
        }

        $candidatePath = $null
        if (@('Conflict', 'OfferReference') -contains $decision[0]) {
            $candidatePath = '{0}/{1}/{2}' -f $script:CandidatesDirectoryName, $version, (ConvertTo-InertRelativePath -Destination $entry.Destination -Suffix '.incoming')
        }
        $operations.Add((New-SyncOperation -Action $decision[0] -Reason $decision[1] -Destination $entry.Destination -Ownership $entry.Ownership `
                    -Source $entry.Source -SourcePath $sourcePath -TargetPath $targetPath -IncomingSha256 $incomingSha256 `
                    -LocalSha256 $localSha256 -LockEntry $lockEntry -CandidatePath $candidatePath))
    }

    if ($null -ne $lock) {
        foreach ($lockEntry in $lock.Entries.Values) {
            if ($manifestDestinations.Contains($lockEntry.Destination)) { continue }
            $operations.Add((New-SyncOperation -Action 'Deprecated' -Destination $lockEntry.Destination -Ownership $lockEntry.Ownership `
                        -LockEntry $lockEntry -Reason 'no longer distributed; left in place'))
        }
    }

    $previousVersion = $null
    if ($null -ne $lock) { $previousVersion = $lock.InstalledVersion }
    return [pscustomobject]@{
        Mode                     = $Mode
        TemplateRoot             = $templateRootPath
        ProjectRoot              = $projectRootPath
        Version                  = $version
        PreviousVersion          = $previousVersion
        MinimumClaudeCodeVersion = $manifest.MinimumClaudeCodeVersion
        SourceRevision           = Get-TemplateSourceRevision -TemplateRoot $templateRootPath
        ProjectHasUncommittedWork = Test-GitWorkingTreeDirty -Root $projectRootPath
        Lock                     = $lock
        Excluded                 = $excluded
        Operations               = $operations.ToArray()
    }
}

#endregion

#region Lock document

function New-LockFileRecord {
    param([pscustomobject]$Operation, [string]$Version)
    $lockEntry = $Operation.LockEntry
    if ($Operation.Ownership -eq 'managed') {
        switch ($Operation.Action) {
            { @('Create', 'Update', 'Skip', 'Adopt') -contains $_ } { $status = 'active'; $sha256 = $Operation.IncomingSha256; $templateVersion = $Version }
            'Deprecated' { $status = 'deprecated'; $sha256 = $lockEntry.Sha256; $templateVersion = $lockEntry.TemplateVersion }
            'KeepCustomized' {
                $status = 'active'
                if ($lockEntry.Status -eq 'conflict') { $status = 'conflict' }
                $sha256 = $lockEntry.Sha256; $templateVersion = $lockEntry.TemplateVersion
            }
            default {
                # Conflict and Excluded keep the last content the template actually installed, which is
                # what the next update needs to tell an unchanged file from a customized one.
                $status = $Operation.Action.ToLowerInvariant()
                $sha256 = $null; $templateVersion = $null
                if ($null -ne $lockEntry) { $sha256 = $lockEntry.Sha256; $templateVersion = $lockEntry.TemplateVersion }
            }
        }
        if ($null -eq $sha256) { $templateVersion = $null }
        return [ordered]@{ destination = $Operation.Destination; ownership = 'managed'; status = $status; sha256 = $sha256; templateVersion = $templateVersion }
    }

    $templateSha256 = $Operation.IncomingSha256
    switch ($Operation.Action) {
        'Create' { $status = 'created' }
        'RemovedByProject' { $status = 'removed'; $templateSha256 = $lockEntry.TemplateSha256 }
        'Deprecated' { $status = 'deprecated'; $templateSha256 = $lockEntry.TemplateSha256 }
        default {
            $status = 'preserved'
            if ($null -ne $lockEntry -and $lockEntry.Status -eq 'created') { $status = 'created' }
        }
    }
    return [ordered]@{ destination = $Operation.Destination; ownership = $Operation.Ownership; status = $status; templateSha256 = $templateSha256 }
}

function New-LockDocument {
    param([Parameter(Mandatory = $true)]$Plan, [string]$Timestamp)
    $records = @($Plan.Operations | ForEach-Object { New-LockFileRecord -Operation $_ -Version $Plan.Version })
    # Ordinal sorting keeps the lock byte-identical across cultures and PowerShell editions.
    $keys = [string[]]@($records | ForEach-Object { $_.destination })
    $sortedRecords = [object[]]$records.Clone()
    [Array]::Sort($keys, $sortedRecords, [StringComparer]::Ordinal)
    $installedAt = $Timestamp
    if ($null -ne $Plan.Lock -and $Plan.Lock.InstalledAt) { $installedAt = $Plan.Lock.InstalledAt }

    return [ordered]@{
        lockSchemaVersion = $script:SupportedLockSchemaVersion
        templateId        = $script:TemplateId
        installedVersion  = $Plan.Version
        sourceRevision    = $Plan.SourceRevision
        installedAt       = $installedAt
        updatedAt         = $Timestamp
        excluded          = Get-SortedStrings -Values @($Plan.Excluded)
        files             = $sortedRecords
    }
}

function Test-LockChanged {
    # Compares everything except timestamps so that a no-op run leaves the lock file untouched.
    param([Parameter(Mandatory = $true)][string]$ProjectRoot, [Parameter(Mandatory = $true)]$NewLock)
    $path = Resolve-ContainedPath -Root $ProjectRoot -RelativePath $script:LockRelativePath
    if (-not [IO.File]::Exists($path)) { return $true }
    $current = Read-JsonFile -Path $path
    $comparable = {
        param($lock)
        $files = @($lock.files | ForEach-Object { ConvertTo-Json -InputObject $_ -Compress -Depth 5 })
        @($lock.installedVersion, $lock.sourceRevision, (@($lock.excluded) -join '|'), ($files -join '|')) -join "`n"
    }
    $newLockAsJson = ConvertTo-Json -InputObject $NewLock -Depth 10 | ConvertFrom-Json
    return (& $comparable $current) -ne (& $comparable $newLockAsJson)
}

#endregion

#region Applying a plan

function New-SyncTransaction {
    [pscustomobject]@{
        CreatedFiles       = New-Object System.Collections.Generic.List[string]
        ReplacedFiles      = New-Object System.Collections.Generic.List[object]
        CreatedDirectories = New-Object System.Collections.Generic.List[string]
        TemporaryFiles     = New-Object System.Collections.Generic.List[string]
    }
}

function New-ContainedDirectory {
    # Creates missing directories one level at a time so rollback can remove exactly what it created.
    param([string]$Root, [string]$DirectoryPath, $Transaction)
    $missing = New-Object System.Collections.Generic.Stack[string]
    $current = $DirectoryPath
    while ($current.Length -gt $Root.Length -and -not [IO.Directory]::Exists($current)) {
        $missing.Push($current)
        $current = [IO.Path]::GetDirectoryName($current)
    }
    while ($missing.Count -gt 0) {
        $directory = $missing.Pop()
        [void][IO.Directory]::CreateDirectory($directory)
        $Transaction.CreatedDirectories.Add($directory)
    }
}

function Copy-VerifiedFile {
    <#
    .SYNOPSIS
        Copies Source over Target through a verified temporary file and records the change for rollback.
    #>
    param(
        [string]$Root,
        [string]$SourcePath,
        [string]$TargetPath,
        [string]$ExpectedSha256,
        [string]$BackupPath,
        $Transaction
    )
    New-ContainedDirectory -Root $Root -DirectoryPath ([IO.Path]::GetDirectoryName($TargetPath)) -Transaction $Transaction
    $temporaryPath = $TargetPath + '.cet-tmp-' + [guid]::NewGuid().ToString('N')
    $Transaction.TemporaryFiles.Add($temporaryPath)
    [IO.File]::Copy($SourcePath, $temporaryPath, $false)
    if ((Get-FileSha256 -Path $temporaryPath) -ne $ExpectedSha256) {
        throw "Hash verification failed while copying '$SourcePath'."
    }

    if ([IO.File]::Exists($TargetPath)) {
        if (-not $BackupPath) { throw "Internal error: refusing to replace '$TargetPath' without a backup." }
        Move-FileReplacing -Source $temporaryPath -Destination $TargetPath
        $Transaction.ReplacedFiles.Add([pscustomobject]@{ TargetPath = $TargetPath; BackupPath = $BackupPath })
    }
    else {
        Move-FileReplacing -Source $temporaryPath -Destination $TargetPath
        $Transaction.CreatedFiles.Add($TargetPath)
    }
    [void]$Transaction.TemporaryFiles.Remove($temporaryPath)
}

function Write-CandidateFile {
    # An identical existing candidate is reused. A different one (from an earlier run of the same
    # version, possibly annotated by a person) is renamed aside rather than deleted, so nothing is
    # lost even if this run is rolled back.
    param([string]$Root, [string]$SourcePath, [string]$CandidatePath, [string]$ExpectedSha256, [string]$Timestamp, $Transaction)
    if ([IO.File]::Exists($CandidatePath)) {
        if ((Get-FileSha256 -Path $CandidatePath) -eq $ExpectedSha256) { return }
        [IO.File]::Move($CandidatePath, $CandidatePath + '.superseded-' + ($Timestamp -replace '[-:]', ''))
    }
    Copy-VerifiedFile -Root $Root -SourcePath $SourcePath -TargetPath $CandidatePath -ExpectedSha256 $ExpectedSha256 -Transaction $Transaction
}

function Write-BaseCandidate {
    <#
    .SYNOPSIS
        Saves the previously installed central version next to a conflict candidate for a three-way comparison.
    .DESCRIPTION
        The base is read from the template's git tag for the version recorded in the lock and is
        only kept when its hash matches the recorded hash. Returns a note describing the outcome.
    #>
    param($Plan, $Operation, [string]$Timestamp, $Transaction)
    $lockEntry = $Operation.LockEntry
    if ($null -eq $lockEntry -or $null -eq $lockEntry.Sha256 -or $null -eq $lockEntry.TemplateVersion) {
        return "no base version for '$($Operation.Destination)' (the file was not installed by the template)"
    }
    $baseRelative = $Operation.CandidatePath -replace '\.incoming$', '.base'
    $basePath = Resolve-ContainedPath -Root $Plan.ProjectRoot -RelativePath $baseRelative
    $exportPath = [IO.Path]::Combine([IO.Path]::GetTempPath(), 'cet-base-' + [guid]::NewGuid().ToString('N'))
    try {
        $tag = 'v' + $lockEntry.TemplateVersion
        if (-not (Export-GitFileAtRevision -RepositoryRoot $Plan.TemplateRoot -Revision $tag -RelativePath $Operation.Source -OutputPath $exportPath)) {
            return "no base version for '$($Operation.Destination)' (tag $tag is not available in the template checkout)"
        }
        if ((Get-FileSha256 -Path $exportPath) -ne $lockEntry.Sha256) {
            return "no base version for '$($Operation.Destination)' (content at $tag does not match the recorded hash)"
        }
        Write-CandidateFile -Root $Plan.ProjectRoot -SourcePath $exportPath -CandidatePath $basePath -ExpectedSha256 $lockEntry.Sha256 -Timestamp $Timestamp -Transaction $Transaction
        return $null
    }
    finally {
        if ([IO.File]::Exists($exportPath)) { [IO.File]::Delete($exportPath) }
    }
}

function Backup-FilesToReplace {
    param($Plan, [string]$Timestamp, $Transaction)
    $updates = @($Plan.Operations | Where-Object { $_.Action -eq 'Update' })
    if ($updates.Count -eq 0) { return $null }

    $fromVersion = if ($Plan.PreviousVersion) { $Plan.PreviousVersion } else { 'none' }
    $directoryName = '{0}-{1}-to-{2}' -f ($Timestamp -replace '[-:]', ''), $fromVersion, $Plan.Version
    $backupRelativeRoot = '{0}/{1}' -f $script:BackupsDirectoryName, $directoryName
    $records = New-Object System.Collections.Generic.List[object]
    $backupPaths = @{}

    foreach ($operation in $updates) {
        $backupRelative = '{0}/{1}' -f $backupRelativeRoot, (ConvertTo-InertRelativePath -Destination $operation.Destination -Suffix '.bak')
        $backupPath = Resolve-ContainedPath -Root $Plan.ProjectRoot -RelativePath $backupRelative
        New-ContainedDirectory -Root $Plan.ProjectRoot -DirectoryPath ([IO.Path]::GetDirectoryName($backupPath)) -Transaction $Transaction
        [IO.File]::Copy($operation.TargetPath, $backupPath, $false)
        if ((Get-FileSha256 -Path $backupPath) -ne $operation.LocalSha256) {
            throw "'$($operation.Destination)' changed while the update was running; no files were replaced."
        }
        $backupPaths[$operation.Destination] = $backupPath
        $records.Add([ordered]@{ destination = $operation.Destination; backup = $backupRelative; sha256 = $operation.LocalSha256 })
    }

    $indexPath = Resolve-ContainedPath -Root $Plan.ProjectRoot -RelativePath ($backupRelativeRoot + '/backup.json')
    Write-JsonFileAtomic -Path $indexPath -Value ([ordered]@{
            createdAt   = $Timestamp
            fromVersion = $Plan.PreviousVersion
            toVersion   = $Plan.Version
            files       = $records.ToArray()
        })
    return [pscustomobject]@{ RelativePath = $backupRelativeRoot; Paths = $backupPaths }
}

function Undo-SyncTransaction {
    # Best-effort rollback in reverse order; returns the problems it could not fix.
    param($Transaction)
    $problems = New-Object System.Collections.Generic.List[string]
    foreach ($path in $Transaction.TemporaryFiles) {
        try { if ([IO.File]::Exists($path)) { [IO.File]::Delete($path) } }
        catch { $problems.Add("could not remove temporary file '$path': $($_.Exception.Message)") }
    }
    for ($index = $Transaction.ReplacedFiles.Count - 1; $index -ge 0; $index--) {
        $replaced = $Transaction.ReplacedFiles[$index]
        try { [IO.File]::Copy($replaced.BackupPath, $replaced.TargetPath, $true) }
        catch { $problems.Add("could not restore '$($replaced.TargetPath)' from '$($replaced.BackupPath)': $($_.Exception.Message)") }
    }
    for ($index = $Transaction.CreatedFiles.Count - 1; $index -ge 0; $index--) {
        $path = $Transaction.CreatedFiles[$index]
        try { if ([IO.File]::Exists($path)) { [IO.File]::Delete($path) } }
        catch { $problems.Add("could not remove newly created '$path': $($_.Exception.Message)") }
    }
    for ($index = $Transaction.CreatedDirectories.Count - 1; $index -ge 0; $index--) {
        $path = $Transaction.CreatedDirectories[$index]
        try {
            if ([IO.Directory]::Exists($path) -and @([IO.Directory]::GetFileSystemEntries($path)).Count -eq 0) { [IO.Directory]::Delete($path) }
        }
        catch { $problems.Add("could not remove directory '$path': $($_.Exception.Message)") }
    }
    return $problems
}

function Invoke-TemplateSyncPlan {
    <#
    .SYNOPSIS
        Applies a plan created by New-TemplateSyncPlan.
    .DESCRIPTION
        Files that will be replaced are backed up first. Every copy is hash-verified. If any step
        fails, completed steps are rolled back and the lock file is left untouched, so the lock
        never claims an update that did not happen. Backups are always kept.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)]$Plan)
    $timestamp = Get-UtcTimestamp
    $transaction = New-SyncTransaction
    $notes = New-Object System.Collections.Generic.List[string]
    $backup = $null
    try {
        $backup = Backup-FilesToReplace -Plan $Plan -Timestamp $timestamp -Transaction $transaction
        foreach ($operation in $Plan.Operations) {
            switch ($operation.Action) {
                'Create' {
                    Copy-VerifiedFile -Root $Plan.ProjectRoot -SourcePath $operation.SourcePath -TargetPath $operation.TargetPath -ExpectedSha256 $operation.IncomingSha256 -Transaction $transaction
                }
                'Update' {
                    Copy-VerifiedFile -Root $Plan.ProjectRoot -SourcePath $operation.SourcePath -TargetPath $operation.TargetPath -ExpectedSha256 $operation.IncomingSha256 -BackupPath $backup.Paths[$operation.Destination] -Transaction $transaction
                }
                { @('Conflict', 'OfferReference') -contains $_ } {
                    $candidatePath = Resolve-ContainedPath -Root $Plan.ProjectRoot -RelativePath $operation.CandidatePath
                    Write-CandidateFile -Root $Plan.ProjectRoot -SourcePath $operation.SourcePath -CandidatePath $candidatePath -ExpectedSha256 $operation.IncomingSha256 -Timestamp $timestamp -Transaction $transaction
                    if ($operation.Action -eq 'Conflict') {
                        $note = Write-BaseCandidate -Plan $Plan -Operation $operation -Timestamp $timestamp -Transaction $transaction
                        if ($note) { $notes.Add($note) }
                    }
                }
            }
        }

        $lockDocument = New-LockDocument -Plan $Plan -Timestamp $timestamp
        $lockWritten = Test-LockChanged -ProjectRoot $Plan.ProjectRoot -NewLock $lockDocument
        if ($lockWritten) {
            $lockPath = Resolve-ContainedPath -Root $Plan.ProjectRoot -RelativePath $script:LockRelativePath
            New-ContainedDirectory -Root $Plan.ProjectRoot -DirectoryPath ([IO.Path]::GetDirectoryName($lockPath)) -Transaction $transaction
            Write-JsonFileAtomic -Path $lockPath -Value $lockDocument
        }
    }
    catch {
        $failure = $_.Exception.Message
        $problems = @(Undo-SyncTransaction -Transaction $transaction)
        $message = "Template $($Plan.Mode.ToLowerInvariant()) failed: $failure`nCompleted changes were rolled back and '$script:LockRelativePath' was not modified."
        if ($null -ne $backup) { $message += "`nBackups of the original files remain in '$($backup.RelativePath)'." }
        if ($problems.Count -gt 0) {
            $message += "`nROLLBACK INCOMPLETE - restore these manually (see docs/TROUBLESHOOTING.md):`n  - " + ($problems -join "`n  - ")
        }
        throw $message
    }

    $backupRelativePath = $null
    if ($null -ne $backup) { $backupRelativePath = $backup.RelativePath }
    return [pscustomobject]@{
        LockWritten        = $lockWritten
        BackupRelativePath = $backupRelativePath
        Notes              = $notes.ToArray()
    }
}

#endregion

#region Reporting

$script:ActionDescriptions = [ordered]@{
    Create           = 'Create'
    Update           = 'Update (unchanged locally; original backed up)'
    Adopt            = 'Adopt (identical file already present)'
    Skip             = 'Already current'
    Conflict         = 'CONFLICT - local file kept; incoming version saved as a candidate'
    KeepCustomized   = 'Customized locally, kept (central version unchanged)'
    OfferReference   = 'Project-owned, kept; newer template saved for reference'
    Preserve         = 'Project-owned, kept'
    RemovedByProject = 'Removed by the project; not recreated'
    Excluded         = 'Excluded by the project'
    Deprecated       = 'DEPRECATED - no longer distributed; left in place'
}

function Write-TemplateSyncPlan {
    param([Parameter(Mandatory = $true)]$Plan)
    $from = if ($Plan.PreviousVersion) { $Plan.PreviousVersion } else { 'not installed' }
    Write-Host ''
    Write-Host ("Template {0}: {1} -> {2}" -f $Plan.Mode.ToLowerInvariant(), $from, $Plan.Version)
    Write-Host ("Project:  {0}" -f $Plan.ProjectRoot)
    Write-Host ("Source:   {0} [{1}]" -f $Plan.TemplateRoot, $Plan.SourceRevision)
    if ($Plan.MinimumClaudeCodeVersion) { Write-Host ("Requires: Claude Code {0} or later" -f $Plan.MinimumClaudeCodeVersion) }
    if ($Plan.ProjectHasUncommittedWork) {
        Write-Host 'WARNING: the project has uncommitted changes. Commit or stash them and use a dedicated branch so the template change can be reviewed on its own.' -ForegroundColor Yellow
    }

    foreach ($action in $script:ActionDescriptions.Keys) {
        $matching = @($Plan.Operations | Where-Object { $_.Action -eq $action })
        if ($matching.Count -eq 0) { continue }
        $color = 'Gray'
        if (@('Conflict', 'Deprecated') -contains $action) { $color = 'Yellow' }
        Write-Host ''
        Write-Host ("{0} ({1}):" -f $script:ActionDescriptions[$action], $matching.Count) -ForegroundColor $color
        foreach ($operation in $matching) {
            $line = '  ' + $operation.Destination
            if ($operation.CandidatePath) { $line += '  ->  ' + $operation.CandidatePath }
            elseif ($action -eq 'Conflict' -or $action -eq 'Deprecated') { $line += '  (' + $operation.Reason + ')' }
            Write-Host $line -ForegroundColor $color
        }
    }
    Write-Host ''
}

function Write-TemplateSyncResult {
    param([Parameter(Mandatory = $true)]$Plan, [Parameter(Mandatory = $true)]$Result)
    if ($Result.BackupRelativePath) { Write-Host "Backups of replaced files: $($Result.BackupRelativePath)" }
    foreach ($note in $Result.Notes) { Write-Host "Note: $note" }
    if ($Result.LockWritten) { Write-Host "Recorded installation in $script:LockRelativePath" }
    elseif ((Get-PlannedWriteCount -Plan $Plan) -gt 0) { Write-Host "Files were written as listed above; $script:LockRelativePath was already up to date." }
    else { Write-Host 'Nothing changed; the project already matches this template version.' }

    $conflicts = @($Plan.Operations | Where-Object { $_.Action -eq 'Conflict' })
    if ($conflicts.Count -gt 0) {
        Write-Host ''
        Write-Host "$($conflicts.Count) conflict(s) need a merge decision. For each one compare:" -ForegroundColor Yellow
        Write-Host '  base     = <candidate>.base      (central version you last installed, when available)' -ForegroundColor Yellow
        Write-Host '  local    = the project file      (your customized copy, left untouched)' -ForegroundColor Yellow
        Write-Host '  incoming = <candidate>.incoming  (new central version)' -ForegroundColor Yellow
        Write-Host 'Example: git merge-file -p <local> <base> <incoming>   (prints a merged result; nothing is written)' -ForegroundColor Yellow
        Write-Host 'The eng-template-update skill walks through reconciliation. Re-run the update afterwards to record the result.' -ForegroundColor Yellow
    }
    if (@($Plan.Operations | Where-Object { $_.Action -eq 'Deprecated' }).Count -gt 0) {
        Write-Host 'Deprecated files were left in place. Check CHANGELOG.md for migration notes before deleting them yourself.' -ForegroundColor Yellow
    }
    $candidateDirectory = '{0}/{1}' -f $script:CandidatesDirectoryName, $Plan.Version
    if (@($Plan.Operations | Where-Object { $_.CandidatePath }).Count -gt 0) {
        Write-Host "Candidates are in $candidateDirectory (inactive; Claude Code does not load them). Consider adding $script:CandidatesDirectoryName/ and $script:BackupsDirectoryName/ to .gitignore."
    }
}

function Get-TemplateSyncExitCode {
    <#
    .SYNOPSIS
        0 = success, 2 = completed with conflicts that need a merge decision.
    #>
    param([Parameter(Mandatory = $true)]$Plan)
    if (@($Plan.Operations | Where-Object { $_.Action -eq 'Conflict' }).Count -gt 0) { return 2 }
    return 0
}

function Get-PlannedWriteCount {
    param([Parameter(Mandatory = $true)]$Plan)
    return @($Plan.Operations | Where-Object { $script:WritingActions -contains $_.Action }).Count
}

#endregion

#region Command entry point

function Split-ListArgument {
    # 'powershell -File script.ps1 -Exclude a,b' passes one string, so lists are also accepted comma-separated.
    param([string[]]$Values)
    return , @($Values | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

function Invoke-TemplateSyncCommand {
    <#
    .SYNOPSIS
        Shared body of Install-EngineeringTemplate.ps1 and Update-EngineeringTemplate.ps1.
    .OUTPUTS
        The process exit code: 0 success, 1 failure (nothing changed), 2 completed with conflicts.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)][ValidateSet('Install', 'Update')][string]$Mode,
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [Parameter(Mandatory = $true)][string]$TemplateRoot,
        [switch]$IncludeExamples,
        [string[]]$Exclude = @(),
        [string[]]$Include = @(),
        [switch]$AllowDowngrade
    )
    try {
        $plan = New-TemplateSyncPlan -Mode $Mode `
            -ProjectRoot $PSCmdlet.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ProjectRoot) `
            -TemplateRoot $PSCmdlet.SessionState.Path.GetUnresolvedProviderPathFromPSPath($TemplateRoot) `
            -IncludeExamples:$IncludeExamples -Exclude (Split-ListArgument $Exclude) -Include (Split-ListArgument $Include) `
            -AllowDowngrade:$AllowDowngrade
        Write-TemplateSyncPlan -Plan $plan

        $description = '{0} engineering template {1} ({2} file write(s))' -f $Mode, $plan.Version, (Get-PlannedWriteCount -Plan $plan)
        if (-not $PSCmdlet.ShouldProcess($plan.ProjectRoot, $description)) { return 0 }

        $result = Invoke-TemplateSyncPlan -Plan $plan
        Write-TemplateSyncResult -Plan $plan -Result $result
        return (Get-TemplateSyncExitCode -Plan $plan)
    }
    catch {
        $Host.UI.WriteErrorLine("ERROR: $($_.Exception.Message)")
        return 1
    }
}

#endregion

Export-ModuleMember -Function @(
    'Get-RelativePathError',
    'Resolve-ContainedPath',
    'ConvertTo-InertRelativePath',
    'Get-FileSha256',
    'Get-TemplateVersion',
    'Compare-TemplateVersion',
    'Get-ManifestErrors',
    'Read-TemplateManifest',
    'Read-TemplateLock',
    'New-TemplateSyncPlan',
    'Invoke-TemplateSyncPlan',
    'Write-TemplateSyncPlan',
    'Write-TemplateSyncResult',
    'Get-TemplateSyncExitCode',
    'Get-PlannedWriteCount',
    'Invoke-TemplateSyncCommand',
    'Get-TemplateSourceRevision',
    'Test-GitWorkingTreeDirty',
    'Get-GitExecutable',
    'Invoke-NativeCommand',
    'Read-JsonFile'
)
