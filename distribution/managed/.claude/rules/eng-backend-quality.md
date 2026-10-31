# Backend quality (shared template rule)

Use the project's actual framework, language and database. Full guidance:
`.claude/engineering-standards/BACKEND_QUALITY.md`.

## Structure

- Keep clear module boundaries. Route handlers and controllers parse input, call application logic
  and shape responses; business rules live in focused services or domain modules; data access is
  isolated where that separation already exists or clearly helps.
- Do not add a generic service or repository layer for every operation without a demonstrated
  benefit. Match the existing architecture.
- Apply authentication and authorization through the project's central mechanism (middleware,
  policies, guards) and check resource ownership in the operation itself.

## Behavior

- Validate request input centrally with the project's validation approach; reject unknown fields
  for writes.
- Return consistent response and error shapes. Map internal errors to safe client messages and
  correct status codes.
- Use transactions with correct boundaries for multi-step writes. Make retried operations and
  webhooks idempotent where duplicates are possible.
- Use structured logging with request or correlation identifiers. Never log secrets, tokens,
  passwords or unnecessary personal data.
- Read configuration from the environment through one typed or validated configuration module.
  Fail fast on missing required configuration.
- Manage connection pools, timeouts and retries deliberately for every external call.

## Verification

Add or update tests for business rules, authorization (allowed and denied cases), validation
failures and error paths. Run the relevant tests and report the actual results.
