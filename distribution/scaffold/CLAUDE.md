# Project instructions for Claude Code

<!--
This file belongs to this project. The engineering template created it once and will never
overwrite it. Keep it concise: essential context and commands only. Detailed engineering rules are
in .claude/rules/ (shared template rules, prefixed eng-) and the full standards are in
.claude/engineering-standards/. Run the eng-project-bootstrap skill to fill this in.
-->

## Project

- **Name:** <!-- project name -->
- **Purpose:** <!-- one or two sentences: what it does and for whom -->
- **Lifecycle / scope:** <!-- e.g. existing full-stack application; see docs/engineering/TECH_STACK.md -->

## Commands

<!-- Replace with the project's real commands. Claude uses these to build and verify work. -->

| Task | Command |
|---|---|
| Install dependencies | `...` |
| Run locally | `...` |
| Test | `...` |
| Lint / format | `...` |
| Type-check | `...` |
| Build | `...` |

## Key paths

<!-- e.g. src/api/ - HTTP handlers; src/domain/ - business rules; migrations/ - database migrations -->

## Engineering documents

| Document | Purpose |
|---|---|
| `docs/engineering/CURRENT_STATE.md` | Current implementation snapshot (imported below) |
| `docs/engineering/IMPLEMENTATION_PLAN.md` | Approved milestones and tasks |
| `docs/engineering/PROJECT_REQUIREMENTS.md` | Goals, scope and acceptance criteria |
| `docs/engineering/TECH_STACK.md` | Verified technologies and versions |
| `docs/engineering/ARCHITECTURE.md` | Architecture and decisions |
| `docs/engineering/SECURITY.md` | Threat model, roles, isolation assessment |
| `docs/engineering/DESIGN_SYSTEM.md` | Visual direction, tokens, components, responsive rules |
| `docs/engineering/TESTING.md` | Test strategy, commands and gaps |
| `docs/engineering/DEPLOYMENT.md` | Environments, deployment, rollback, backups |

## Session start

Follow the `eng-workflow-continuity` rule: check `git status` and the branch, read the current
state below and the relevant part of the implementation plan, verify against the code, then
continue with the next unfinished task. The `eng-project-resume` skill does this.

## Project-specific rules

<!--
Rules that apply only to this project. They may strengthen the shared standards. Put larger or
path-specific rules in .claude/rules/project-*.md. Name local agents and skills with a project-
prefix; the eng- prefix is reserved for template-managed files.
-->

## Template deviations

<!--
Record every intentional deviation from the shared engineering template here: which file or rule,
what differs, why, and who approved it. Deviations must not silently weaken security, clean-code or
responsive-design requirements.
-->

None.

## Current state

@docs/engineering/CURRENT_STATE.md
