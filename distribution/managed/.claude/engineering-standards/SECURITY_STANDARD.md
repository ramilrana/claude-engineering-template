# Security Standard

Part of the shared engineering template. The always-loaded summary is the `eng-security` rule;
database and row-level isolation are covered in `DATABASE_SECURITY.md`. Project-specific decisions,
the threat model and known risks belong in `docs/engineering/SECURITY.md`.

Use the current OWASP Top 10, OWASP Cheat Sheet Series and the applicable OWASP ASVS level as
references. Check the current official documentation of the project's framework for its secure
defaults; do not rely on memory for security-relevant APIs.

## 1. Principles

Defense in depth, least privilege, default deny, server-side authorization, secure data access,
input validation, context-aware output encoding, secure secret management, appropriate encryption,
secure configuration, auditability, safe error handling and regular vulnerability assessment.
Treat the browser, mobile clients and any third-party callers as untrusted.

## 2. Authentication

| Concern | Requirement |
|---|---|
| Passwords | Hash with a current adaptive algorithm (Argon2id, scrypt or bcrypt) through a maintained library. Never store or log plaintext. Enforce length over composition rules; check against breached-password lists where feasible. |
| Sessions | Server-side or signed sessions with `HttpOnly`, `Secure` and an appropriate `SameSite` cookie. Rotate the session identifier on login and privilege change. Idle and absolute timeouts. |
| Tokens | Short-lived access tokens, validated signature, issuer, audience and expiry. Refresh tokens are rotated, revocable and stored securely. Never store tokens in `localStorage` when a cookie-based approach is possible. |
| Login | Generic failure messages, rate limiting and lockout or backoff, no user enumeration. |
| Logout | Invalidates the session or refresh token server-side. |
| Password reset and recovery | Single-use, short-lived, high-entropy tokens stored hashed; no account enumeration; notify the user; invalidate existing sessions after reset. |
| MFA | Offer or require it for administrative and high-risk accounts when appropriate. |

Prefer the framework's or a well-maintained identity provider's implementation over custom code.

## 3. Authorization

- Enforce authorization on the server for every operation: list, read, create, update, delete,
  search, export, import, bulk operations, file access, webhooks and background jobs.
- Check access to the specific resource (object-level authorization), not only the route or role.
  Every lookup by identifier verifies ownership or permission, preventing IDOR.
- Centralize policy decisions (policies, guards, middleware or a permission service) and call them
  consistently. Do not scatter ad-hoc role checks.
- Use RBAC by default; add attribute-based rules (ownership, tenant, department, state) where the
  domain needs them.
- Permission and role changes are themselves authorized, audited and cannot escalate the caller.
- Frontend checks (hidden buttons, route guards) are for usability only.
- Deny by default when a policy is missing or an error occurs.

## 4. Input, output and injection

- Validate type, length, format, range and allowed values at every trust boundary using an
  allow-list approach; reject unknown fields on writes to prevent mass assignment.
- SQL/NoSQL: parameterized queries or safe ORM APIs only. Never concatenate untrusted input into
  queries, including ORDER BY columns and operators - map them through allow-lists.
- OS commands: avoid shelling out; when unavoidable, pass arguments as an array, never through a shell.
- XSS: rely on the framework's automatic escaping; avoid raw HTML APIs (`innerHTML`,
  `dangerouslySetInnerHTML`, `v-html`, `|safe`); sanitize with a maintained sanitizer when rich
  text is required; set a Content Security Policy.
- CSRF: use the framework's CSRF protection for cookie-authenticated state-changing requests and
  `SameSite` cookies.
- SSRF: validate and allow-list outbound destinations for user-supplied URLs; block internal and
  metadata addresses; do not follow redirects blindly.
- Path traversal: never build file paths from user input; map identifiers to stored paths and
  verify the resolved path stays inside the intended directory.
- Deserialization: never deserialize untrusted data into executable object graphs.

## 5. Files

- Uploads: enforce size limits, validate content type by inspection (not only extension), generate
  server-side names, store outside the web root or in object storage, scan where the risk warrants
  it, and serve with `Content-Disposition` and correct content types.
- Downloads: authorize every request for the specific file; use short-lived signed URLs for object
  storage.

## 6. API and transport security

- HTTPS everywhere with HSTS in production.
- Security headers: Content-Security-Policy, `X-Content-Type-Options: nosniff`, frame protection
  (`frame-ancestors` or `X-Frame-Options`), `Referrer-Policy`, and `Permissions-Policy`.
- CORS: explicit allow-list of origins; never reflect arbitrary origins with credentials.
- Rate limiting and request size limits on authentication, search, export and other expensive or
  abusable endpoints; pagination limits on list endpoints.
- Consistent error format that never leaks internals.

## 7. Secrets and configuration

- Secrets come from environment variables or a secret manager, never from source code, committed
  `.env` files, client bundles or logs.
- Provide `.env.example` with names only. Keep `.env*` in `.gitignore`.
- Separate credentials per environment; rotate them and document the rotation procedure.
- Secure defaults: debug mode off in production, verbose errors off, default accounts removed.

## 8. Data protection

- Classify sensitive data (credentials, personal data, financial, health, tokens) in
  `docs/engineering/SECURITY.md`.
- Encrypt in transit always; encrypt at rest where the platform supports it and for sensitive fields
  when the risk warrants it.
- Minimize collection and retention; never return more fields than the client needs.
- Logs and analytics exclude secrets and unnecessary personal data.

## 9. Concurrency and abuse

- Protect check-then-act sequences (balances, inventory, unique claims) with transactions,
  locking or atomic operations.
- Make webhooks and retried operations idempotent; verify webhook signatures.
- Consider denial-of-service vectors: unbounded queries, regular expressions with catastrophic
  backtracking, large uploads, expensive exports.

## 10. Dependencies and supply chain

- Commit lockfiles; use the package manager's audit tool and the repository's dependency alerts.
- Prefer well-maintained packages; review new dependencies before adding them.
- Pin CI actions and build images to versions or digests; give CI the least privilege it needs.
- Never run install scripts or binaries from untrusted sources.

## 11. Logging and audit

- Audit-log authentication events, permission changes, administrative actions, exports and access
  to sensitive records, with actor, action, target and time.
- Protect logs from tampering and from unauthorized reading.

## 12. Infrastructure and deployment

Assess TLS configuration, secret handling and rotation, database network exposure (no public
database ports), file permissions, container images (minimal base, non-root user), CI/CD
credentials, backup protection and restore testing, disaster recovery, monitoring and alerting,
and dependency scanning. Never modify production data or run destructive production operations
without explicit approval and a reviewed recovery plan.

## 13. Security testing and reporting

- Include automated tests for authorization (allowed and denied), validation, and isolation.
- Review changes touching authentication, authorization, data access, files, payments or secrets
  with the `eng-security-reviewer` agent or the `eng-security-audit` skill.
- Report each finding as:

| Field | Content |
|---|---|
| Severity | Critical, High, Medium, Low or Informational, with rationale |
| Description | What is wrong |
| Evidence | File and line, request, or reproduction steps |
| Affected component | Module, endpoint, table |
| Impact | What an attacker could achieve |
| Exploitability | Preconditions and effort |
| Recommended fix | Specific change |
| Verification | How to confirm the fix |

- Never claim perfect security or a passed audit without evidence. Critical and high-risk
  exploitable issues must be fixed before production unless the user approves a documented,
  time-limited exception.
