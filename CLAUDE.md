# claude-engineering-template - maintainer instructions

This repository is the central, versioned source of reusable Claude Code engineering standards.
Projects receive tested copies of selected files through a manifest-driven installer and adopt new
versions deliberately through a safe updater. It is not an application and not a starter kit.

## Priorities

Security and data protection, then correctness, then clean maintainable code, then responsive and
accessible frontend quality, architecture, testing, documentation, and controlled distribution.
Changes here reach many projects: prefer small, backward-compatible, well-tested changes.

## Important paths

| Path | Purpose |
|---|---|
| `distribution/managed/.claude/` | Shared rules, agents, skills and standards (template-owned in projects) |
| `distribution/scaffold/` | Project `CLAUDE.md` and `docs/engineering/` templates (project-owned after install) |
| `distribution/examples/` | Opt-in, inactive examples (settings, hooks, customization) |
| `TEMPLATE_MANIFEST.json` | The only list of distributed files |
| `VERSION`, `CHANGELOG.md` | Authoritative version and release history |
| `scripts/lib/Template.Core.psm1` | All install/update logic |
| `tests/` | Test suites; run through `scripts/Test-EngineeringTemplate.ps1` |
| `docs/` | Documentation about this system (not distributed) |
| `.claude/` | Tools for maintaining this repository (not distributed) |

## Rules for changes

- Everything under `distribution/` must be in the manifest and nothing else may ship.
- Never weaken the installer's safety guarantees: path containment, link refusal, ownership,
  hash checks, no overwriting of project-owned or customized files, no deletion, rollback, and the
  lock file written last. Every behavior change needs a test.
- Scripts must run on Windows PowerShell 5.1 and PowerShell 7 and stay ASCII-only.
- Verify current official Claude Code documentation before changing agent, skill, rule or settings
  formats.
- Keep one source per standard; do not duplicate guidance across rules, standards, agents and skills.
- Stay technology-independent.
- Update `CHANGELOG.md` under `[Unreleased]` and the affected docs in the same change. Moving a
  destination or changing ownership is a MAJOR change with migration notes.

## Validation

Run `powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/Test-EngineeringTemplate.ps1`
(and with `pwsh` when available) and report the actual results. The `template-validation` skill
describes the full procedure.

## Release workflow

Branch, change, validate, pull request, review, merge to `main`, then bump `VERSION` and date the
`CHANGELOG.md` section in a release pull request, and run
`scripts/New-EngineeringTemplateRelease.ps1` on `main` to create the local tag. See
`docs/RELEASE_PROCESS.md`. Never push, tag remotely or publish without explicit approval.
