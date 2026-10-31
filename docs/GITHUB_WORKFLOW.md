# GitHub workflow

## Publishing this repository for the first time

The repository is created locally on branch `main`. Publishing is a manual, approved step:

1. Create an empty repository on GitHub (for example `ramilrana/claude-engineering-template`),
   private or public, without a README or license (they already exist).
2. Add the remote and push:

   ```powershell
   git remote add origin https://github.com/ramilrana/claude-engineering-template.git
   git push -u origin main
   ```

3. Push release tags only after they are approved: `git push origin v1.0.0`.
4. Configure the repository settings below.

## Recommended repository settings

| Setting | Value |
|---|---|
| Branch protection / ruleset on `main` | Require a pull request, at least one approving review, review from code owners, and the status checks `Windows PowerShell 5.1`, `PowerShell 7 on Windows`, `PowerShell 7 on Linux`; block force pushes and deletion |
| Tag protection / ruleset | Restrict creation of `v*` tags to maintainers |
| Secret scanning and push protection | Enabled |
| Private vulnerability reporting | Enabled (referenced by `SECURITY.md`) |
| Dependabot | Enabled; `.github/dependabot.yml` keeps pinned actions current |
| Actions permissions | Read-only `GITHUB_TOKEN` by default |

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
