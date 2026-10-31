---
name: eng-responsive-audit
description: "Audit rendered and source-level responsive behavior, usability, accessibility and overflow of web pages across the representative viewport widths from 320 to 1920 px, and report actual results per page and width."
when_to_use: "Use after frontend changes, before a pull request with user-facing changes, or when the user asks to check mobile, tablet or desktop layouts, overflow or accessibility."
argument-hint: "[pages or routes to audit, and the local URL if the app is running]"
---

# Responsive and accessibility audit

Verify that user-facing pages work from 320 to 1920 px, following
`.claude/engineering-standards/RESPONSIVE_DESIGN_STANDARD.md`. Report only what you actually
checked.

Target: $ARGUMENTS

## Step 1 - Scope and tooling

1. Identify the pages or routes and the states to check (logged out or in, empty, populated,
   error, long content). Ask if unclear.
2. Find the project's browser tooling: Playwright, Cypress, WebdriverIO, Storybook test runner, or
   a browser automation tool available in this session. Use what exists.
3. If no tooling exists, propose adding Playwright as a development dependency and ask before
   installing anything. Without browser tooling, perform the source-level review (Step 3) and state
   clearly that rendered behavior is unverified.
4. Confirm how to run the app locally. Never audit against production with real user accounts.

## Step 2 - Rendered checks

Widths: 320, 360, 375, 390, 430, 768, 1024, 1280, 1440, 1920. Add landscape for phone and tablet
widths where relevant. At each width, for each page:

1. Horizontal overflow. In the page context:
   `document.documentElement.scrollWidth > document.documentElement.clientWidth` must be false.
   If true, find the widest offending elements, for example:
   `[...document.querySelectorAll('body *')].filter(e => e.getBoundingClientRect().right > document.documentElement.clientWidth + 1)`
2. Clipped, overlapping or hidden content, including sticky and fixed elements.
3. Navigation: menu opens and closes, focus moves correctly, every destination is reachable.
4. Dialogs, drawers and dropdowns fit the viewport and are dismissible with Escape.
5. Forms: labels visible, errors shown next to fields, correct input types.
6. Tables: contained scrolling with keyboard access or an alternative layout; no lost data.
7. Touch targets for primary controls at least 24x24 CSS px (44x44 preferred).
8. Images scale correctly and do not cause layout shift.
9. Long words, URLs and user content wrap.
10. 200% browser zoom at 1280 px.
11. Keyboard-only pass through the primary workflow with visible focus.
12. Automated accessibility scan (for example axe via `@axe-core/playwright`) if available.

Capture screenshots for failures and representative widths if the tooling supports it.

## Step 3 - Source-level review

Look for fixed pixel widths on containers, `100vw` widths, missing `min-width: 0` on flex or grid
children, unwrapped long text, tables without a scroll container, hover-only interactions,
missing labels or alternative text, removed focus outlines, hard-coded colors that bypass tokens,
and animations without `prefers-reduced-motion` handling.

## Step 4 - Report

```
## Environment (URL, tool, browser)
## Matrix
| Page | 320 | 360 | 375 | 390 | 430 | 768 | 1024 | 1280 | 1440 | 1920 |
(pass / fail / not checked)
## Failures (page, width, issue, evidence, likely cause path:line, fix)
## Accessibility findings
## Not verified and why
```

Offer to fix the failures, or delegate a review of screenshots to `eng-frontend-design-reviewer`.

## Acceptance criteria

- [ ] Every requested page checked at every representative width, or gaps stated
- [ ] No page-level horizontal overflow at any width, or each failure reported with its cause
- [ ] Navigation, dialogs, forms and tables verified on small screens
- [ ] Keyboard and accessibility checks performed or explicitly not performed
- [ ] Results reflect actual rendered checks; source-only findings are labeled as such
