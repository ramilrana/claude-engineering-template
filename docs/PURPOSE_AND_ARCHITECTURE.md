# Purpose and architecture

## Purpose

This repository is a reusable software-engineering governance system for Claude Code. It owns the
shared engineering standards (security, database security, clean code, responsive design, frontend
and backend quality, testing, workflow), the agents and skills that apply them, the project
documentation templates, and the tooling that distributes, updates and validates them.

It is **not** an application, a framework-specific starter kit, a store for project code,
credentials or data, a replacement for project documentation, or a system that changes projects
automatically.

## Three layers

| Layer | Owns | Lives in |
|---|---|---|
| A. Central repository | Standards, shared agents, skills and rules, documentation templates, scripts, tests, releases | This repository |
| B. Project installation | A tested copy of the managed files for one template version, plus the lock file | Each project's `.claude/` |
| C. Project customization | Requirements, code, architecture, stack, database, auth, security policies, design system, local agents and skills, settings, hooks, plans, tests, deployment, `CURRENT_STATE.md` | Each project |

Layer B is a copy, never a link: a project keeps working if this repository moves, changes or
disappears, and it adopts a newer version only when someone runs the updater.

## Directory responsibilities

| Path | Responsibility |
|---|---|
| `distribution/managed/.claude/rules/` | Short, focused rules loaded by Claude Code (always, or for matching paths) |
| `distribution/managed/.claude/engineering-standards/` | The single detailed source for each standard, read on demand |
| `distribution/managed/.claude/agents/` | Specialist agents |
| `distribution/managed/.claude/skills/` | Reusable workflows |
| `distribution/scaffold/` | Project-owned starting documents, created only if missing |
| `distribution/examples/` | Opt-in, inactive examples |
| `TEMPLATE_MANIFEST.json` | The only list of what ships, where it goes and who owns it |
| `scripts/lib/Template.Core.psm1` | Planning, path safety, hashing, transactional apply, lock handling, reporting |
| `scripts/*.ps1` | Thin entry points: install, update, test, release |
| `tests/` | Dependency-free test suites run in temporary directories |
| `docs/` | Documentation of this system (never distributed) |
| `.claude/` | Agent and skill for maintaining this repository (never distributed) |
| `.github/` | Review ownership, pull request checklist, CI, Dependabot |

## How the pieces fit in a project

```text
CLAUDE.md (project-owned)  -> imports docs/engineering/CURRENT_STATE.md
.claude/rules/eng-*.md     -> always-loaded checklists; UI rules load for UI files only
     \-> point to .claude/engineering-standards/*.md for detail (read when relevant)
.claude/agents/eng-*.md    -> specialists the main session delegates to
.claude/skills/eng-*/      -> workflows: bootstrap, resume, audits, design, PR, template update
docs/engineering/*.md      -> the project's own requirements, architecture, plan and state
```

## Design decisions and trade-offs

| Decision | Why | Trade-off |
|---|---|---|
| Copy-based distribution with a lock file | Projects stay independent and reviewable; updates are deliberate | Updates require running a script per project |
| Everything that ships lives under `distribution/` and is listed in the manifest | One invariant, checked in both directions by tests, prevents leaking development files | Slight deviation from a flat `docs/` layout for standards |
| Detailed standards installed into `.claude/engineering-standards/` | Projects must work without this repository, and each standard has exactly one source | Projects carry about 1,000 lines of reference text that loads only on demand |
| Destination policy in code, not in the manifest | A manifest edit cannot widen where files may be written | Adding a new destination area requires a code change and review |
| Ownership by hash, not by timestamps or markers | Detects any local edit reliably, independent of editors and Git | Re-saving a file with different line endings counts as an edit; `.gitattributes` keeps LF |
| Conflict candidates in `.template-update-candidates/` with `.claude` renamed to `dot-claude` and a suffix on every file | Claude Code discovers nested `.claude` directories and `CLAUDE.md` files; candidates must never become active | Paths in the candidate folder differ slightly from their destinations |
| Plan, then apply; backups; rollback; lock written last | A failure never leaves a falsely successful lock or a half-updated project | Slightly more code than a copy loop |
| Reviewer agents without Bash or write tools | Read-only is enforced by Claude Code, not just requested in a prompt | The main session must supply diffs and test output to reviewers |
| No Pester or other modules | Windows PowerShell ships Pester 3.4, incompatible with Pester 5; nothing to install | A small custom assertion helper (`tests/TestHelpers.psm1`) |
| PowerShell only | Native on Windows; PowerShell 7 runs on macOS and Linux | macOS and Linux users install PowerShell 7 |
| No third-party skills or plugins | The template must be complete and maintainable on its own | Optional tools can be recommended but are never required |

## Known limitations

- Frontmatter of agents, skills and rules is validated by a static check against the formats
  documented for Claude Code 2.1.309; the check does not start Claude Code. Confirm loading
  manually with `/agents` and the `/` menu after format changes.
- The test frontmatter parser supports the YAML subset this repository uses (flat keys, quoted
  strings, block lists). Files must stay within it.
- Permission rules and the example hook match command text and can be evaded; they are guardrails
  alongside human approval, not security boundaries.
- Responsive verification depends on browser tooling in each project; the template defines the
  procedure but does not bundle a browser.
- Three-way conflict bases require the template checkout to be a Git repository with release tags.
