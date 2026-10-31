# Installing the template into a project (Windows)

## Prerequisites

| Requirement | Check | Notes |
|---|---|---|
| Windows PowerShell 5.1 or PowerShell 7+ | `$PSVersionTable.PSVersion` | 5.1 is built into Windows 10 and 11 |
| Git | `git --version` | Recommended: release tags, conflict bases, source revision in the lock |
| Claude Code 2.1.309+ | `claude --version`, or the desktop app's About | For the projects that use the installed files |

No modules, package managers or network access are needed.

## 1. Get the template

```powershell
git clone <url-of-this-repository> C:\Tools\claude-engineering-template
cd C:\Tools\claude-engineering-template
git tag --list "v*"
git checkout v1.0.0
```

Keep one checkout and switch tags as needed. Installing from an untagged commit works, but the lock
file then records a commit instead of a release.

If you downloaded a ZIP instead of cloning, Windows marks the scripts as downloaded. Unblock them
after checking their origin: `Get-ChildItem -Recurse -Filter *.ps1* | Unblock-File`.

## 2. Prepare the project

```powershell
cd C:\Projects\my-app
git status                                   # commit or stash your own work first
git switch -c chore/engineering-template     # review the install like any change
```

## 3. Preview

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\Tools\claude-engineering-template\scripts\Install-EngineeringTemplate.ps1 -ProjectRoot C:\Projects\my-app -WhatIf
```

`-ExecutionPolicy Bypass` applies only to this one process; it does not change system settings.

The preview lists what would be created, adopted, preserved or reported as a conflict. Nothing is
written.

## 4. Install

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\Tools\claude-engineering-template\scripts\Install-EngineeringTemplate.ps1 -ProjectRoot C:\Projects\my-app
```

| Exit code | Meaning | What to do |
|---|---|---|
| 0 | Installed | Review and commit |
| 2 | Installed, with conflicts | A file already existed at a managed path. It was kept; the template version is in `.template-update-candidates/<version>/`. Decide per file (see `eng-template-update`), then run the installer again |
| 1 | Failed, nothing changed | Read the error; see [TROUBLESHOOTING.md](TROUBLESHOOTING.md) |

Options:

- `-IncludeExamples` - also copy recommended settings, a guard hook and customization samples to
  `docs/engineering/template-examples/` (inactive until you adopt them).
- `-Exclude .claude/agents/eng-database-engineer.md,.claude/rules/eng-frontend-quality.md` - skip
  managed files that do not apply; recorded in the lock file and respected by later updates.

## 5. After installing

1. Add the tool folders to the project's `.gitignore`:

   ```gitignore
   .template-update-candidates/
   .template-update-backups/
   ```

2. Review `git diff --stat` and the new files. Commit `.claude/` (including
   `engineering-template.lock.json`), `CLAUDE.md` and `docs/engineering/`.
3. Open the project in Claude Code and confirm:
   - `/agents` lists the nine `eng-` agents;
   - typing `/eng-` shows the skills;
   - asking Claude "which engineering rules are loaded?" names the `eng-` rules from `.claude/rules/`.
4. Run `/eng-project-bootstrap` to fill in the project documents. If the project kept its own
   `CLAUDE.md`, add the line `@docs/engineering/CURRENT_STATE.md` to it (the skill proposes this)
   so the current state is loaded in every session.
5. Optionally adopt settings from `docs/engineering/template-examples/` by hand.

## PowerShell 7, macOS and Linux

```bash
pwsh -NoProfile -File ~/tools/claude-engineering-template/scripts/Install-EngineeringTemplate.ps1 -ProjectRoot ~/projects/my-app -WhatIf
```

The scripts and tests run on PowerShell 7 on every platform; CI checks Windows and Linux.

## Installing a specific older release

Check out that release's tag in the template checkout and run the installer. Projects may stay on
any release for as long as they need.
