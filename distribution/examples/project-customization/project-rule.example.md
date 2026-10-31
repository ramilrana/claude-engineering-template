---
paths:
  - "src/billing/**"
  - "migrations/**"
---

# Billing module rules (example project rule)

<!--
Example of a project-specific, path-scoped rule. It loads only when Claude works with files that
match the paths above. Copy to .claude/rules/project-billing.md and adapt; delete what does not
apply. It strengthens, and never weakens, the shared eng- rules.
-->

- Every billing record belongs to exactly one organization through `organization_id`; queries in
  `src/billing/` must go through `BillingRepository`, which applies the organization scope.
- Amounts are stored as integer minor units with an ISO 4217 currency code. Never use floating
  point for money.
- Invoice numbers are generated only by `InvoiceNumberService` inside the same transaction that
  creates the invoice.
- Every change to a billing record writes an audit entry with actor, action and previous values.
- Migrations touching billing tables need a reviewed backfill plan and a tested rollback before
  they are applied anywhere other than a local database.
- Tests for this module must include the cross-organization isolation cases from
  DATABASE_SECURITY.md section 9.
