---
paths:
  - "**/*.{html,htm,css,scss,sass,less,styl}"
  - "**/*.{jsx,tsx,vue,svelte,astro,mdx}"
  - "**/*.{php,erb,haml,slim,cshtml,razor,twig,hbs,ejs,njk,liquid,jinja,j2}"
  - "**/{components,pages,views,layouts,templates,screens,ui,styles}/**"
  - "**/tailwind.config.*"
---

# Frontend design and code quality (shared template rule)

Interfaces must be specific to this product's purpose, audience and identity, consistent with
`docs/engineering/DESIGN_SYSTEM.md`, and maintainable. Full guidance:
`.claude/engineering-standards/FRONTEND_QUALITY.md`.

## Before building a major screen or flow

Understand the users and their primary workflow, follow (or first establish, with the
`eng-frontend-design` skill) the design system, define responsive behavior and every component
state (loading, empty, error, success, disabled, long content), then review the rendered result.

## Design rules

- Use the project's existing UI framework, components, tokens and patterns before creating new ones.
- Typography, color, spacing, radius and elevation come from design tokens, not ad-hoc values.
- Visual hierarchy follows the workflow: the primary action is obvious; secondary actions recede.
- No generic AI-looking output: arbitrary gradients, card grids for everything, random accent
  colors, decorative animation, inconsistent type, cramped or uneven spacing, generic dashboards
  where the product does not need one.
- Never ship invented content: fake metrics, testimonials, logos, customer names or statistics.
  Use clearly marked sample data only when the user asks for a prototype.
- Motion is purposeful, short and respects `prefers-reduced-motion`.

## Component code

- Components are small, named for what they represent, and keep data fetching, business rules
  and presentation separated in the way the project already does.
- Props and state are typed; derived state is computed, not duplicated.
- Forms validate on the client for usability and on the server for security, with accessible
  error messages tied to their fields.
- Avoid unnecessary re-renders, oversized bundles and unoptimized images; measure before
  optimizing.
- Frontend checks never replace server-side authorization.
