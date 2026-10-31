# Release process

Releases are Git tags (`vMAJOR.MINOR.PATCH`) on `main`, created after validation and published only
with approval.

## 1. Prepare the release pull request

On a branch such as `release/1.1.0`:

1. Decide the version from the changes since the last tag (see
   [DISTRIBUTION_AND_VERSIONING.md](DISTRIBUTION_AND_VERSIONING.md#semantic-versioning)):
   `git log --oneline v1.0.0..main`.
2. Update `VERSION`.
3. In `CHANGELOG.md`, move the `[Unreleased]` entries into `## [1.1.0] - YYYY-MM-DD`, keep an empty
   `[Unreleased]` section, and add a **Migration** section for deprecated files, ownership changes or
   breaking changes.
4. Run the tests on Windows PowerShell 5.1 and PowerShell 7.
5. Open the pull request; merge after review and green CI.

## 2. Release checklist

`scripts/New-EngineeringTemplateRelease.ps1` automates the items marked (auto).

| # | Check | How |
|---|---|---|
| 1 | Working tree is clean | (auto) |
| 2 | On `main` | (auto) |
| 3 | `VERSION` is valid and its tag does not exist | (auto) |
| 4 | `CHANGELOG.md` has a dated section for the version | (auto) |
| 5 | Manifest valid and every managed file exists | (auto, Manifest suite) |
| 6 | Claude Code formats valid | (auto, ContentFormats suite); re-verify docs if formats changed |
| 7 | Installer tests pass | (auto) |
| 8 | Updater tests pass | (auto) |
| 9 | Project-isolation tests pass | (auto) |
| 10 | CI green on all three environments for the release commit | Check GitHub Actions |
| 11 | Security implications reviewed | Pull request review |
| 12 | Responsive and clean-code standards not weakened | Pull request review |
| 13 | Backward compatibility checked; MAJOR bump if broken | Pull request review |
| 14 | Deprecated files documented with migration notes | `CHANGELOG.md` |
| 15 | Release notes prepared | Printed by the script from `CHANGELOG.md` |
| 16 | Approval to publish | Ask the maintainer |

## 3. Create the tag

```powershell
git switch main
git pull --ff-only
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\New-EngineeringTemplateRelease.ps1 -WhatIf
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\New-EngineeringTemplateRelease.ps1
```

The script runs every automated gate, prints the release notes, and creates a local annotated tag.
It never pushes.

## 4. Publish (after approval)

```powershell
git push origin v1.1.0
```

Optionally create a GitHub release from the tag with the changelog section as notes, through the
GitHub web interface or `gh release create v1.1.0 --notes-file <file>`.

## 5. After the release

- Announce the release and its migration notes to project maintainers.
- Projects update when they choose, using [INSTALLATION_WINDOWS.md](INSTALLATION_WINDOWS.md) and the
  `eng-template-update` skill.

## Hotfixes

Fix on a branch from `main`, release as a PATCH. Projects on older MAJOR versions are not patched;
they update to the current release.

## Deprecating a managed file

1. Remove its manifest entry and its file under `distribution/` (MAJOR if projects must act, MINOR
   if it is safely superseded).
2. Add a **Migration** note: what replaces it and whether projects should delete their copy.
3. The updater marks it `deprecated` in projects and leaves the file in place.
4. Never reuse the removed name for a different purpose.
