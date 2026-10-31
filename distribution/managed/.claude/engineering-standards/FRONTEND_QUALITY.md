# Frontend Quality Standard

Part of the shared engineering template. The summary rule `eng-frontend-quality` loads when Claude
works on UI files. Responsive and accessibility requirements are in `RESPONSIVE_DESIGN_STANDARD.md`.
The project's own visual language is defined in `docs/engineering/DESIGN_SYSTEM.md`.

## 1. Product-specific design, not generic output

Interfaces must reflect the product's purpose, its users and its identity. Before building a major
interface:

1. Identify the intended users, their context (device, environment, expertise) and goals.
2. Map the primary workflows and the decisions users make on each screen.
3. Establish the visual direction and record it in `docs/engineering/DESIGN_SYSTEM.md`
   (the `eng-frontend-design` skill guides this).
4. Define the design tokens and components needed.
5. Define responsive behavior for each layout.
6. Define every component state.
7. Check accessibility.
8. Review the actual rendered interface at the representative widths.

## 2. Anti-patterns to avoid

| Avoid | Prefer |
|---|---|
| Arbitrary gradients, glows and glassmorphism | Color used to communicate hierarchy, state and brand |
| Everything in cards | Cards only for discrete, comparable items; plain sections and lists otherwise |
| Random accent colors | A small, documented palette with semantic roles |
| Decorative animation | Short, purposeful motion that explains change; reduced-motion support |
| Inconsistent typography | A type scale with defined roles (display, heading, body, caption, code) |
| Cramped or uneven spacing | A spacing scale applied consistently |
| Generic KPI dashboards | Screens organized around the user's actual tasks |
| Fake metrics, testimonials, logos or names | Real content, or clearly labeled sample data in prototypes only |
| Desktop-only layouts | Mobile-first layouts verified across widths |
| Impressive but unusable components | Familiar patterns that users already understand |

## 3. Design system

- Tokens for color (with semantic roles: background, surface, text, muted, primary, danger,
  warning, success, info, border, focus), typography, spacing, radius, elevation, z-index and motion.
- Light and dark themes only if the product needs them; both must meet contrast requirements.
- Components document their variants, sizes and states.
- Reuse the project's UI library (for example a component library or headless primitives) before
  writing new components; extend it consistently.

## 4. Component states

Every interactive or data-driven component handles: default, hover, focus-visible, active,
disabled, loading (with skeletons or progress that does not shift layout), empty (with a helpful
next step), error (with recovery), success, and overflowing or very long content.

## 5. Frontend code quality

- Components are small and named for the domain concept they render. Split when a component
  mixes data fetching, business logic and complex presentation.
- Follow the project's state-management approach. Keep server state in the data-fetching layer,
  derive values instead of duplicating state, and keep global state minimal.
- Types for props, API responses and form values. Validate API responses at the boundary when the
  API is not type-shared.
- Forms: one validation schema shared between client and server where the stack allows; the
  server always revalidates.
- API integration goes through a shared client that handles authentication, errors and
  cancellation consistently.
- Routing protects pages for usability only; the API enforces authorization.
- Never put secrets in frontend code or public environment variables.

## 6. Performance

- Measure with the browser's performance tools or Lighthouse before optimizing.
- Code-split large routes; lazy-load below-the-fold media; use the framework's image optimization.
- Avoid layout shift (reserved media space, stable skeletons).
- Keep dependencies lean; check bundle impact before adding UI libraries.
- Track Core Web Vitals (LCP, INP, CLS) where the project has monitoring.

## 7. Optional external design resources

Third-party design skills and references can be useful but are never required by this template.
Before adopting one, review its availability, documentation, license, maintenance status and
security, and get approval. Do not copy third-party code or assets without license review and
attribution.

## 8. Review checklist

- [ ] Matches `docs/engineering/DESIGN_SYSTEM.md`; uses tokens, not ad-hoc values
- [ ] Primary workflow and hierarchy are clear
- [ ] No generic anti-patterns or invented content
- [ ] All component states implemented
- [ ] Responsive behavior verified at the representative widths
- [ ] WCAG 2.2 AA checks done (keyboard, focus, labels, contrast, targets, reflow)
- [ ] Components focused, typed and consistent with project conventions
- [ ] No secrets or authorization logic relied upon in the client
