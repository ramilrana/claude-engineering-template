# Security first (shared template rule)

Treat application data and user information as high-value assets and the browser as untrusted.
Security is never traded for convenience. Full guidance:
`.claude/engineering-standards/SECURITY_STANDARD.md`.

## Non-negotiable

- **Server-side authorization on every operation.** List, read, create, update, delete, search,
  export, bulk operations and background jobs all check the caller's rights to the specific
  resource. Hidden buttons and frontend route guards are UX, never a security boundary.
- **Default deny and least privilege** for users, roles, services, database accounts, API keys,
  CI credentials and agents.
- **Validate input at every trust boundary**; encode output for its context (HTML, attribute,
  URL, SQL, shell). Use parameterized queries or the ORM's safe APIs; never build queries,
  commands or file paths by string concatenation with untrusted input.
- **Prevent mass assignment**: accept only explicitly allowed fields; never let clients set
  ownership, role, tenant or price fields.
- **Secrets** come from the environment or a secret manager, are never committed, logged or sent
  to the client, and can be rotated.
- **Errors and logs** never expose stack traces, SQL, secrets, tokens or personal data to users.
  Security-relevant events (login, permission changes, exports, admin actions) are audit-logged.

## Check every relevant change against

Injection (SQL, NoSQL, command), XSS, CSRF, SSRF, IDOR and broken object-level authorization,
privilege escalation, session and token handling, password reset and recovery, file upload and
download, path traversal, rate limiting and denial of service, CORS, security headers, dependency
and supply-chain risk, race conditions, and sensitive data exposure.

## Data isolation

Any application with user-, team-, department-, organization- or tenant-owned data needs a
documented row-level isolation design and tests. Follow `eng-database-security` and record the
assessment in `docs/engineering/SECURITY.md`.

## Reporting

Report findings with severity, evidence, affected files, impact, exploitability, fix and
verification steps. Never claim an application is secure or that an audit passed without
evidence. Critical and high-risk exploitable issues block release unless the user approves a
documented exception.
