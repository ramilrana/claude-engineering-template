# Changelog

All notable changes to the central engineering template are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html):

- **MAJOR** - breaking changes or a required migration (for example a managed file changes
  ownership, a lock or manifest schema changes, or a rule is removed);
- **MINOR** - backward-compatible additions (new rules, agents, skills, standards or scaffold files);
- **PATCH** - backward-compatible fixes and clarifications.

Each release lists Added, Changed, Deprecated, Removed, Fixed and Security sections as needed.
Releases with deprecated or removed files, ownership changes or breaking changes include a
**Migration** section that projects follow when updating.

## [Unreleased]

### Added

- `tests/Test-Acceptance.ps1`: an end-to-end acceptance suite that installs the real distribution
  into a realistic project, verifies that project-owned files stay byte-identical, installs again,
  and updates to a newer release with one unchanged and one project-modified managed file. CI now
  runs it on Windows PowerShell 5.1 and on PowerShell 7 for Windows and Linux. Repository tooling
  only; nothing distributed to projects changes.

## [1.0.0] - 2026-10-31

First stable release.

### Added

- Distribution manifest (`TEMPLATE_MANIFEST.json`, schema version 1) with managed, project and
  example ownership classes and a code-enforced destination policy.
- Installer (`scripts/Install-EngineeringTemplate.ps1`) and updater
  (`scripts/Update-EngineeringTemplate.ps1`) with dry-run (`-WhatIf`), SHA-256 ownership tracking,
  conflict candidates outside active Claude Code directories, backups, transactional rollback,
  exclusions and downgrade protection.
- Project lock file `.claude/engineering-template.lock.json` (lock schema version 1).
- Shared rules: core principles, clean code, security, database security, backend quality,
  testing and verification, workflow and continuity, responsive design, frontend quality.
- Detailed standards in `.claude/engineering-standards/`: clean code, security, database security,
  responsive design, frontend quality, backend quality, testing, engineering workflow.
- Agents: `eng-project-architect`, `eng-architecture-reviewer`, `eng-security-reviewer`,
  `eng-frontend-engineer`, `eng-backend-engineer`, `eng-database-engineer`, `eng-qa-engineer`,
  `eng-release-reviewer`, `eng-frontend-design-reviewer`.
- Skills: `eng-project-bootstrap`, `eng-project-resume`, `eng-security-audit`,
  `eng-responsive-audit`, `eng-frontend-design`, `eng-prepare-pr`, `eng-template-update`.
- Project scaffold: root `CLAUDE.md` and nine `docs/engineering/` documents.
- Examples: recommended settings, a destructive-command guard hook, project rule and agent samples.
- Test suites, release script and GitHub Actions validation on Windows PowerShell 5.1,
  PowerShell 7 on Windows and PowerShell 7 on Linux.
