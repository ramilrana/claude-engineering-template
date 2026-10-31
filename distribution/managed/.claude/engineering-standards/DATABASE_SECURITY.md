# Database Security Standard

Part of the shared engineering template. The always-loaded summary is the
`eng-database-security` rule. Record the project's assessment in `docs/engineering/SECURITY.md`
and its schema decisions in `docs/engineering/ARCHITECTURE.md`.

## 1. Two different protections

| | Native Row-Level Security | Application-level row authorization |
|---|---|---|
| Enforced by | The database engine, on every query | Application code: scoped queries, data-access layer, policies |
| Protects against | Application bugs that forget a filter, ad-hoc queries through the app role | Unauthorized access through the application's own APIs |
| Depends on | Correct policies, roles without bypass privileges, per-request security context | Every query path using the shared scoping code |
| Examples | PostgreSQL `ENABLE ROW LEVEL SECURITY` + `CREATE POLICY` | `WHERE tenant_id = :currentTenant` in a central repository, ORM global scopes, policy checks |

Native RLS is an additional boundary. Backend authorization is always required. Never label
application filtering as RLS in code, documentation or reports.

## 2. Mandatory isolation assessment

Required for any application with user-, team-, department-, campus-, organization-, tenant- or
otherwise restricted data. Document in `docs/engineering/SECURITY.md`:

1. Data ownership model: who owns each kind of record and through which column or relation.
2. Tenant and organizational boundaries, and any data-sharing exceptions.
3. Roles and what each may read and change.
4. Database engine and exact version, and which native capabilities exist.
5. Chosen enforcement: native RLS, application-level authorization, or both, with the reason.
6. How the security context reaches the database (if RLS is used).
7. The isolation tests that prove it.

## 3. PostgreSQL

Evaluate native RLS for multi-tenant or ownership-restricted tables.

- `ALTER TABLE ... ENABLE ROW LEVEL SECURITY;` on every protected table.
- `ALTER TABLE ... FORCE ROW LEVEL SECURITY;` when the application role owns the table; otherwise
  the owner bypasses policies.
- Create policies for each command that is allowed. With RLS enabled and no matching policy,
  access is denied (default deny).
  - `USING (...)` filters which existing rows are visible or affected (SELECT, UPDATE, DELETE).
  - `WITH CHECK (...)` validates new or changed rows (INSERT, UPDATE), preventing users from
    creating rows in, or moving rows to, another owner's or tenant's scope.
- Roles: the runtime application role must not be a superuser, must not have `BYPASSRLS`, and
  must not own the tables unless RLS is forced. Use a separate role for migrations.
- Security context: set it per transaction, for example
  `SELECT set_config('app.tenant_id', $1, true);` (transaction-local) or `SET LOCAL`, and read it in
  policies with `current_setting('app.tenant_id', true)`. Session-level settings leak across
  pooled connections; with transaction-pooling poolers such as PgBouncer, only transaction-local
  settings are safe. After a transaction-local setting ends, `current_setting(..., true)` can return
  an empty string rather than NULL on the same connection, so wrap it in `NULLIF(..., '')` before
  casting; a missing context then matches no rows instead of raising an error.
- Views run with the owner's privileges unless created with `security_invoker = true`
  (PostgreSQL 15+); check views and `SECURITY DEFINER` functions for bypasses.
- Test policies directly with the application role, not as a superuser.

Illustrative pattern (adapt names, types and roles to the project):

```sql
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE documents FORCE ROW LEVEL SECURITY;

CREATE POLICY documents_tenant_isolation ON documents
  USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid)
  WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid);
```

## 4. MySQL and MariaDB

There is no PostgreSQL-style `CREATE POLICY`. Check the actual version and capabilities, then:

- Enforce row access in the application through a central data-access layer or ORM scopes that
  every query path uses; forbid unscoped queries on restricted tables in review.
- Grant the application user only the privileges it needs on the tables it needs; no `SUPER`,
  `FILE`, DDL or administrative privileges at runtime.
- Use views with `SQL SECURITY` deliberately when they restrict columns or rows, and know whose
  privileges they run with.
- Use foreign keys and constraints to keep ownership columns consistent.
- Describe this honestly as application-level row authorization.

## 5. Other databases

Check current official documentation for the engine's access-control features (for example SQL
Server security policies and predicates, Oracle VPD, document-database rules, or cloud
database security rules), and apply the same assessment. Do not assume equivalence between engines.

## 6. General database security

- Parameterized queries or safe ORM APIs only; allow-list dynamic identifiers.
- Least-privilege accounts per purpose: runtime, migrations, read-only reporting, backups.
- No public network exposure; TLS for connections where supported; restrict by network policy.
- Constraints in the schema: primary and foreign keys, NOT NULL, unique and check constraints.
- Transactions with explicit boundaries for multi-step changes; deliberate isolation levels and
  locking for race-prone operations.
- Index for real query patterns; verify with the engine's query plan before and after.
- Sensitive columns identified, minimized, and encrypted or hashed where appropriate.
- Audit trails for sensitive changes where the domain requires them.

## 7. Migrations and data changes

- Migrations are versioned, reviewed, tested on a copy of realistic data, and reversible where
  possible. Destructive steps (dropping columns or tables, data rewrites) are split and planned.
- Never run migrations or manual data changes on shared, staging or production databases without
  explicit approval, a backup and a tested rollback or recovery plan.
- Long-running migrations consider locking and downtime.

## 8. Backups and recovery

- Backups are encrypted, access-controlled, retained per policy and restore-tested.
- Dumps are production data: never commit them, attach them to tickets or copy them to laptops
  without approval. Use anonymized data for development.

## 9. Required isolation tests

For each restricted resource, with at least two users, roles, departments or tenants (A and B),
verify that A cannot:

| Operation | Test |
|---|---|
| Read | Fetch B's record by ID (expect not found or forbidden, without revealing existence where required) |
| List and search | See B's records in lists, search results or filters |
| Pagination and counts | Infer B's records from totals, page counts or aggregates |
| Update | Modify B's record, including partial updates |
| Delete | Delete B's record |
| Insert | Create a record owned by B or in B's tenant |
| Ownership change | Change a record's owner or tenant to or from B |
| Export | Include B's data in exports or reports |
| Bulk operations | Affect B's records through bulk endpoints |
| Background jobs | Process B's data in jobs triggered by A |

When native RLS is used, also test directly against the database with the application role and
the security context set for A.
