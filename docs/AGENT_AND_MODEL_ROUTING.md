# Agent and model routing

How the distributed agents are configured and why. The project-facing usage guidance (when to
delegate in the lifecycle) is in
`distribution/managed/.claude/engineering-standards/ENGINEERING_WORKFLOW.md`, section 3.

## Verified configuration format

Agent and skill definitions were checked against the official Claude Code documentation for
version 2.1.309 (the version installed when 1.0.0 was built):

- Agents: Markdown with YAML frontmatter in `.claude/agents/`. Required: `name`, `description`.
  Used here: `tools` (explicit allow-list), `model` (alias), `effort`, `color`. Supported model
  aliases: `sonnet`, `opus`, `haiku`, `fable`, `inherit`. Effort levels: `low`, `medium`, `high`,
  `xhigh`, `max` (availability depends on the model).
- Skills: `.claude/skills/<name>/SKILL.md`. Used here: `name`, `description`, `when_to_use`
  (combined listing text limit 1,536 characters), `argument-hint`, `disable-model-invocation`.
- Rules: `.claude/rules/*.md`, optional `paths:` list of globs (brace expansion supported).

`tests/Test-ContentFormats.ps1` encodes these expectations. When Claude Code's formats change,
re-verify the documentation and update the test in the same change.

## Inventory

| Agent | Model | Effort | Tools | Rationale |
|---|---|---|---|---|
| `eng-project-architect` | `opus` | high | Read, Grep, Glob, WebFetch, WebSearch | Planning benefits most from the strongest reasoning; it reads and researches but never edits, so plans are reviewed before anything changes |
| `eng-architecture-reviewer` | `opus` | high | Read, Grep, Glob | Independent judgment; read-only enforced by tools |
| `eng-security-reviewer` | `opus` | high | Read, Grep, Glob | Security review needs depth; read-only enforced by tools |
| `eng-frontend-design-reviewer` | `opus` | high | Read, Grep, Glob | Design and accessibility judgment; read-only |
| `eng-release-reviewer` | `opus` | high | Read, Grep, Glob | Gatekeeping decision; read-only |
| `eng-frontend-engineer` | `sonnet` | default | Read, Grep, Glob, Edit, Write, Bash, WebFetch | Routine implementation at good speed and cost |
| `eng-backend-engineer` | `sonnet` | default | Read, Grep, Glob, Edit, Write, Bash, WebFetch | Routine implementation |
| `eng-database-engineer` | `sonnet` | default | Read, Grep, Glob, Edit, Write, Bash, WebFetch | Schema and query work; forbidden from touching shared databases by instruction and by the project's permission prompts |
| `eng-qa-engineer` | `sonnet` | default | Read, Grep, Glob, Edit, Write, Bash | Writes and runs tests |

Aliases are used instead of dated model IDs so agents follow the current model generation without
template changes.

## Read-only enforcement

Reviewers get no `Bash`, `PowerShell`, `Edit`, `Write` or `NotebookEdit`. This is a technical
restriction enforced by Claude Code, not an instruction the model could ignore. The cost is that
reviewers cannot run `git diff` or tests themselves: the main session runs those commands and passes
the output in the delegation prompt. Each reviewer's instructions say to mark checks as "not
verified" when that evidence is missing.

The alternative, giving reviewers Bash with a hook that blocks write commands, was rejected: the
hook would need a cross-platform script, and command filtering can be bypassed.

## Permissions

No agent sets `permissionMode`, so every agent inherits the project's permission mode and prompts.
Implementation agents can request shell commands and edits; the user still approves them according
to the project's settings.

## Platform note

Implementation agents list `Bash`. On Windows installations where Claude Code uses the PowerShell
tool instead of Git Bash, a project can add `PowerShell` to a local copy of the agent (record it as
a template deviation) or propose the change centrally.

## When not to use subagents

Do simple, well-scoped tasks in the main session. Delegate when specialization, an independent
opinion or context isolation is worth the extra time and tokens. The main session always integrates
results and remains responsible for verification.

## Skills and invocation

| Skill | Invocation | Reason |
|---|---|---|
| `eng-project-bootstrap` | Manual only | Writes many project documents |
| `eng-project-resume` | Automatic allowed | Read-mostly, useful at every session start |
| `eng-security-audit` | Automatic allowed | Read-only assessment |
| `eng-responsive-audit` | Automatic allowed | Read-only checks |
| `eng-frontend-design` | Automatic allowed | Proposes before writing |
| `eng-prepare-pr` | Manual only | Leads to commits, pushes and pull requests |
| `eng-template-update` | Manual only | Changes template-managed files |

Skills do not select models; agents do.

## Changing a model for one project

Exclude the template agent (`-Exclude .claude/agents/<name>.md`) and add a project agent with a
different name and model, or edit the managed agent and record the deviation.
