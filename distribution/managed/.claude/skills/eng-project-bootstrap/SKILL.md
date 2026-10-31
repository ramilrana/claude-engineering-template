---
name: eng-project-bootstrap
description: "Initialize engineering foundations for a new or existing project: discovery, lifecycle and scope classification, requirements, technology stack, architecture, security and data-isolation design, responsive design system, testing strategy, implementation plan and the docs/engineering documents."
when_to_use: "Use when starting a new project, adopting the engineering template in an existing codebase, beginning a migration or modernization, or preparing a security or architecture audit baseline."
argument-hint: "[short description of the project or goal]"
disable-model-invocation: true
---

# Project bootstrap

Establish a verified understanding of the project and an approved plan, recorded in
`docs/engineering/`, before substantial implementation begins. This skill writes documentation;
it does not implement features. Ask for approval at each marked checkpoint.

Goal or description from the user: $ARGUMENTS

## Step 1 - Inspect the workspace (no changes)

1. Confirm the project directory with the user if there is any doubt.
2. Run `git status` and `git branch --show-current`; note uncommitted work and do not disturb it.
3. List the top-level structure; read README, `CLAUDE.md`, package or build manifests, lockfiles,
   framework configuration, CI workflows, Docker or deployment files, test configuration, and any
   existing `docs/`.
4. Check `.claude/engineering-template.lock.json` for the installed template version.
5. Read the existing `docs/engineering/*.md` files; they may already contain approved decisions.

## Step 2 - Classify

Record lifecycle and scope separately (see `.claude/engineering-standards/ENGINEERING_WORKFLOW.md`
section 1):

- Lifecycle: new, existing with established standards, existing with only source structure,
  migration or modernization, legacy maintenance, security audit, architecture audit.
- Scope: frontend-only, backend-only, full-stack, monorepo, multiple repositories, static site,
  mobile, API service, library or SDK, documentation-only, other.

For an existing project, base everything on what the code shows. Never impose a stack from the
template.

## Step 3 - Technology stack (write `docs/engineering/TECH_STACK.md`)

Record verified facts with their evidence (file and version), and list unknowns separately:
frontend, backend, database and version, frameworks and versions, key dependencies,
authentication, integrations, build tools, test tools, deployment environment.

**Checkpoint:** show the classification and stack summary; ask the user to confirm or correct it.

## Step 4 - Requirements (write `docs/engineering/PROJECT_REQUIREMENTS.md`)

Clarify goals, scope, non-goals, stakeholders, users and roles, functional and non-functional
requirements, constraints and acceptance criteria. Use a brainstorming skill if one is installed;
otherwise ask focused questions, a few at a time. Skip what is already approved.

## Step 5 - Architecture and plan

For non-trivial projects, delegate analysis to the `eng-project-architect` agent with the verified
facts and requirements. Then draft:

- `docs/engineering/ARCHITECTURE.md`: components, data flow, data model and ownership, API
  boundaries, integrations, security boundaries, decisions with reasons.
- `docs/engineering/SECURITY.md`: threat model, roles, record ownership, the row-level isolation
  assessment (native RLS vs application-level, per
  `.claude/engineering-standards/DATABASE_SECURITY.md`), sensitive data, known risks.
- `docs/engineering/DESIGN_SYSTEM.md` for user-facing projects (run `eng-frontend-design`).
- `docs/engineering/TESTING.md`: strategy, commands, required security and responsive tests.
- `docs/engineering/DEPLOYMENT.md`: environments, configuration, migrations, rollback, backups.
- `docs/engineering/IMPLEMENTATION_PLAN.md`: milestones, numbered tasks with dependencies,
  acceptance criteria (including responsive and security criteria) and verification steps.

**Checkpoint:** present the architecture, security design and plan; get approval before treating
them as approved. Mark unapproved sections as "Proposed".

## Step 6 - Project instructions and state

1. Update the project's root `CLAUDE.md`: purpose, commands (install, run, test, lint, build),
   key paths, project-specific rules and any intentional template deviations. Keep it concise.
2. Fill `docs/engineering/CURRENT_STATE.md` with the phase, branch, last verified commit,
   working-tree status, completed and next tasks.
3. Suggest project-specific rules (`.claude/rules/project-*.md`) only where the project needs
   stricter or more specific guidance.

## Acceptance criteria

- [ ] Lifecycle and scope classified and confirmed by the user
- [ ] Stack facts verified from files, unknowns listed
- [ ] Requirements and acceptance criteria recorded
- [ ] Architecture, security (including isolation assessment), testing and deployment documented
- [ ] Design system defined for user-facing projects, with responsive behavior
- [ ] Implementation plan with small tasks, acceptance criteria and verification steps
- [ ] `CLAUDE.md` and `CURRENT_STATE.md` updated; nothing claimed as done that was only planned
- [ ] No application code changed, nothing committed or pushed without the user's request
