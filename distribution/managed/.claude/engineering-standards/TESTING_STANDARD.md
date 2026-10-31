# Testing and Verification Standard

Part of the shared engineering template. The always-loaded summary is the
`eng-testing-verification` rule. The project's test commands, strategy and known gaps live in
`docs/engineering/TESTING.md`.

## 1. Principles

- Tests verify behavior users and other systems depend on, not implementation details.
- Use the project's existing frameworks and conventions. Adding a test framework or tool needs
  approval.
- Fast, deterministic and isolated: no dependence on test order, wall-clock time, network or shared
  state unless the test is explicitly an integration or end-to-end test.
- A claim that something works is backed by a test run or a manual check that was actually
  performed, reported with the command and result.

## 2. Test types

| Type | Purpose | Typical scope |
|---|---|---|
| Unit | Business rules, pure functions, edge cases | One function or module, no I/O |
| Integration | Modules working together with real infrastructure | Endpoint + database, service + queue |
| End-to-end | Critical user journeys through the real UI | Browser automation against a running app |
| Regression | A bug never returns | Test written to reproduce the bug before the fix |
| Security | Authorization, validation, injection, isolation | Denied-path tests, isolation matrix |
| Responsive and accessibility | Layout and access across widths and inputs | Browser checks at representative widths, automated a11y scans |
| Contract | API compatibility between services or clients | Schema or consumer-driven contract tests |

Choose the cheapest test that gives confidence; keep end-to-end tests for critical journeys.

## 3. What to test for each change

- The happy path and the most important edge cases (empty, boundary, maximum, invalid).
- Validation failures and error handling.
- Authorization: an allowed case and at least one denied case for every protected operation.
- Isolation for restricted data (see `DATABASE_SECURITY.md`, section 9).
- For bug fixes: a failing test that reproduces the bug first.
- For frontend changes: component states and responsive behavior (see
  `RESPONSIVE_DESIGN_STANDARD.md`, section 6).

## 4. Test-driven development

Use TDD where it adds value, especially for business rules and bug fixes:

1. Write a test that fails for the right reason.
2. Write the simplest code that makes it pass.
3. Refactor while keeping tests green.

## 5. Test data and environments

- Use factories or fixtures that create only what each test needs.
- Never use production data or real personal data in tests. Anonymize when realistic data is needed.
- Integration tests use disposable databases (containers, transactions rolled back, or dedicated
  test schemas).
- Never run destructive tests against shared, staging or production environments.

## 6. Quality of tests

- One behavior per test with a descriptive name ("rejects export when the user lacks permission").
- Arrange, act, assert structure; clear failure messages.
- Mock only external boundaries; do not mock the code under test.
- No sleeps for synchronization; wait on conditions.
- Flaky tests are fixed or quarantined with an issue, never ignored silently.

## 7. Coverage

Coverage is a signal, not a goal. Prioritize business rules, authorization, data integrity and
critical journeys. Report coverage only when it was measured.

## 8. Reporting results

Report:

- The exact commands run.
- Pass, fail and skip counts.
- Failures with the relevant output.
- What was not tested or could not be run, and why.

Never edit tests to make them pass without explaining why the test was wrong, never delete or skip
failing tests to get a green run, and never claim tests pass without running them.

## 9. Continuous integration

- The main branch's CI runs the automated test suites on every pull request, plus linting and type
  checks where the stack has them.
- CI failures block merging.
- Test commands in `docs/engineering/TESTING.md` match what CI runs.
