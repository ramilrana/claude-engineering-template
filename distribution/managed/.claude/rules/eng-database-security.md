# Database security and row-level isolation (shared template rule)

Full guidance, including PostgreSQL policy patterns and the isolation test matrix:
`.claude/engineering-standards/DATABASE_SECURITY.md`.

## Know which protection you actually have

Always distinguish, in code reviews, documents and reports:

1. **Native database Row-Level Security** - enforced by the database itself (for example
   PostgreSQL `CREATE POLICY` with RLS enabled on the table).
2. **Application-level row authorization** - enforced by scoped queries, a central data-access
   layer and authorization checks in the application.

Never describe application-level filtering as RLS. Never assume a database supports native RLS:
check the actual engine and version. MySQL and MariaDB have no PostgreSQL-style row policies, so
isolation there is application-level authorization plus database privileges, views and constraints.
Native RLS is an additional boundary, never a replacement for backend authorization.

## When the project uses PostgreSQL RLS

- Enable RLS on every protected table and add `FORCE ROW LEVEL SECURITY` where the application
  role owns the table.
- Cover SELECT, INSERT, UPDATE and DELETE; use `USING` for visibility and `WITH CHECK` for writes,
  so users cannot insert or move rows into another owner's or tenant's scope.
- The application's runtime role must not be a superuser, the table owner (unless RLS is forced)
  or have `BYPASSRLS`. Migrations and administration use separate roles.
- Set the security context (user, tenant) per transaction, for example with `SET LOCAL` or
  `set_config(..., true)`, so pooled connections never leak another request's context.

## Always

- Use parameterized queries or safe ORM APIs; never interpolate untrusted input into SQL.
- Give the application database account only the privileges it needs. No DDL at runtime.
- Enforce integrity in the schema: foreign keys, NOT NULL, unique and check constraints.
- Use transactions for multi-step writes and choose isolation deliberately for race-prone flows.
- Write migrations that are reviewable and reversible where possible. Never run migrations or
  data changes against shared, staging or production databases without explicit approval and a
  recovery plan.
- Protect backups and dumps like production data. Never commit real data or dumps.

## Isolation tests are required

For restricted data, test that one user, team or tenant cannot read, update, delete, insert,
change ownership of, search, paginate, count, aggregate, export or bulk-modify another's rows,
including through background jobs.
