#Requires -Version 5.1
<#
.SYNOPSIS
    Example Claude Code PreToolUse hook that blocks destructive shell commands.

.DESCRIPTION
    Reads the hook input JSON from stdin, inspects tool_input.command and exits with code 2 (block)
    and a reason on stderr when the command matches a destructive pattern. Any other input exits 0,
    so Claude Code's normal permission flow still applies.

    This is a guardrail, not a security boundary: pattern matching on command text can be evaded
    (aliases, variables, scripts). Keep permission deny rules and human approval in place.

    Install by copying to .claude/hooks/guard-destructive-commands.ps1 in the project and merging
    the hooks block from settings.hooks.example.json into .claude/settings.json after review.
    On macOS and Linux, use "pwsh" instead of "powershell.exe" as the hook command.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Each pattern is matched case-insensitively against the full command text.
$blockedPatterns = @(
    @{ Pattern = 'git\s+push\b[^\n]*(\s--force\b|\s--force-with-lease\b|\s-f\b|\s\+\S)'; Reason = 'force push rewrites remote history' }
    @{ Pattern = 'git\s+reset\s+[^\n]*--hard\b'; Reason = 'git reset --hard discards uncommitted work' }
    @{ Pattern = 'git\s+clean\s+[^\n]*-[a-z]*f'; Reason = 'git clean -f deletes untracked files' }
    @{ Pattern = 'git\s+(checkout|restore)\s+(--\s+)?\.(\s|$)'; Reason = 'discards all uncommitted changes' }
    @{ Pattern = 'git\s+branch\s+[^\n]*-D\b'; Reason = 'force-deletes a branch' }
    @{ Pattern = '--no-verify\b'; Reason = 'skips repository hooks' }
    @{ Pattern = '\brm\s+-[a-z]*(rf|fr)[a-z]*\b'; Reason = 'recursive forced deletion' }
    @{ Pattern = 'Remove-Item\b(?=[^\n]*-Recurse)(?=[^\n]*-Force)'; Reason = 'recursive forced deletion' }
    @{ Pattern = '\b(DROP\s+(DATABASE|SCHEMA|TABLE)|TRUNCATE\s+TABLE)\b'; Reason = 'destructive database statement' }
)

try {
    $hookInput = [Console]::In.ReadToEnd() | ConvertFrom-Json
}
catch {
    exit 0 # Not valid hook input; do not interfere.
}

$toolInput = $hookInput.PSObject.Properties['tool_input']
if ($null -eq $toolInput -or $null -eq $toolInput.Value.PSObject.Properties['command']) { exit 0 }
$command = [string]$toolInput.Value.command

foreach ($rule in $blockedPatterns) {
    if ($command -match $rule.Pattern) {
        [Console]::Error.WriteLine("Blocked by guard-destructive-commands hook: $($rule.Reason). Ask the user to run this command themselves if it is really intended.")
        exit 2
    }
}
exit 0
