# Security

<!--
Owned by this project. Records this project's security design and decisions. The shared
requirements are in .claude/engineering-standards/SECURITY_STANDARD.md and DATABASE_SECURITY.md.
Do not put secrets in this file.
-->

## Threat model

| Asset | Threat | Likelihood | Impact | Mitigation | Status |
|---|---|---|---|---|---|
| | | | | | |

## Authentication

<!-- Mechanism, password hashing, sessions or tokens, expiry and refresh, reset and recovery, MFA. -->

## Authorization

<!-- Model (RBAC / ABAC), where checks are enforced, how object-level ownership is verified. -->

## Roles

| Role | Can read | Can create / update | Can delete | Administrative rights |
|---|---|---|---|---|
| | | | | |

## Record ownership

| Entity | Owned by | Ownership column / relation | Sharing rules |
|---|---|---|---|
| | | | |

## Row-level isolation assessment

| Question | Answer |
|---|---|
| Restricted data present? | <!-- yes / no; which entities --> |
| Isolation boundaries | <!-- user / team / department / organization / tenant --> |
| Database engine and version | |
| Native RLS available? | <!-- e.g. PostgreSQL yes; MySQL no --> |
| Enforcement chosen | <!-- native RLS + application authorization / application authorization only --> |
| Reason | |
| Security context mechanism | <!-- e.g. SET LOCAL app.tenant_id per transaction --> |
| Runtime database role | <!-- privileges; confirms no superuser, BYPASSRLS or table ownership --> |
| Isolation tests | <!-- where they live and what they cover --> |

## Sensitive data

| Data | Classification | Storage | Protection | Retention |
|---|---|---|---|---|
| | | | | |

## API protection

<!-- Validation, rate limits, CORS, CSRF, security headers, request size limits. -->

## Infrastructure security

<!-- TLS, secret management and rotation, database network access, containers, CI/CD credentials, backups, monitoring. -->

## Security tests

<!-- Authorization, isolation, validation and other security tests, and how to run them. -->

## Known risks and exceptions

| Risk | Severity | Owner | Mitigation / exception approval | Review date |
|---|---|---|---|---|
| | | | | |
