---
name: eng-frontend-design
description: "Establish or extend an application-specific design direction and design system: users and workflows, visual direction, typography, color, spacing, components and states, responsive behavior and accessibility, recorded in docs/engineering/DESIGN_SYSTEM.md."
when_to_use: "Use before building major user interfaces, when a project has no design system, when the UI looks generic or inconsistent, or when adding a significant new screen type."
argument-hint: "[product or screen to design for]"
---

# Frontend design direction and design system

Create a design direction specific to this product, its users and its identity, and record it in
`docs/engineering/DESIGN_SYSTEM.md` so every later screen is consistent. Follow
`.claude/engineering-standards/FRONTEND_QUALITY.md` and
`.claude/engineering-standards/RESPONSIVE_DESIGN_STANDARD.md`.

Subject: $ARGUMENTS

## Step 1 - Understand the product

1. Read `docs/engineering/PROJECT_REQUIREMENTS.md` and any existing `DESIGN_SYSTEM.md`.
2. Inspect the existing UI: framework, component library, CSS approach, existing tokens, brand
   assets, and screenshots or running pages if available.
3. Establish with the user: audience, their context and devices, the primary workflows, brand
   personality, accessibility needs, content density, and any reference products they admire or
   want to avoid. Ask a few focused questions at a time.

## Step 2 - Propose a direction

Present one recommended direction and, if useful, one alternative, each covering:

- Personality in a few words and why it fits the users.
- Layout approach for the primary workflows (not a generic dashboard unless the product needs one).
- Typography: families (system or licensed web fonts), type scale with roles.
- Color: neutral ramp, brand color, semantic colors (success, warning, danger, info), focus color,
  with contrast checked against WCAG 2.2 AA.
- Spacing scale, radius, elevation, borders, motion principles (and reduced motion).
- Iconography and imagery guidance.
- Responsive strategy: navigation pattern on small screens, grid behavior, table strategy.

Avoid the anti-patterns in `FRONTEND_QUALITY.md` section 2. Do not invent product claims, metrics
or testimonials for examples.

**Checkpoint:** get the user's approval or adjustments before writing the design system.

## Step 3 - Define the system

Write or update `docs/engineering/DESIGN_SYSTEM.md` with:

- Tokens with values and semantic roles, mapped to the project's mechanism (CSS custom properties,
  Tailwind theme, design-token files).
- Core components with variants, sizes and all states (default, hover, focus-visible, active,
  disabled, loading, empty, error, success, long content).
- Layout patterns for each screen type and their behavior at the representative widths.
- Accessibility requirements specific to the product.
- Do and don't examples in words.

Only implement tokens or components in code if the user asks; use the existing UI library where
possible and the `eng-frontend-engineer` agent for implementation.

## Step 4 - Validate

When a screen is built, review it with `eng-responsive-audit` and, for an independent opinion,
`eng-frontend-design-reviewer`.

## Acceptance criteria

- [ ] Direction is grounded in the users and workflows, approved by the user
- [ ] Tokens defined with semantic roles and verified contrast
- [ ] Components and every state specified
- [ ] Responsive behavior defined per layout pattern from 320 to 1920 px
- [ ] Accessibility requirements recorded (WCAG 2.2 AA baseline)
- [ ] No generic anti-patterns or invented content
- [ ] `docs/engineering/DESIGN_SYSTEM.md` updated
