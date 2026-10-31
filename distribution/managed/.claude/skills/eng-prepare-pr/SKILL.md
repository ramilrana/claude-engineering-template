---
name: eng-prepare-pr
description: "Prepare a pull request: review the branch diff, run tests, check security, responsive and documentation requirements, run an independent release review and draft the pull request summary. Never merges; pushes or opens the pull request only with explicit approval."
when_to_use: "Use when the user asks to prepare, open or get a pull request ready, or before requesting review of a branch."
argument-hint: "[base branch, default main]"
disable-model-invocation: true
---

# Prepare a pull request

Get the current branch ready for review with evidence for every claim. This workflow never merges.
Committing, pushing and opening the pull request each require the user's explicit approval.

Base branch: $ARGUMENTS (default `main`; confirm if the repository uses another)

## Step 1 - Inspect

1. `git status`: list uncommitted and untracked files. Ask how to handle them; never discard work.
2. `git branch --show-current`: refuse to prepare a pull request from the base branch itself;
   suggest creating a branch.
3. `git fetch` only if the user agrees to network access; then compare with the base:
   `git log --oneline <base>..HEAD` and `git diff --stat <base>...HEAD`.
4. Read the full diff. Identify the purpose, affected areas and any unrelated changes.

## Step 2 - Self-review the diff

Check against `eng-clean-code`, `eng-security` and the relevant standards:

- Unrelated changes, debug output, commented-out code, TODOs added without tracking.
- Secrets, credentials, `.env` files, keys, dumps or personal data.
- Authorization and validation on new or changed operations; isolation for restricted data.
- Migrations: reviewed, reversible or with a recovery plan.
- Breaking changes to APIs, schemas, configuration or behavior.

## Step 3 - Verify

1. Run the project's lint, type-check and test commands from `docs/engineering/TESTING.md` or
   `CLAUDE.md`. Record exact commands and results.
2. For user-facing changes, run or reference `eng-responsive-audit` results.
3. For security-sensitive changes, run `eng-security-audit` on the changed scope or delegate to
   `eng-security-reviewer`.
4. Fix verified defects (with the user's agreement) and re-run the affected checks.

## Step 4 - Independent release review

Delegate to `eng-release-reviewer`, giving it the commit list, diff, test output, security and
responsive results and the acceptance criteria. Address blockers before continuing.

## Step 5 - Draft the pull request

```
## Summary
What changed and why (1-3 sentences).

## Changes
- ...

## Acceptance criteria
- [x] criterion - verified by <test or check>
- [ ] criterion - not verified: <reason>

## Testing
<commands and results>

## Security
<review performed, findings and their status>

## Responsive and accessibility
<widths checked and results, or not applicable>

## Breaking changes and migration
<none, or details>

## Follow-ups
```

## Step 6 - Hand off

Show the draft. Then, only with explicit approval for each step: commit remaining changes, push the
branch, and open the pull request using the available tooling (for example `gh pr create`). Never
merge, never force-push, never push to the base branch. Update `docs/engineering/CURRENT_STATE.md`
with the pull request status.

## Acceptance criteria

- [ ] Diff reviewed in full; unrelated changes and secrets excluded
- [ ] Lint, type checks and tests run with actual results recorded
- [ ] Security and responsive checks done where applicable, or marked not applicable with reason
- [ ] Release review completed and blockers resolved
- [ ] Pull request description states verified and unverified items honestly
- [ ] Nothing merged; nothing pushed or opened without explicit approval
