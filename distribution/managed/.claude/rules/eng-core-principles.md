# Engineering principles (shared template rule)

These rules come from the central engineering template and apply to every task in this project.
Project-specific instructions in `CLAUDE.md` or `project-*` rules may strengthen them. They must not
silently weaken security, correctness, clean-code or responsive-design requirements; record any
intentional deviation in the "Template deviations" section of `CLAUDE.md`.

## Priority order

When requirements conflict, follow this order, explain the conflict, and recommend the safest
maintainable option:

1. Security and data protection
2. Correctness and reliability
3. Clean, readable, maintainable code
4. Responsive, accessible, professional frontend quality
5. Maintainable architecture and appropriate scalability
6. Testing and verification
7. Documentation and continuity
8. Controlled versioning and distribution

## Working rules

- Discover before changing: read the relevant code, configuration and `docs/engineering/` documents.
  Follow the project's actual conventions and technology instead of imposing new ones.
- Prefer the simplest implementation that correctly meets the requirement and remains extensible.
  Do not add layers, patterns, dependencies or files without a demonstrated need.
- Preserve existing behavior unless the task is to change it. Keep changes focused on the request.
- Never invent results. Do not state that code works, tests pass, security is verified or a
  deployment succeeded without evidence you produced in this session. Say what was not verified.
- Never report planned work as complete. Git history and the working tree are the source of truth.

## Actions that always need explicit approval

Ask the user first, every time, before:

- pushing, force-pushing, merging, tagging, publishing or deploying;
- `git reset --hard`, `git clean`, rewriting history or discarding uncommitted work;
- deleting files you did not create in this task;
- running migrations or any write against a shared, staging or production database;
- changing permissions, accounts, secrets, CI credentials or infrastructure;
- installing new dependencies, plugins, skills or MCP servers.

Never commit secrets, `.env` files, credentials, private keys or real customer data. Never print
secret values in output.

## Where the detailed standards live

Read the relevant standard when the task touches its area; do not load all of them by default.

| Area | Standard |
|---|---|
| Clean code | `.claude/engineering-standards/CLEAN_CODE_STANDARD.md` |
| Security | `.claude/engineering-standards/SECURITY_STANDARD.md` |
| Database security and RLS | `.claude/engineering-standards/DATABASE_SECURITY.md` |
| Responsive design and accessibility | `.claude/engineering-standards/RESPONSIVE_DESIGN_STANDARD.md` |
| Frontend design quality | `.claude/engineering-standards/FRONTEND_QUALITY.md` |
| Backend quality | `.claude/engineering-standards/BACKEND_QUALITY.md` |
| Testing and verification | `.claude/engineering-standards/TESTING_STANDARD.md` |
| Lifecycle, agents and Git workflow | `.claude/engineering-standards/ENGINEERING_WORKFLOW.md` |
