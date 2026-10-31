# claude-engineering-template

A central, versioned, tested source of Claude Code engineering standards: shared rules, agents,
skills and standards that you install into independent projects as copies, customize per project,
and update deliberately without overwriting project-specific work.

**One central repository -> tested, versioned releases -> independent project copies ->
project-specific customization -> controlled updates.**

Projects never depend on this repository at runtime. Once installed, each project works on its own,
even if this repository is unavailable.

## Who it is for

Engineers and teams using Claude Code on several applications who want the same security-first,
clean-code, responsive-design and testing discipline everywhere, without forcing every project into
the same stack or architecture.

## What a project receives

| Installed to | Ownership | What it is |
|---|---|---|
| `.claude/rules/eng-*.md` | Template-managed | 9 focused rules: core principles, clean code, security, database security and RLS, backend quality, testing, workflow and continuity, responsive design (UI files), frontend quality (UI files) |
| `.claude/engineering-standards/*.md` | Template-managed | 8 detailed standards the rules point to, read on demand |
| `.claude/agents/eng-*.md` | Template-managed | 9 agents: architect and 4 read-only reviewers (Opus, high effort); frontend, backend, database and QA engineers (Sonnet) |
| `.claude/skills/eng-*/SKILL.md` | Template-managed | 7 skills: project bootstrap, resume, security audit, responsive audit, frontend design, prepare PR, template update |
| `CLAUDE.md`, `docs/engineering/*.md` | Project-owned | Root instructions and 9 project documents (requirements, stack, architecture, security, plan, design system, testing, deployment, current state), created only if missing |
| `docs/engineering/template-examples/` | Project-owned, opt-in | Recommended settings, a guard hook, customization samples (inactive) |
| `.claude/engineering-template.lock.json` | Tool-owned | Installed version, file ownership and SHA-256 hashes |

The template never writes `.claude/settings.json`, `.claude/settings.local.json`, hooks, MCP
configuration or application code, and never deletes files.

## Repository structure

```text
claude-engineering-template/
├── README.md  CLAUDE.md  VERSION  CHANGELOG.md  TEMPLATE_MANIFEST.json
├── CONTRIBUTING.md  SECURITY.md  LICENSE  .gitignore  .gitattributes  .editorconfig
├── .claude/                     maintainer agent and validation skill for THIS repository
├── .github/                     CODEOWNERS, pull request template, CI workflow, Dependabot
├── docs/                        how this system works (not distributed)
├── distribution/                everything that ships, and only that
│   ├── managed/.claude/         rules, agents, skills, engineering-standards
│   ├── scaffold/                CLAUDE.md and docs/engineering/ templates
│   └── examples/                opt-in settings, hook and customization examples
├── scripts/                     Install-, Update-, Test-EngineeringTemplate.ps1, New-EngineeringTemplateRelease.ps1
│   └── lib/Template.Core.psm1   all install and update logic
└── tests/                       manifest, installation, update, isolation and content-format suites
```

See [docs/PURPOSE_AND_ARCHITECTURE.md](docs/PURPOSE_AND_ARCHITECTURE.md) for the design and its
trade-offs.

## Prerequisites

- Windows PowerShell 5.1 (built into Windows 10 and 11) or PowerShell 7+ (Windows, macOS, Linux)
- Git (recommended; enables release tags, three-way conflict bases and source revisions)
- Claude Code 2.1.309 or later in the projects that use the installed files

No PowerShell modules, package managers, plugins or network access are required.

## Install into a project

```powershell
git clone https://github.com/ramilrana/claude-engineering-template.git C:\Tools\claude-engineering-template
cd C:\Tools\claude-engineering-template
git checkout v1.0.0

# Preview, then install
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Install-EngineeringTemplate.ps1 -ProjectRoot C:\Projects\my-app -WhatIf
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Install-EngineeringTemplate.ps1 -ProjectRoot C:\Projects\my-app
```

Run it on a dedicated branch in the project and review the result like any other change. Then open
the project in Claude Code and run the `/eng-project-bootstrap` skill. Full guide:
[docs/INSTALLATION_WINDOWS.md](docs/INSTALLATION_WINDOWS.md).

Options: `-IncludeExamples` copies the inactive examples; `-Exclude <path>[,<path>]` opts out of
specific managed files. Exit codes: `0` success, `1` failure with nothing changed, `2` completed
with conflicts to review.

## Update a project

```powershell
cd C:\Tools\claude-engineering-template
git fetch --tags
git checkout v1.1.0
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Update-EngineeringTemplate.ps1 -ProjectRoot C:\Projects\my-app -WhatIf
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Update-EngineeringTemplate.ps1 -ProjectRoot C:\Projects\my-app
```

| Situation | Action |
|---|---|
| Managed file missing | Installed |
| Identical to incoming | Skipped |
| Unchanged since last install | Backed up, then replaced |
| Modified locally | Kept; incoming version saved to `.template-update-candidates/<version>/` |
| Removed from the new manifest | Marked deprecated; never deleted |
| Project-owned file | Kept; a changed template is saved for reference |
| Invalid or ambiguous lock or ownership | Stops before writing anything |
| Any write fails | All changes rolled back; lock file unchanged |

In the project, the `/eng-template-update` skill guides the update and the three-way reconciliation
of conflicts. Details: [docs/DISTRIBUTION_AND_VERSIONING.md](docs/DISTRIBUTION_AND_VERSIONING.md).

## Versioning

`VERSION` is authoritative; releases are Git tags such as `v1.0.0`; `CHANGELOG.md` records every
change and migration. Semantic versioning: PATCH for fixes, MINOR for backward-compatible
additions, MAJOR for breaking changes or required migrations. Projects choose when to update and may
stay on an older release indefinitely.

## Project customization

Projects own their `CLAUDE.md`, `docs/engineering/`, settings, hooks and any `project-*` rules,
agents and skills. Shared standards can be strengthened locally but must not be silently weakened;
intentional deviations are recorded in the project's `CLAUDE.md`. See
[docs/CUSTOMIZATION_POLICY.md](docs/CUSTOMIZATION_POLICY.md).

## Development and contribution

Work on a branch, keep `distribution/` and `TEMPLATE_MANIFEST.json` in sync, update
`CHANGELOG.md`, and open a pull request. See [CONTRIBUTING.md](CONTRIBUTING.md),
[docs/GITHUB_WORKFLOW.md](docs/GITHUB_WORKFLOW.md) and
[docs/AGENT_AND_MODEL_ROUTING.md](docs/AGENT_AND_MODEL_ROUTING.md).

## Testing

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-EngineeringTemplate.ps1
pwsh -NoProfile -File ./scripts/Test-EngineeringTemplate.ps1          # PowerShell 7, if installed
.\scripts\Test-EngineeringTemplate.ps1 -Name Updates,ProjectIsolation  # selected suites
```

Six suites run in isolated temporary directories: `Manifest`, `Installation`, `Updates`,
`ProjectIsolation`, `ContentFormats`, and `Acceptance`, an end-to-end scenario that installs the
real distribution into a realistic project, installs again, and updates to a newer release with one
unchanged and one customized file. CI runs them on Windows PowerShell 5.1 and on PowerShell 7
for Windows and Linux.

## Release process

Bump `VERSION` and date the `CHANGELOG.md` section in a pull request, merge, then on `main` run
`scripts/New-EngineeringTemplateRelease.ps1`. It checks the working tree, branch, version, changelog
and tests, then creates a local annotated tag. Pushing and publishing are manual and require
approval. See [docs/RELEASE_PROCESS.md](docs/RELEASE_PROCESS.md).

## More

- [Engineering standards](distribution/managed/.claude/engineering-standards/) (security, database
  security, clean code, responsive design, frontend, backend, testing, workflow)
- [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
- [SECURITY.md](SECURITY.md) - reporting vulnerabilities in this repository

Licensed under the [MIT License](LICENSE).
