---
name: template-validation
description: "Validate the claude-engineering-template repository: manifest correctness, distribution invariants, Claude Code formats of agents, skills and rules, installer, updater, isolation and rollback tests, on Windows PowerShell 5.1 and PowerShell 7."
when_to_use: "Use after changing anything in this repository, before opening a pull request, and before preparing a release."
---

# Validate the template repository

## Steps

1. `git status` - note uncommitted changes; validation runs against the working tree.
2. Run the full suite under Windows PowerShell 5.1:

   `powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/Test-EngineeringTemplate.ps1`

3. Run it under PowerShell 7 if installed (`pwsh -NoProfile -File ./scripts/Test-EngineeringTemplate.ps1`).
   If PowerShell 7 is not installed, say so; CI covers PowerShell 7 on Windows and Linux.
4. For a focused run use `-Name Manifest`, `Installation`, `Updates`, `ProjectIsolation` or
   `ContentFormats` (comma-separated for several).
5. If agent, skill, rule or settings formats changed, compare them with the current official Claude
   Code documentation and update `tests/Test-ContentFormats.ps1` if the supported fields changed.
6. Optional manual smoke test: install into a scratch directory outside this repository with
   `-WhatIf`, then for real, and open it in Claude Code to confirm `/agents` lists the `eng-` agents
   and the `eng-` skills appear in the `/` menu.

## Report

List each command, the edition it ran under, and the pass/fail summary lines. For failures, include
the failing case and its message, then fix the cause (not the test) unless the test is wrong.

## Acceptance criteria

- [ ] All suites pass on Windows PowerShell 5.1
- [ ] PowerShell 7 result reported (local run or CI)
- [ ] Format changes verified against current Claude Code documentation
- [ ] Results reported exactly as produced
