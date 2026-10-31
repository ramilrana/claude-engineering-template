# Workflow, Git safety and session continuity (shared template rule)

Full lifecycle, agent routing and Git workflow:
`.claude/engineering-standards/ENGINEERING_WORKFLOW.md`.

## Start of every session

1. Confirm you are in the correct project directory.
2. Inspect `git status` and the current branch. Never assume the working tree is clean.
3. Read `CLAUDE.md` and `docs/engineering/CURRENT_STATE.md`.
4. Read the relevant part of `docs/engineering/IMPLEMENTATION_PLAN.md`.
5. Check the actual code and recent Git history before trusting any summary.
6. Continue with the next unfinished task, or ask if the next step is unclear.

The `eng-project-resume` skill performs this procedure.

## Git discipline

- Never overwrite, discard or stash uncommitted work you did not create without approval.
- Work on a feature or fix branch, not directly on the main branch, unless the project says otherwise.
- Make small, logical commits with clear messages, and only when the user asks for commits.
- Inspect the diff before every commit. Never commit secrets, generated noise or unrelated changes.
- Never push, force-push, merge, tag, publish or deploy without explicit authorization.

## Keep the project continuable

- Update `docs/engineering/CURRENT_STATE.md` at meaningful milestones and before handing work to a
  new session: branch, last verified commit, completed and active tasks, tests actually run with
  results, known issues, risks and the next concrete actions. Keep it a snapshot, not a diary.
- Record approved architecture and security decisions in `docs/engineering/ARCHITECTURE.md` and
  `docs/engineering/SECURITY.md`; record the plan in `docs/engineering/IMPLEMENTATION_PLAN.md`.
- Do not repeat already-approved discovery or brainstorming without a material reason.

## Agents and models

- Do simple, well-scoped work directly. Use subagents only when specialization, independent
  review or context isolation adds real value.
- Planning and architecture: `eng-project-architect`. Implementation: `eng-frontend-engineer`,
  `eng-backend-engineer`, `eng-database-engineer`. Testing: `eng-qa-engineer`.
- Independent read-only review: `eng-architecture-reviewer`, `eng-security-reviewer`,
  `eng-frontend-design-reviewer`, `eng-release-reviewer`. Reviewers cannot run commands, so give
  them the diff, test output and screenshots or measurements they need.
- The main session coordinates, integrates results and remains responsible for verification.
