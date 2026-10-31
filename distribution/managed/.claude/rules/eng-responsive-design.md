---
paths:
  - "**/*.{html,htm,css,scss,sass,less,styl}"
  - "**/*.{jsx,tsx,vue,svelte,astro,mdx}"
  - "**/*.{php,erb,haml,slim,cshtml,razor,twig,hbs,ejs,njk,liquid,jinja,j2}"
  - "**/{components,pages,views,layouts,templates,screens,ui,styles}/**"
  - "**/tailwind.config.*"
---

# Responsive design and accessibility (shared template rule)

Responsiveness is a mandatory acceptance criterion for every user-facing feature, not polish.
Full guidance: `.claude/engineering-standards/RESPONSIVE_DESIGN_STANDARD.md`.

## Every interface must work on

Phones, tablets, laptops, desktops and large displays, in portrait and landscape where relevant.

## Build it this way

- Mobile-first, content-driven layouts using the project's framework conventions (flexbox, grid,
  container or media queries, fluid sizing). Breakpoints follow the content, not device names.
- No page-level horizontal scrolling, clipped or overlapping content, unreadable text or controls
  that cannot be reached or tapped.
- Do not hide essential information or functionality on small screens to make them look tidy.
- Navigation, headers, sidebars, forms, filters, dialogs, dropdowns, notifications, dashboards
  and charts adapt deliberately. Wide data tables use an accessible contained scroll region or an
  appropriate alternative layout.
- Images and media are responsive and sized to avoid layout shift.
- Long words, URLs and user-generated text wrap without breaking the layout.

## Accessibility (WCAG 2.2 AA by default)

Semantic HTML, keyboard operability, visible focus, labelled form controls, accessible validation
messages, sufficient contrast, screen-reader names and roles, touch targets of at least 24x24 CSS
pixels (44x44 preferred), support for 200% zoom, `prefers-reduced-motion`, single-pointer
alternatives to dragging, sign-in that allows paste and password managers, and reflow at 320 CSS
pixels without two-dimensional scrolling except for genuinely two-dimensional content.

## Verify before calling it done

Check rendered pages at 320, 360, 375, 390, 430, 768, 1024, 1280, 1440 and 1920 px wide (these are
test points, not required breakpoints), using the project's browser tooling such as Playwright.
Look for horizontal overflow, clipping, overlap, broken navigation and modals, form and table
behavior, touch usability, image scaling, long text and zoom. Report what you actually checked;
if no browser tooling is available, say so and list what remains unverified. The
`eng-responsive-audit` skill runs this check.
