# Distribution and versioning

## Model

One central repository produces tested, tagged releases. A project installs a copy of one release,
customizes it, and later updates to a newer release when its maintainers decide to. There is no
live link, shared path or automatic upgrade.

## The manifest (`TEMPLATE_MANIFEST.json`)

```json
{
  "manifestSchemaVersion": 1,
  "templateId": "claude-engineering-template",
  "description": "...",
  "minimumClaudeCodeVersion": "2.1.309",
  "files": [
    { "source": "distribution/managed/.claude/rules/eng-security.md",
      "destination": ".claude/rules/eng-security.md",
      "ownership": "managed", "install": "always" }
  ]
}
```

Validation rejects the whole manifest when any entry:

- has an absolute path, drive letter, backslash, colon, reserved character, empty segment, `.`,
  `..`, trailing dot or surrounding whitespace in `source` or `destination`;
- has a `source` outside `distribution/`, or a source file that does not exist;
- has an unknown property, ownership or install value, or an install value that does not match
  its ownership;
- has a destination outside the locations allowed for its ownership;
- would place a project or example file where Claude Code loads instructions (a `.claude`
  directory, or a `CLAUDE.md` other than the root one);
- duplicates a destination or source (case-insensitively).

The template version is not repeated in the manifest; `VERSION` is the only source.

## Ownership classes

| Ownership | Install value | Allowed destinations (fixed in code) | Install | Update |
|---|---|---|---|---|
| `managed` | `always` | `.claude/rules/`, `.claude/agents/`, `.claude/skills/`, `.claude/engineering-standards/` | Copied; an existing different file is a conflict | Hash-checked replacement (see table below) |
| `project` | `ifMissing` | `CLAUDE.md`, `docs/engineering/` | Created only if missing | Never modified; changed templates offered for reference |
| `example` | `optIn` | `docs/engineering/template-examples/` | Only with `-IncludeExamples` | Like `project` |

## The lock file (`.claude/engineering-template.lock.json`)

```json
{
  "lockSchemaVersion": 1,
  "templateId": "claude-engineering-template",
  "installedVersion": "1.1.0",
  "sourceRevision": "v1.1.0 (3c32b195b5e6)",
  "installedAt": "2026-10-31T09:12:44Z",
  "updatedAt": "2026-11-20T15:03:10Z",
  "excluded": [".claude/agents/eng-database-engineer.md"],
  "files": [
    { "destination": ".claude/rules/eng-security.md", "ownership": "managed", "status": "active",
      "sha256": "<hash of the central content last installed>", "templateVersion": "1.1.0" },
    { "destination": "CLAUDE.md", "ownership": "project", "status": "preserved",
      "templateSha256": "<hash of the scaffold template last offered>" }
  ]
}
```

| Field | Meaning |
|---|---|
| `sha256` | For managed files: the central content the template last installed. Comparing it with the file on disk tells an untouched file from a customized one |
| `templateVersion` | The release that `sha256` belongs to; used to fetch the conflict base from the matching Git tag |
| `templateSha256` | For project-owned files: the scaffold version last offered, so a changed scaffold is offered once |
| `status` | Managed: `active`, `conflict`, `excluded`, `deprecated`. Project and example: `created`, `preserved`, `removed`, `deprecated` |

The lock contains only relative paths and hashes: no machine paths, user names or secrets. It is
written last, through a temporary file, and only when the whole run succeeded. Commit it.

## Install algorithm

1. Resolve and validate the project and template roots; refuse filesystem roots and installing into
   the template repository.
2. Read `VERSION`; read and validate the manifest; confirm every source exists.
3. Read and validate any existing lock. If it records a different version, stop and point to the
   updater.
4. For each entry, resolve the destination inside the project, refusing paths that escape it or
   pass through a symbolic link or junction.
5. Plan: managed files are `Create`, `Skip` (identical), `Adopt` (identical, not yet recorded),
   `Excluded` or `Conflict`; project files are `Create` or `Preserve`; examples only with
   `-IncludeExamples`.
6. Print the plan. With `-WhatIf`, stop.
7. Apply with verified copies, then write the lock (see "Applying a plan").

Running the installer again for the same version changes nothing unless files changed. Installer
and updater share the decision table below, so a re-run also restores deleted managed files and,
with a backup, refreshes managed files that are unchanged since installation.

## Update decision table

| Situation | Action | Lock afterwards |
|---|---|---|
| Managed file does not exist | Install it (`Create`) | `active`, new hash |
| Existing file identical to incoming | `Skip`, or `Adopt` when the lock had no active record for it | `active`, new hash |
| Existing file matches the previously recorded hash | Back up, then replace (`Update`) | `active`, new hash |
| Existing file differs from the recorded hash, central version changed | Keep it; save `.incoming` and `.base` candidates (`Conflict`) | `conflict`, previous hash kept |
| Existing file differs from the recorded hash, central version unchanged | Keep it; nothing to merge (`KeepCustomized`) | status and hash unchanged |
| File exists at a managed path but its content was never recorded | Keep it; save candidate (`Conflict`) | `conflict`, no hash |
| Managed file excluded by the project | Leave untouched (`Excluded`) | `excluded` |
| Entry removed from the new manifest | Leave the file (`Deprecated`); never delete | `deprecated`, hash kept if any |
| Deprecated entry returns in a later release | Treated like any recorded file (unchanged files are updated, customized ones conflict) | `active` or `conflict` |
| Project-owned file exists | Keep it (`Preserve`); if its template changed, save an `.incoming` reference once (`OfferReference`) | `templateSha256` set to the template offered; a file recreated after removal becomes `preserved` |
| Project-owned file deleted by the project | Do not recreate (`RemovedByProject`) | `removed` |
| Lock invalid, ownership changed between versions, unsafe path, older target version without `-AllowDowngrade` | Stop before writing | unchanged |
| Any write fails | Roll back the run | unchanged |

A customized file is reported as a conflict only when the central version differs from the one the
project last installed. It stays a conflict on later updates until its content equals the central
version; a deliberate permanent customization is therefore reported again only when the central
file changes.

## Conflict candidates

```text
.template-update-candidates/<target version>/
    dot-claude/rules/eng-security.md.incoming   new central version
    dot-claude/rules/eng-security.md.base       central version previously installed (if available)
    CLAUDE.md.incoming                          reference copy of a changed scaffold
```

Leading dots are replaced (`.claude` -> `dot-claude`) and every file has a suffix, so Claude Code
never loads candidates as rules, skills, agents or `CLAUDE.md`. If a different candidate already
exists from an earlier run of the same version, it is renamed to `<name>.superseded-<timestamp>`
rather than deleted. The `.base` file comes from the
template checkout's `v<templateVersion>` tag and is kept only when its hash equals the recorded hash.

Reconcile with a three-way comparison of base, local and incoming (`git merge-file -p local base
incoming`), or with the `eng-template-update` skill, then run the updater again to record the result.

## Applying a plan, backups and recovery

1. Files to be replaced are copied to `.template-update-backups/<timestamp>-<from>-to-<to>/` with a
   `backup.json` index and verified by hash.
2. Each new file is written to a temporary file next to its destination, verified by hash, then
   moved into place.
3. Candidates are written the same way.
4. The lock file is written last.

If any step fails, replaced files are restored from the backups, files and directories created by
the run are removed, temporary files are deleted, and the lock is not modified. The error message
names the backup folder and anything that could not be restored.

Backups are never deleted automatically. Retention policy: keep them until the update branch is
merged and the project's tests pass, then delete the folder manually. Candidates follow the same
policy after their conflicts are reconciled.

## Exclusions

`-Exclude <path>` (installer or updater) stops managing a managed file; an existing copy is left in
place. `-Include <path>` (updater) resumes management. Exclusions are recorded in the lock.

## Semantic versioning

| Change | Version |
|---|---|
| Wording fixes, clarifications, bug fixes in scripts, new tests | PATCH |
| New rules, standards, agents, skills, scaffold or example files; new optional script parameters | MINOR |
| Removing or renaming a managed file, changing a destination or ownership, changing manifest or lock schema, behavior changes that require project action | MAJOR |

Every MAJOR release and every release that deprecates files has a **Migration** section in
`CHANGELOG.md`.

## Using a specific version

Check out the release tag in the template checkout (`git checkout v1.0.0`) and run the installer or
updater. A project can stay on any release; moving to an older release requires
`-AllowDowngrade`.
