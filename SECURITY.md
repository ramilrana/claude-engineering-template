# Security policy

## Reporting a vulnerability

Report suspected vulnerabilities privately through GitHub's **Report a vulnerability** button on
the repository's Security tab (private vulnerability reporting), or by contacting the maintainer
listed in `.github/CODEOWNERS`. Do not open a public issue for security problems.

Please include the affected version or commit, the steps to reproduce, and the impact you expect.
You will receive an acknowledgement, and the fix will be released with a `Security` entry in
`CHANGELOG.md`.

## Supported versions

The latest MINOR release of the current MAJOR version receives security fixes. Projects on older
releases should update with `scripts/Update-EngineeringTemplate.ps1`.

## Security model of the installer and updater

The scripts run with the permissions of the user who starts them and write only inside the chosen
project directory. They are designed so that:

- only files listed in `TEMPLATE_MANIFEST.json` are copied, and only from `distribution/`;
- destinations are restricted by ownership class to `.claude/rules/`, `.claude/agents/`,
  `.claude/skills/`, `.claude/engineering-standards/`, `CLAUDE.md` and `docs/engineering/`, and this
  policy lives in code, not in the manifest;
- absolute paths, traversal segments, reserved characters, and writes through symbolic links or
  junctions are refused;
- project-owned and locally modified files are never overwritten, and no file is ever deleted from a
  project (rollback removes only files created by the failed run itself);
- every copy is verified by SHA-256, replaced files are backed up first, and a failed run is rolled
  back without updating the lock file;
- settings, permissions, hooks and MCP configuration are never written;
- no network access is needed or performed, and no secrets or machine-specific paths are written to
  the lock file.

Anything that weakens one of these guarantees is a security-relevant change.

## Content in this repository

Never commit credentials, tokens, `.env` files, real project data or database dumps. Examples use
obviously fake values only.

## Third-party components

The repository has no runtime dependencies. The CI workflow uses `actions/checkout` pinned to a
full commit SHA, updated through Dependabot pull requests that are reviewed like any other change.
