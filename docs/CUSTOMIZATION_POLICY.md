# Customization and file-ownership policy

## Who owns what

| Centrally managed (updated by the template) | Project-owned (never changed by the template) |
|---|---|
| `.claude/rules/eng-*.md` | Root `CLAUDE.md` and `CLAUDE.local.md` |
| `.claude/agents/eng-*.md` | `docs/engineering/*` (requirements, stack, architecture, security, plan, design system, testing, deployment, current state) |
| `.claude/skills/eng-*/` | Project-specific rules, agents and skills (`project-*` or any non-`eng-` name) |
| `.claude/engineering-standards/*` | `.claude/settings.json`, `.claude/settings.local.json`, hooks, MCP configuration, plugins |
| | Application source code, tests and deployment |

## How to customize

1. **Strengthen with a project rule (preferred).** Add `.claude/rules/project-<topic>.md`, optionally
   path-scoped with `paths:` frontmatter. It loads alongside the shared rules and survives every
   update. Example: `distribution/examples/project-customization/project-rule.example.md`.
2. **Add local agents and skills** under names that do not start with `eng-`, for example
   `project-accessibility-auditor`. Claude Code identifies agents by name, so unique names prevent
   collisions with template agents.
3. **Opt out of a managed file** that does not fit the project with `-Exclude <path>`. The file is
   no longer updated; if it exists it is left in place for you to delete or keep.
4. **Edit a managed file only when necessary.** The updater detects the edit by hash, keeps your
   version, and offers a conflict candidate only when a release changes the central file. Record the change under
   "Template deviations" in the project's `CLAUDE.md`.
5. **Project-owned documents** are yours from the moment they are created. When the scaffold
   changes centrally, the updater saves the new version as a reference only.

## What customizations may not do

Project instructions may make the shared standards stricter or more specific. They must not
silently weaken mandatory requirements for:

- security and data protection (server-side authorization, isolation, secrets, validation);
- correctness and honest verification;
- clean, maintainable code;
- responsive and accessible user interfaces.

An intentional deviation (for example, a documentation-only project excluding the frontend rules,
or an internal tool with a documented accessibility exception) is recorded in `CLAUDE.md` with what
differs, why, who approved it and when it will be reviewed.

## Settings, permissions and hooks

The template never writes settings or hooks. Recommended configurations are provided as inactive
examples (`-IncludeExamples`) and must be reviewed and merged by hand. Never add unrestricted
`allow` rules (`Bash`, `Bash(*)`, `Edit`, `Write`) or disable approval mechanisms.

## Proposing changes back to the template

When a project customization would help every project, propose it to the central repository through
a pull request instead of keeping a long-lived local deviation. Once released, update the project
and remove the deviation.
