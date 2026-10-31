# Clean, maintainable code (shared template rule)

Code must be easy for another competent engineer to understand, debug, test, change and extend.
The goal is clarity, not the fewest lines. Full guidance:
`.claude/engineering-standards/CLEAN_CODE_STANDARD.md`.

## Write code that

- Uses clear, descriptive names that match the project's existing naming conventions.
- Keeps functions, components, controllers and classes small and focused on one responsibility.
- Keeps business logic out of UI components and route definitions; keeps configuration out of logic.
- Uses straightforward control flow: early returns and guard clauses instead of deep nesting.
- Uses the project's type system properly. In TypeScript avoid `any`; never weaken types just to
  silence the compiler.
- Validates external input at trust boundaries and never assumes client data is trustworthy.
- Handles expected failures deliberately, preserves useful error context, never silently swallows
  exceptions, and never exposes internal details or secrets in user-facing errors.
- Centralizes shared validation, authorization and data-access rules instead of scattering them.
- Explains non-obvious business rules, security decisions and constraints in brief comments.

## Avoid

- Abstractions, generic frameworks or design patterns introduced for a single simple use.
- Duplicated business rules; reuse the project's existing utilities and components first.
- Dead code, unused imports and variables, commented-out code and stale comments.
- Magic values without a named constant or explanation.
- Circular dependencies and hidden side effects.
- New dependencies when existing code or the platform is sufficient. Before adding one, check
  maintenance, security, size, compatibility and license, and get approval.
- Upgrading unrelated dependencies during feature work.
- Comments that only restate what the code already says.

## Before finishing a substantial change, review it for

Duplication, unnecessary abstraction, complexity, naming, separation of concerns, security,
testability, dependency impact, documentation and backward compatibility. Fix what you find or
report it explicitly.
