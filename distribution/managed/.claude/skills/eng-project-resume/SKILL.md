---
name: eng-project-resume
description: "Resume work on an existing project in a new session by checking the Git working tree, CLAUDE.md, docs/engineering/CURRENT_STATE.md, the implementation plan and recent history, then reporting the verified state and the next task."
when_to_use: "Use at the start of a session, when the user says continue, resume or pick up where we left off, or when the current state of the project is unclear."
---

# Resume a project

Rebuild an accurate picture of the project from the repository itself, then continue with the next
unfinished task. Documents can be stale; Git and the code are the source of truth.

## Procedure

1. **Location**: confirm the working directory is the intended project (repository root, project
   name in `CLAUDE.md` or README).
2. **Working tree**: run `git status`, `git branch --show-current` and
   `git log --oneline -15`. Note uncommitted or untracked changes and do not discard, stash or
   overwrite them.
3. **Instructions**: `CLAUDE.md` is already loaded; note project commands and deviations.
4. **State**: read `docs/engineering/CURRENT_STATE.md`. Compare its branch, last verified commit,
   active task and test results with what Git shows.
5. **Plan**: read the current milestone in `docs/engineering/IMPLEMENTATION_PLAN.md`.
6. **Verify the active task**: inspect the files it touches. Decide whether it is done, partially
   done or not started based on code and tests, not on the document.
7. **Optional quick check**: if the project's test command is fast and safe, run it to confirm the
   baseline; otherwise say it was not run.
8. **Report** to the user before making changes.

## Report format

```
Project: <name>    Branch: <branch>    HEAD: <short sha> <subject>
Working tree: clean | <n> modified, <n> untracked (list key files)
Template: <installed version from .claude/engineering-template.lock.json, if present>
Phase / milestone: ...
Last recorded state: <date or commit from CURRENT_STATE.md>  Matches Git: yes | no (explain)
Completed (verified): ...
Active task: <task> - status: done | partial | not started (evidence)
Known issues and risks: ...
Baseline tests: <command and result> | not run (reason)
Next action: <the next concrete step>
Questions: ...
```

## Rules

- If `CURRENT_STATE.md` disagrees with Git, trust Git, explain the difference and offer to update
  the document.
- If the next step is ambiguous or needs a decision, ask instead of guessing.
- Do not repeat discovery or brainstorming that the documents show as approved.
- When work progresses to a meaningful milestone, update `CURRENT_STATE.md` (concise snapshot).

## Acceptance criteria

- [ ] Git status, branch and recent history inspected and reported
- [ ] `CURRENT_STATE.md` and the plan reconciled with the actual code
- [ ] Active task status supported by evidence
- [ ] No uncommitted work disturbed
- [ ] Clear next action, or a question for the user
