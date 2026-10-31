## Summary

<!-- What changes and why. Link the issue if there is one. -->

## Type of change

- [ ] Fix (PATCH)
- [ ] Backward-compatible addition (MINOR)
- [ ] Breaking change or required migration (MAJOR)
- [ ] Repository maintenance only (not distributed)

## Distribution impact

- [ ] `TEMPLATE_MANIFEST.json` updated for every added, moved or removed distributed file
- [ ] No development-only files added to `distribution/`
- [ ] Ownership of existing destinations unchanged (or migration documented)
- [ ] Removed or renamed managed files documented as deprecated with migration notes

## Validation

<!-- Paste the summary lines of the actual runs. -->

- [ ] `powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/Test-EngineeringTemplate.ps1` (Windows PowerShell 5.1)
- [ ] `pwsh -NoProfile -File ./scripts/Test-EngineeringTemplate.ps1` (PowerShell 7), or CI result
- [ ] Agents, skills and rules checked against current Claude Code documentation where formats changed

## Review checklist

- [ ] Security implications reviewed (scripts never write outside the project, never overwrite project-owned files)
- [ ] Standards stay technology-independent; no project-specific framework or database assumptions
- [ ] No duplicated guidance; each standard has one source
- [ ] Clean-code and responsive-design requirements not weakened
- [ ] `CHANGELOG.md` updated under `[Unreleased]`
- [ ] Documentation updated (`README.md`, `docs/`)
