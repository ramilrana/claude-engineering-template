# Project customization examples

These files are inactive reference material copied by `Install-EngineeringTemplate.ps1
-IncludeExamples`. Nothing here is loaded by Claude Code until you deliberately copy it into place.

## Settings and permissions

- `settings.recommended.json` - conservative permission rules: read-only Git commands allowed,
  history-changing and publishing commands require approval, secrets and destructive Git commands
  denied. Each command rule exists for both the `Bash` and the `PowerShell` tool, because on Windows
  Claude Code may run commands through either.
- `settings.hooks.example.json` and `hooks/guard-destructive-commands.ps1` - an example
  PreToolUse hook that blocks common destructive shell commands.

The template never writes `.claude/settings.json`, `.claude/settings.local.json`, hooks or MCP
configuration. To adopt these examples:

1. Review every rule against the project's real workflow.
2. Merge the relevant parts into `.claude/settings.json` by hand (it is strict JSON: no comments,
   no trailing commas). Keep personal preferences in `.claude/settings.local.json`.
3. For the hook, copy the script to `.claude/hooks/` and adjust the command for your platform
   (`powershell.exe` on Windows, `pwsh` on macOS and Linux).
4. Confirm with `/status` and `/hooks` in a Claude Code terminal session.

Do not add broad rules such as `Bash`, `Bash(*)`, `Edit` or `Write` to `allow`, and do not set
`bypassPermissions`. Permission rules on command text are not airtight (see the Claude Code
permissions documentation); deny rules, hooks and human review are layers, not guarantees.

## Project-specific rules, agents and skills

- `project-rule.example.md` - a path-scoped rule that strengthens the shared standards for one
  area of a project. Copy it to `.claude/rules/project-<topic>.md` and edit it.
- `project-agent.example.md` - a project-specific agent. Copy it to
  `.claude/agents/project-<role>.md` and edit it.

Naming: the `eng-` prefix is reserved for template-managed files. Use a `project-` prefix (or the
project's own) for local rules, agents and skills, so names never collide with template files.

To change a shared rule's behavior, prefer adding a stricter project rule over editing the
template file. If you must edit a managed `eng-` file, record the change under "Template
deviations" in `CLAUDE.md`; the updater keeps your version and reports a conflict candidate only
when a new release changes the central file. To stop receiving a managed file entirely, use
`Update-EngineeringTemplate.ps1 -Exclude <path>`.

Project customizations may strengthen the shared standards. They must not silently weaken
security, clean-code or responsive-design requirements.
