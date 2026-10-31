---
name: eng-security-audit
description: "Structured security assessment of the project or a scope within it, covering authentication, authorization, row-level data isolation, database, API, input handling, files, secrets, dependencies, frontend, infrastructure and deployment, with severity-rated, evidence-based findings."
when_to_use: "Use when the user asks for a security audit, review or assessment, before a production release, or after changes to authentication, authorization, data access, file handling or secrets."
argument-hint: "[scope, e.g. whole project, a module, a pull request]"
---

# Security audit

Produce an evidence-based security assessment. Report findings; do not change code unless the user
asks for fixes afterwards. Never claim the application is secure or that the audit passed without
evidence.

Scope: $ARGUMENTS (if empty, ask whether to audit the whole project or a specific area)

## Step 1 - Prepare

1. Read `docs/engineering/SECURITY.md`, `docs/engineering/ARCHITECTURE.md` and
   `docs/engineering/TECH_STACK.md`. Note the threat model, roles, data classification and
   isolation design. If they are missing, record that as a finding.
2. Identify the stack, database engine and version, authentication mechanism and deployment target
   from the code.
3. Map the attack surface: entry points (routes, APIs, webhooks, jobs, CLI), trust boundaries,
   data stores, privileged operations, third-party integrations.

## Step 2 - Collect evidence (non-destructive commands only)

Local, read-only:

- `git ls-files` for committed secrets candidates (`.env`, keys, dumps); search for hard-coded
  credentials, tokens and private keys.

Contacting external services (ask the user before running):

- The package manager's audit command, if one exists (for example `npm audit`, `pnpm audit`,
  `pip-audit`, `composer audit`, `bundle audit`, `dotnet list package --vulnerable`). These send
  the dependency list to an advisory service.

Local, read-only:
- Read framework security configuration: CORS, CSRF, cookies, headers, session and token settings.
- Read CI workflows for permissions, secrets usage and unpinned actions.

## Step 3 - Assess

Work through `.claude/engineering-standards/SECURITY_STANDARD.md` and
`.claude/engineering-standards/DATABASE_SECURITY.md`:

| Area | Key questions |
|---|---|
| Authentication | Hashing, sessions and tokens, login, logout, refresh, reset, recovery, MFA |
| Authorization | Server-side on every operation including list, search, export, bulk and jobs; object-level ownership; escalation |
| Data isolation | Native RLS vs application-level authorization, named correctly; policies, roles, pooling context; isolation tests present |
| Input and injection | Validation at boundaries, parameterized queries, XSS, SSRF, path traversal, mass assignment |
| Web protections | CSRF, CORS, headers, cookies, rate limits |
| Files | Upload validation and storage, download authorization |
| Secrets and config | Committed or logged secrets, debug settings, defaults |
| Dependencies and CI | Vulnerable packages, supply chain, CI permissions |
| Errors and logging | Leakage, audit logs, sensitive data in logs |
| Concurrency | Races, webhook replay, idempotency |
| Infrastructure | TLS, database exposure, containers, backups, monitoring |

For a deep independent pass on high-risk areas, delegate to the `eng-security-reviewer` agent and
give it the relevant files and the evidence collected in Step 2.

## Step 4 - Report

Present findings ordered by severity, each with: severity, description, evidence (path:line or
reproduction), affected component, impact, exploitability, recommended fix and verification steps.
Include an isolation assessment and a list of what was not reviewed. Ask whether to save the report
(for example under `docs/engineering/security-audits/<date>.md`) and whether to update
`docs/engineering/SECURITY.md` known risks.

## Acceptance criteria

- [ ] Scope and attack surface stated
- [ ] Every area in the table assessed or explicitly marked out of scope
- [ ] Findings have severity, evidence, impact, fix and verification
- [ ] Native RLS and application-level authorization distinguished correctly
- [ ] Commands run are listed with their results; nothing destructive was executed
- [ ] Critical and High findings flagged as release blockers
- [ ] Limitations and unreviewed areas stated
