# Testing and honest verification (shared template rule)

Full guidance: `.claude/engineering-standards/TESTING_STANDARD.md`. The project's commands and
current gaps are recorded in `docs/engineering/TESTING.md`.

## Verify actual behavior

- Use the project's existing test framework and conventions. Do not introduce a new framework
  without approval.
- Add or update tests together with the code they cover. Use test-driven development where it
  helps: write the failing test, implement, refactor.
- Test the important paths: normal behavior, edge cases, validation failures, error handling and
  authorization (both the allowed and the denied case).
- For bug fixes, first reproduce the bug with a test that fails, then fix it.
- For frontend work, verify responsive behavior at the required viewport widths in a real browser
  when tooling is available (see `eng-responsive-design`).
- Never test destructive behavior against real data, shared databases or production systems.

## Report results truthfully

- Run the relevant tests before claiming completion and report the exact commands and outcomes.
- If tests fail, say so and include the failure. If you could not run something, say what and why.
- Never edit a test merely to make it pass, skip or delete failing tests, or weaken assertions,
  unless the test itself is wrong and you explain why.
- Do not describe coverage, security or performance as verified unless you measured it.

A task is complete only when its acceptance criteria are verified, or when the remaining
unverified items are listed explicitly.
