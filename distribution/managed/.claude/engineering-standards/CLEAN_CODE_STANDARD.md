# Clean Code Standard

Part of the shared engineering template. The always-loaded summary is the `eng-clean-code` rule;
this document is the detailed reference. It applies to every language and framework in the project.

The objective is not the fewest lines of code. The objective is code that another competent
engineer can understand, debug, test, modify and extend with confidence.

## 1. Principles, applied with judgment

| Principle | Apply it as | Do not turn it into |
|---|---|---|
| Single responsibility / separation of concerns | One reason to change per module, function or component | One-line classes and files for every concept |
| DRY | One source of truth for each business rule | Coupling unrelated code because it looks similar |
| KISS | The simplest design that meets the requirement and can grow | Naive shortcuts that ignore real requirements |
| SOLID | Stable interfaces where variation is real | Interfaces and factories with one implementation |
| Composition over inheritance | Combine small behaviors | Deep hierarchies for code reuse |
| Explicit dependencies | Pass collaborators in; avoid hidden globals | Dependency-injection frameworks for small apps |
| High cohesion, low coupling | Related code together; narrow interfaces between modules | Arbitrary layering that splits a feature across many folders |
| Defensive programming / fail safe | Validate at boundaries; fail closed on security decisions | Re-validating the same data in every internal call |

Prefer the simplest implementation that correctly satisfies the requirement while remaining
extensible. Complexity must be justified by a present need, not by a hypothetical future.

## 2. Code organization

- Each module has a clear responsibility that its name communicates.
- Functions and methods do one thing at one level of abstraction. When a function needs a comment
  to separate its "sections", extract those sections.
- Large components, controllers, services and classes are split along responsibilities, not
  arbitrarily by line count.
- Business logic does not live in UI components, templates or route definitions.
- Shared validation, authorization and data-access rules are centralized and reused.
- Configuration is read in one place and passed in; business logic does not read environment
  variables directly.
- Follow the existing folder and naming conventions. Do not create files or directories only to
  satisfy a pattern from another project.
- No circular dependencies between modules.

## 3. Readability

- Names say what something is or does: `calculateInvoiceTotal`, `activeSubscriptions`,
  `isEligibleForRefund`. Avoid cryptic abbreviations and type-encoded names.
- Booleans read as predicates (`isVisible`, `hasAccess`, `canEdit`).
- Prefer guard clauses and early returns over nested conditionals. Replace complex conditions
  with well-named helper functions or variables.
- Avoid hidden side effects: a function named `getX` does not write data.
- Keep functions' parameter lists short; group related parameters into a typed object.
- Comments explain why: business rules, security decisions, non-obvious algorithms, workarounds
  with a link to the cause, and architectural constraints. Keep them accurate or delete them.
- Remove obsolete code, unused imports and variables, and commented-out code. Version control
  keeps history.

## 4. Reusability

- Reuse the project's existing utilities, hooks, components and services before writing new ones.
- Extract a shared abstraction when there are real, current duplicates of the same concept and
  the abstraction is simpler than the duplication (the "rule of three" is a useful default).
- Do not build generic frameworks, plugin systems or configuration-driven engines for behavior
  with a single simple use.
- Never duplicate a business rule. If two places need it, they call the same code.

## 5. Types and validation

- Use the project's type system fully. Model domain concepts with precise types (unions, enums,
  value objects) instead of loose strings and maps.
- TypeScript: avoid `any`; use `unknown` and narrow it. Do not use non-null assertions or casts to
  silence the compiler. Enable and respect strict compiler options the project uses.
- Dynamically typed languages: use type hints or schemas where the project supports them, and
  validate data shapes at boundaries.
- Validate all external input (HTTP requests, files, messages, environment, third-party API
  responses) at the trust boundary, using one validation approach per project.

## 6. Error handling

- Distinguish expected failures (validation, not found, conflict, permission denied) from
  unexpected ones, and handle each deliberately.
- Preserve the original error as the cause when wrapping, so debugging context is not lost.
- Never silently swallow exceptions. If ignoring an error is correct, explain why in a comment.
- Use the project's central error handling to map errors to user-facing responses. Do not
  duplicate inconsistent handling at every call site.
- User-facing messages are helpful and safe: no stack traces, SQL, file paths, secrets or tokens.
- Log failures once, at the layer that handles them, with structured context and without
  sensitive data.

## 7. Dependency management

Before adding a dependency:

1. Check whether existing code, the standard library or the platform already covers the need.
2. Evaluate maintenance activity, security history and known vulnerabilities.
3. Evaluate size, transitive dependencies and compatibility with the project's runtime.
4. Check the license when distribution or commercial use matters.
5. Avoid redundant libraries that overlap with ones already installed.
6. Get approval, then pin according to the project's convention and commit the lockfile.

Do not upgrade unrelated dependencies during ordinary feature work. Upgrade deliberately, in a
separate change, with the changelog reviewed and tests run.

## 8. Testability

- Keep pure logic separate from I/O so it can be unit tested without mocks.
- Inject external dependencies (clock, randomness, network, storage) where tests need control.
- Avoid global mutable state.
- If code is hard to test, treat that as design feedback.

## 9. Review checklist for substantial changes

- [ ] No duplicated business logic; existing utilities reused
- [ ] No unnecessary abstraction, layer, pattern or dependency
- [ ] Functions and components focused; control flow easy to follow
- [ ] Names clear and consistent with the project
- [ ] Concerns separated (UI, business logic, data access, configuration)
- [ ] Inputs validated at boundaries; types precise; no `any` or silenced errors
- [ ] Errors handled deliberately; nothing sensitive exposed or logged
- [ ] Authorization and security considered (see `SECURITY_STANDARD.md`)
- [ ] Tests added or updated and actually run
- [ ] Dead code, unused imports and stale comments removed
- [ ] Documentation and `docs/engineering/` updated where behavior or decisions changed
- [ ] Backward compatibility preserved or the break is documented and approved
