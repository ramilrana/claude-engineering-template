# Engineering Workflow Standard

Part of the shared engineering template. The always-loaded summary is the
`eng-workflow-continuity` rule. This document defines the application lifecycle, agent and model
routing, context management and the Git workflow for projects that use the template.

## 1. Classify the project first

Keep lifecycle and scope separate; record both in `docs/engineering/TECH_STACK.md`.

| Lifecycle | Scope |
|---|---|
| New project | Frontend-only, static website |
| Existing project with established standards | Backend-only, API service |
| Existing project with only source structure | Full-stack application |
| Migration or modernization | Monorepo, or multiple independent repositories |
| Legacy maintenance | Mobile application |
| Security audit | Library or SDK |
| Architecture audit | Documentation-only, or another system |

Examples: "new frontend-only website", "existing backend with only source structure",
"legacy PHP application undergoing modernization", "SaaS system requiring tenant isolation".

## 2. Lifecycle

### Phase A - Discovery

Understand the purpose; classify lifecycle and scope; inspect the workspace, Git status, code,
configuration, dependencies, tests, CI and deployment files; review existing standards and
documents; identify risks and available tools. For existing projects, inspect before suggesting
anything. Record verified facts and unknowns separately.

### Phase B - Requirements and brainstorming

Clarify goals, users, scope and non-goals; explore alternatives and trade-offs; define acceptance
criteria; record approved decisions in `docs/engineering/PROJECT_REQUIREMENTS.md`. Use the
project's brainstorming tool if `CLAUDE.md` declares one (section 4); otherwise ask focused
questions directly. Do not repeat approved brainstorming without a material reason.

### Phase C - Architecture and planning

Define technology choices, structure, module and security boundaries, data model and isolation
approach, design system, testing strategy, deployment and milestones broken into small tasks with
acceptance criteria and verification steps. Record them in `ARCHITECTURE.md`, `SECURITY.md`,
`DESIGN_SYSTEM.md`, `TESTING.md`, `DEPLOYMENT.md` and `IMPLEMENTATION_PLAN.md` under
`docs/engineering/`. Get approval before major architecture changes.

### Phase D - Implementation

Follow the approved plan in small, reviewable changes; write clean code; use TDD where it helps;
preserve behavior; reuse existing components; avoid unnecessary dependencies; run targeted tests;
update documentation and `CURRENT_STATE.md`.

### Phase E - Independent review

Review architecture, security, clean-code quality, maintainability, responsive behavior,
accessibility, performance, acceptance criteria and test coverage with the read-only reviewers
where useful. Fix verified defects before preparing a pull request.

### Phase F - GitHub integration

Feature branch, logical commits, tests, diff inspection, pull request (`eng-prepare-pr`), required
reviews and CI, approval, then a merge performed or authorized by the user.

### Phase G - Deployment and continuation

Follow `docs/engineering/DEPLOYMENT.md`; verify deployed behavior and migrations; record changes,
outstanding issues and next steps in `CURRENT_STATE.md`. Never report an unverified deployment as
successful.

## 3. Agent and model routing

| Agent | Model | Can modify files | Use for |
|---|---|---|---|
| `eng-project-architect` | Opus, high effort | No | Requirements analysis, stack assessment, architecture and implementation plans |
| `eng-architecture-reviewer` | Opus, high effort | No | Independent architecture and maintainability review |
| `eng-security-reviewer` | Opus, high effort | No | Security and data-isolation review |
| `eng-frontend-design-reviewer` | Opus, high effort | No | Visual, responsive, accessibility and usability review |
| `eng-release-reviewer` | Opus, high effort | No | Release readiness of a change set |
| `eng-frontend-engineer` | Sonnet | Yes | UI implementation |
| `eng-backend-engineer` | Sonnet | Yes | API and business logic implementation |
| `eng-database-engineer` | Sonnet | Yes | Schema, migrations, queries, RLS policies |
| `eng-qa-engineer` | Sonnet | Yes (tests) | Test design, implementation and execution |

- Do simple, well-scoped tasks directly in the main session.
- Use a subagent when specialization, an independent opinion or context isolation is worth the cost.
- Reviewers have no shell or write tools by design. The main session runs commands and passes them
  the diff, test output, screenshots or measurements.
- Skills do not choose models; agents do. The main session integrates and verifies all results.

## 4. Workflow stages and project tools

The template works on its own: every stage below has a built-in default. A project may name its
own skill, plugin or agent for a stage in the "Workflow tools" section of its `CLAUDE.md`; that
tool then takes the place of the default for that stage. Stages the project does not list use the
default.

| Stage | Template default |
|---|---|
| Brainstorm | Focused questions in the main session (Phase B) |
| Plan | `eng-project-architect` agent |
| Design system | `eng-frontend-design` skill, recorded in `docs/engineering/DESIGN_SYSTEM.md` |
| Design references | References the user supplies, gathered in `eng-frontend-design` step 1 |
| Screen design and build | `eng-frontend-engineer` agent, following `docs/engineering/DESIGN_SYSTEM.md` |
| Design audit | `eng-responsive-audit` skill; `eng-frontend-design-reviewer` agent for an independent opinion |
| Polish | Fix the audit findings with `eng-frontend-engineer`, then audit again |
| Test | `eng-qa-engineer` agent |
| Browser verification | The project's browser-testing tooling (`RESPONSIVE_DESIGN_STANDARD.md` section 6) |
| Review | `eng-architecture-reviewer`, `eng-security-reviewer` and `eng-release-reviewer` agents |
| Pull request | `eng-prepare-pr` skill |

- Project tools are optional. The template never requires one. If a declared tool is missing or
  fails, use the default for that stage and say so.
- Use one tool per step. When a project chains tools (for example audit, then polish), run them as
  explicit, ordered steps; never run two tools for the same step.
- Project tools add capability, not exemptions. Their output meets the same security, clean-code,
  responsive, accessibility and testing standards, and the template's verification still applies.
- When a tool's own instructions conflict with the project's (mandatory steps, extra output
  sections, broader permissions, self-updates), the project's instructions win.
- Adopt a third-party tool only after the review in `SECURITY_STANDARD.md` section 10, pinned to a
  version or commit. Installing one always needs the user's approval.
- Use the stage names above for the stages they describe; add a stage of your own only when none
  fits.

An example `CLAUDE.md` section is installed with `-IncludeExamples` as
`docs/engineering/template-examples/workflow-tools.example.md`.

## 5. Context and continuity

| Location | Holds | Loaded |
|---|---|---|
| `CLAUDE.md` | Essential project context and commands | Every session |
| `.claude/rules/` | Focused engineering rules | Every session, or when matching files are touched |
| `.claude/agents/` | Specialist roles | When delegated to |
| `.claude/skills/` | Reusable workflows | When invoked |
| `.claude/engineering-standards/` | Detailed standards | When relevant |
| `docs/engineering/CURRENT_STATE.md` | Concise implementation snapshot | Every session (imported by `CLAUDE.md`) |
| `docs/engineering/IMPLEMENTATION_PLAN.md` | Approved tasks | When planning or continuing work |
| Other `docs/engineering/` files | Detailed project reference | When relevant |

Start each session with the checklist in `eng-workflow-continuity` (the `eng-project-resume`
skill). Do not rely on conversation history, summaries or `/compact` as the continuity system;
`/compact` is an optional context tool.

## 6. Git workflow for application projects

- Main branch is stable and protected; work on `feature/...`, `fix/...` or the project's branch
  naming convention.
- Logical commits with clear messages; commit only when the user asks.
- Inspect the diff before committing; never commit secrets or unrelated changes.
- Pull requests with CI, required reviews and CODEOWNERS where configured.
- Enable secret scanning and dependency alerts on the hosting platform.
- Never push directly to protected branches, force-push, merge, tag, publish or deploy without
  explicit authorization.

## 7. Adopting and updating the engineering template

- Template installation and updates happen on a dedicated branch and are reviewed like any change.
- Use the `eng-template-update` skill to review lock information, managed-file changes and
  customization conflicts before applying a newer version.
- Project customizations are preserved; conflicts are reconciled deliberately.
- Run the project's tests after adopting a new template version.
