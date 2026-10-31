# Contributing

Changes here reach every project that adopts the template, so they are small, reviewed, tested and
documented.

## Workflow

1. Create a branch from `main`: `feature/<topic>`, `fix/<topic>` or `docs/<topic>`.
2. Make the change, following the conventions below.
3. Run the tests (see [Testing](#testing)) and fix failures at their cause.
4. Add an entry to `CHANGELOG.md` under `[Unreleased]`.
5. Open a pull request using the template; CI must pass and a code owner must approve.
6. Releases are cut separately; see [docs/RELEASE_PROCESS.md](docs/RELEASE_PROCESS.md).

Never push directly to `main`, force-push shared branches, or publish tags without approval.

## Adding, changing or removing distributed files

- Put distributed files under `distribution/` only and add a `TEMPLATE_MANIFEST.json` entry in the
  same change. `tests/Test-Manifest.ps1` fails if either side is missing.
- Allowed destinations are fixed in code (`$script:OwnershipPolicy` in
  `scripts/lib/Template.Core.psm1`). Widening them is a security-relevant change that needs explicit
  review.
- Managed names use the `eng-` prefix. Never reuse a removed name for something with a different
  purpose.
- Changing a destination path or ownership class, or removing a managed file, is a breaking change:
  bump MAJOR at release time and write migration notes in `CHANGELOG.md`.
- Removing a file from the manifest marks it deprecated in projects; it is never deleted for them.

## Content conventions

- **Rules** (`.claude/rules/eng-*.md`): short, imperative, checkable. Always-loaded rules have a
  shared line budget enforced by `tests/Test-ContentFormats.ps1`. Frontmatter may contain only
  `paths`.
- **Standards** (`.claude/engineering-standards/*.md`): the single detailed source for a topic.
  Rules, agents and skills reference them instead of copying them.
- **Agents**: valid frontmatter (`name`, `description`, explicit `tools`, `model` alias, `effort`
  where useful). Reviewers stay read-only through their `tools` list. Do not set `permissionMode`.
- **Skills**: one workflow each, with procedure and acceptance criteria; manual invocation
  (`disable-model-invocation: true`) for workflows with consequential side effects.
- **Technology independence**: requirements must not assume a framework, language or database;
  examples may name them.
- Verify current Claude Code documentation before changing any frontmatter or settings format.

## Script conventions

- Logic lives in `scripts/lib/Template.Core.psm1`; entry scripts only parse parameters and report.
- Compatible with Windows PowerShell 5.1 and PowerShell 7: no `??`, ternaries, `-AsHashtable`, or
  `Join-Path` with more than one child path. ASCII-only source files.
- Plan first, apply second. Never weaken path containment, link refusal, hash verification,
  rollback, or the rule that the lock file is written last.
- Every behavior change has a test that uses temporary directories only.

## Testing

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-EngineeringTemplate.ps1
pwsh -NoProfile -File ./scripts/Test-EngineeringTemplate.ps1
```

Paste the summary lines into the pull request. If PowerShell 7 is not available locally, rely on
the CI result and say so.

## Commit messages

Use the imperative mood and explain why: `Add isolation test for exports`, `Fix rollback of created
directories`. Keep unrelated changes in separate commits.
