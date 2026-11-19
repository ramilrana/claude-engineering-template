# Example: the "Workflow tools" section of a project's CLAUDE.md

This is an inactive example. It shows how a full-stack web project could name its own tools for
some workflow stages. The stage names and the template defaults are in
`.claude/engineering-standards/ENGINEERING_WORKFLOW.md` section 4.

The tools named below are third-party examples, not recommendations, and the template does not
need any of them. Before adopting one, review it as described in
`.claude/engineering-standards/SECURITY_STANDARD.md` section 10, install a pinned copy with the
user's approval, and record it in the project's documentation. Replace each "pinned version" cell
with the release or commit you reviewed.

Copy the section below into the project's `CLAUDE.md`, replacing its "Workflow tools" section,
and keep only the rows the project uses.

---

## Workflow tools

Stages not listed use the template default. Chained tools run as separate, ordered steps; never two
tools for the same step.

| Stage | Tool and how to run it | Pinned version |
|---|---|---|
| Brainstorm | Superpowers `brainstorming` skill | plugin release reviewed on <date> |
| Plan | Superpowers `writing-plans` skill | plugin release reviewed on <date> |
| Design references | `awesome-design` project skill (brand style references, for direction only) | library commit <sha> |
| Screen design and build | `design-taste-frontend` (Taste) project skill for new screens | commit <sha> |
| Design audit | `/impeccable audit` | skill release <version> |
| Polish | `/impeccable polish`, after the audit findings are fixed | skill release <version> |
| Browser verification | `playwright-cli` project skill | CLI <version>, skill commit <sha> |

Notes for this project:

- The design system stays with the template's `eng-frontend-design` skill; the tools above design
  and refine individual screens against it.
- Existing screens go straight to the design audit stage.
- The Impeccable hooks stay off.
