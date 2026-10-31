---
name: eng-template-update
description: "Guide controlled adoption of a newer engineering-template version: review the lock file, preview managed-file changes, detect customization conflicts, run the updater on a dedicated branch, reconcile conflicts with a three-way comparison and verify the project."
when_to_use: "Use when the user wants to update, upgrade or check the claude-engineering-template version installed in this project, or to resolve template update conflicts."
argument-hint: "[path to the template checkout] [target version]"
disable-model-invocation: true
---

# Update the engineering template

Adopt a newer template release deliberately, without losing project customizations. Every
consequential step needs the user's approval. Never edit `.claude/engineering-template.lock.json`
by hand.

Arguments: $ARGUMENTS

## Step 1 - Current state

1. Read `.claude/engineering-template.lock.json`: installed version, source revision, files with
   status `conflict`, `excluded` or `deprecated`.
2. Run `git status`. The working tree must be clean before updating; if not, ask the user to commit
   or stash their work. Never discard it.
3. Read the "Template deviations" section of `CLAUDE.md` for intentional customizations.

## Step 2 - Locate and select the template version

1. Ask for the local path of the `claude-engineering-template` checkout if it was not given.
2. In that checkout, list available releases with `git tag --list "v*"` and read `CHANGELOG.md`
   entries between the installed and the target version, especially breaking changes, deprecated
   files and migration instructions.
3. With approval, check out the target tag in the template checkout (`git checkout v<version>`).
   The project may stay on an older version; updating is the user's choice.

## Step 3 - Prepare a branch and preview

1. With approval, create a branch in the project, for example `chore/engineering-template-v<version>`.
2. Preview without writing:

   Windows PowerShell:
   `powershell -NoProfile -ExecutionPolicy Bypass -File <template>/scripts/Update-EngineeringTemplate.ps1 -ProjectRoot . -WhatIf`

   PowerShell 7 (Windows, macOS, Linux):
   `pwsh -NoProfile -File <template>/scripts/Update-EngineeringTemplate.ps1 -ProjectRoot . -WhatIf`

3. Summarize the plan for the user: files to create, update, conflicts, deprecated files,
   scaffold references. Explain anything surprising using the changelog.

## Step 4 - Apply (after approval)

Run the same command without `-WhatIf`. Exit codes: 0 success, 2 completed with conflicts, 1 failed
with all changes rolled back and the lock unchanged. Report the output faithfully.

## Step 5 - Reconcile conflicts

For each conflict the updater lists, under `.template-update-candidates/<version>/`:

- `local`: the project's file (unchanged by the updater)
- `base`: `<candidate>.base`, the central version previously installed (when available)
- `incoming`: `<candidate>.incoming`, the new central version

1. Show the differences (`git diff --no-index <base> <incoming>` for what changed centrally, and
   `git diff --no-index <base> <local>` for the project's customization).
2. Propose a merged version that keeps the project's intentional customizations and adopts the
   central improvements; `git merge-file -p <local> <base> <incoming>` gives a starting point.
   Customizations must not weaken mandatory security, clean-code or responsive requirements.
3. With approval, write the merged content to the local file. If the customization is intentional
   and long-lived, record it under "Template deviations" in `CLAUDE.md`.
4. Re-run the updater. A file whose content now equals the incoming version is recorded as current;
   a still-customized file stays a recorded conflict, which is expected for permanent deviations.

Scaffold references (`OfferReference`) are optional reading: compare them with the project's own
documents and adopt useful improvements manually.

Deprecated files are never deleted automatically. Follow the changelog's migration notes and ask
before deleting any.

## Step 6 - Verify and hand off

1. Run the project's tests and checks.
2. Review the diff of the update branch with the user.
3. Leave `.template-update-candidates/` and `.template-update-backups/` out of commits (suggest
   adding them to `.gitignore`); they can be removed by the user after the update is merged.
4. Commit and open a pull request only with approval (see `eng-prepare-pr`).
5. Update `docs/engineering/CURRENT_STATE.md`.

## Acceptance criteria

- [ ] Installed and target versions identified; changelog reviewed
- [ ] Working tree clean; update on a dedicated branch
- [ ] Preview shown before applying; apply approved by the user
- [ ] Every conflict reconciled or deliberately kept and documented
- [ ] No project-owned file overwritten; deprecated files handled per changelog with approval
- [ ] Project tests run with actual results reported
