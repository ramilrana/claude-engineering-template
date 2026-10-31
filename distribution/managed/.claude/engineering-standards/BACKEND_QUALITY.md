# Backend Quality Standard

Part of the shared engineering template. The always-loaded summary is the `eng-backend-quality`
rule. Security requirements are in `SECURITY_STANDARD.md` and `DATABASE_SECURITY.md`.

This standard is technology-independent. Apply it through the project's actual framework,
language and database; follow existing conventions.

## 1. Module boundaries

- Organize by feature or domain when the project is large enough; keep each module's public
  surface small.
- Typical responsibilities:
  - **Transport** (routes, controllers, handlers, resolvers): parse and validate input,
    authenticate, call application logic, map results and errors to responses.
  - **Application or domain logic** (services, use cases, domain modules): business rules,
    authorization decisions on resources, orchestration, transactions.
  - **Data access** (ORM models, query modules, repositories): queries scoped to the caller,
    persistence details.
- Introduce a layer only when it has a clear job in this codebase. A small CRUD application does
  not need a repository and a service for every table.
- Integrations with external services sit behind a small adapter so they can be tested and replaced.

## 2. Validation

- Validate every request at the transport boundary with one schema approach per project.
- Use allow-lists for writable fields; reject or ignore unknown fields consistently.
- Domain invariants are also enforced in domain logic and, where possible, by database constraints.

## 3. API design

- Consistent resource naming, HTTP methods and status codes (or the project's RPC/GraphQL
  conventions).
- One response envelope and one error format across the API, including a machine-readable code,
  a safe message and a correlation identifier.
- Pagination, filtering and sorting with limits and allow-listed fields.
- Version or evolve APIs without breaking existing clients; document breaking changes.
- Document endpoints in the project's API documentation format when one exists.

## 4. Error handling

- Central error handler maps known errors to status codes and safe messages; unknown errors return
  a generic 500 and are logged with context.
- Do not catch and ignore errors; do not log the same error at every layer.
- Distinguish client errors (4xx) from server errors (5xx) consistently.

## 5. Data access and transactions

- Parameterized queries or safe ORM APIs.
- Define transaction boundaries in the application layer around a complete business operation.
- Avoid N+1 queries; select only needed columns; paginate large reads.
- Handle concurrency with optimistic locking, unique constraints or explicit locks where races
  matter.
- Manage connection pools: sized for the workload, with timeouts, released reliably.

## 6. Integrations and resilience

- Timeouts on every outbound call; retries only for idempotent operations, with backoff and jitter.
- Idempotency keys for payment-like or externally retried operations; verify webhook signatures.
- Background jobs are idempotent, authorized for the data they touch, observable and retry-safe.

## 7. Configuration

- One configuration module reads and validates environment variables at startup and fails fast.
- No secrets in source, logs or error messages; `.env.example` lists names only.
- Environment-specific behavior is driven by configuration, not by scattered environment checks.

## 8. Logging and observability

- Structured logs (key-value or JSON) with level, timestamp, correlation or request identifier,
  and relevant non-sensitive context.
- Never log passwords, tokens, secrets, full payment data or unnecessary personal data.
- Audit logs for security-relevant actions (see `SECURITY_STANDARD.md`).
- Health checks and metrics where the deployment platform uses them.

## 9. Testing

- Unit tests for business rules and edge cases.
- Integration tests for endpoints including authentication, authorization (allowed and denied),
  validation errors and database behavior, run against a real or containerized database where
  practical.
- Isolation tests for restricted data (see `DATABASE_SECURITY.md`).

## 10. Review checklist

- [ ] Responsibilities placed in the right layer; no unnecessary layers added
- [ ] Input validated; writable fields allow-listed
- [ ] Authorization checked for the specific resource on every operation
- [ ] Queries parameterized and scoped; transactions correct; no N+1
- [ ] Consistent responses and safe errors
- [ ] Timeouts, retries and idempotency where needed
- [ ] Configuration validated; no secrets in code or logs
- [ ] Tests for rules, authorization and errors run and passing
