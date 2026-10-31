# Troubleshooting

## Running the scripts

| Symptom | Cause | Fix |
|---|---|---|
| "running scripts is disabled on this system" | Execution policy | Run through `powershell -NoProfile -ExecutionPolicy Bypass -File <script>`; this affects only that process |
| "is not digitally signed" or a security warning | Files from a downloaded ZIP are marked as downloaded | After checking their origin: `Get-ChildItem -Recurse -Filter *.ps1* \| Unblock-File`, or clone with Git instead |
| A list parameter is treated as one value | `-File` passes `-Exclude a,b` as one string | Supported: values are split on commas |
| `pwsh` is not recognized | PowerShell 7 is not installed | Use `powershell` (5.1) on Windows, or install PowerShell 7 |

## Installer or updater exits with 1

Nothing was changed. The message names the problem:

| Message contains | Meaning | What to do |
|---|---|---|
| `Manifest validation failed` / `not valid JSON` | The template checkout is broken or modified | `git status` in the template checkout; check out a release tag |
| `already installed. Use Update-EngineeringTemplate.ps1` | The project has a different version installed | Use the updater |
| `No '.claude/engineering-template.lock.json' found` | The project was never installed | Use the installer |
| `Lock file ... is not valid JSON` / `is invalid` | The lock was edited or damaged | Restore it from Git (`git checkout -- .claude/engineering-template.lock.json`); never edit it by hand |
| `Ownership of '<path>' changed` | A release moved a file between ownership classes | Read the release's migration notes; resolve the file manually, then rerun |
| `older than the installed` | The template checkout is on an older tag | Check out the intended tag, or use `-AllowDowngrade` deliberately |
| `symbolic link or junction` | A directory on the destination path is a link | Replace the link with a real directory, or exclude the affected files |
| `must not be the template repository` | `-ProjectRoot` points at or inside the template | Point at the project directory |
| `Cannot exclude` | The path is not a managed manifest destination | Use the exact destination from the manifest |

## Exit code 2: conflicts

A managed file differs from what the template last installed (or existed before installation). It
was kept. Compare the files in `.template-update-candidates/<version>/` (`.incoming` = new central,
`.base` = previously installed central) with your file, merge deliberately (the
`eng-template-update` skill helps), then rerun the updater.

If every managed file is reported as a conflict right after cloning the project on another
machine, line endings probably changed. Ensure the project's Git settings do not convert the
template files (`core.autocrlf=false`, or a `.gitattributes` entry such as
`.claude/** text eol=lf`), restore the files from Git, and rerun.

## A run failed part-way

The script rolls back automatically and says so. If it reports `ROLLBACK INCOMPLETE`:

1. Open the backup folder it names (`.template-update-backups/<timestamp>-<from>-to-<to>/`).
2. `backup.json` maps each destination to its backup file and hash.
3. Copy each backup file back to its destination (or restore from Git: `git checkout -- <path>`).
4. The lock file was not modified; rerun the updater after fixing the cause (often a file locked by
   an editor or antivirus, or missing write permission).

## Claude Code does not pick up installed files

| Symptom | Check |
|---|---|
| Agents missing from `/agents` | Restart the session; confirm the files are in `.claude/agents/` with frontmatter starting on line 1 |
| Skills missing from the `/` menu | Confirm `.claude/skills/<name>/SKILL.md`; manual-only skills are hidden from automatic use but listed in the menu |
| UI rules not applied | `eng-responsive-design` and `eng-frontend-quality` load only for matching files; extend the globs in a project rule if your UI files use other extensions |
| Old behavior after an update | Start a new session so updated rules and agents are loaded |
| Version mismatch warnings | The template targets Claude Code 2.1.309 or later; update Claude Code |

## Tests

| Symptom | Fix |
|---|---|
| A suite fails only under PowerShell 7 or only on Linux | Look for case-sensitive paths, `\` path separators or 5.1-only APIs |
| `git` errors in update tests | Install Git; tests that need conflict bases use it |
| Temporary folders left behind after an interrupted run | Delete `cet-*` folders in the system temporary directory |
