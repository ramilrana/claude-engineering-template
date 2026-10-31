# GitHub workflow

## Repository

The central repository is public at
<https://github.com/ramilrana/claude-engineering-template>. Public visibility lets branch
protection, rulesets and secret scanning work on a free GitHub plan; the repository contains no
secrets or project data.

## Repository settings

Applied through the GitHub API (`gh api`) and verified by reading them back:

| Setting | Value |
|---|---|
| Branch protection on `main` | Pull request required; status checks `Windows PowerShell 5.1`, `PowerShell 7 on Windows` and `PowerShell 7 on Linux` must pass on an up-to-date branch; conversations must be resolved; force pushes and deletion blocked; enforced for administrators too |
| Required approvals | **0 while there is a single maintainer**, because GitHub does not let authors approve their own pull requests. When a second maintainer joins, raise it to 1 and require code-owner review |
| Merge methods | Merge commits only, so logical commits are preserved; head branches are deleted after merge |
| Ruleset "Protect release tags" | `v*` tags cannot be deleted, moved or force-updated once created |
| Secret scanning and push protection | Enabled |
| Private vulnerability reporting | Enabled (referenced by `SECURITY.md`) |
| Dependabot alerts | Enabled; `.github/dependabot.yml` keeps the SHA-pinned actions current |
| Actions permissions | Read-only `GITHUB_TOKEN` by default; workflows cannot approve pull requests |

To raise required approvals later:

```powershell
gh api -X PATCH repos/ramilrana/claude-engineering-template/branches/main/protection/required_pull_request_reviews -F required_approving_review_count=1 -F require_code_owner_reviews=true
```

## Changing this repository

1. Branch from `main` (`feature/...`, `fix/...`, `docs/...`).
2. Make the change and keep `distribution/` and `TEMPLATE_MANIFEST.json` in sync.
3. Run the tests on Windows PowerShell 5.1, and PowerShell 7 if available.
4. Review agents, skills and rules for correctness and duplication; review security implications of
   script changes.
5. Update `CHANGELOG.md` under `[Unreleased]` and the documentation.
6. Open a pull request with the template checklist; CI must pass; a code owner approves.
7. Merge. Release separately (see [RELEASE_PROCESS.md](RELEASE_PROCESS.md)).

Never push directly to `main`, force-push, or create remote tags or releases without approval.

## Adopting or updating the template in an application project

1. Start from a clean working tree on a dedicated branch, for example
   `chore/engineering-template-v1.1.0`.
2. Run the installer or updater with `-WhatIf`, review, then run it for real.
3. Reconcile conflicts deliberately; record intentional deviations in `CLAUDE.md`.
4. Keep `.template-update-candidates/` and `.template-update-backups/` out of commits.
5. Run the application's tests.
6. Open a pull request, get it reviewed and approved, and merge through the project's normal process.

## Application project practices (summary)

Stable protected main branch, feature and fix branches, logical commits, pull requests with CI and
required reviews, CODEOWNERS where useful, secret scanning and dependency monitoring. The full
guidance that projects receive is in
`distribution/managed/.claude/engineering-standards/ENGINEERING_WORKFLOW.md`, section 5.
