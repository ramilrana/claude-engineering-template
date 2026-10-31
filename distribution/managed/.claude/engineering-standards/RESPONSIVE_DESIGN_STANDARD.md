# Responsive Design and Accessibility Standard

Part of the shared engineering template. The summary rule `eng-responsive-design` loads when
Claude works on UI files. This standard is mandatory for every website and user-facing
application: a frontend task is not complete until its responsive acceptance criteria are verified.

## 1. Supported environments

Mobile phones, tablets, laptops, desktop monitors and large displays; portrait and landscape where
the device allows both; touch, mouse and keyboard input; browser zoom up to 200% and text-only
zoom; user preferences such as reduced motion and dark mode where the product supports it.

## 2. Representative test widths

| Width (CSS px) | Represents |
|---|---|
| 320 | Small phones; WCAG reflow requirement |
| 360 | Common Android phones |
| 375 | Smaller iPhones |
| 390 | Current iPhones |
| 430 | Large phones |
| 768 | Tablets, portrait |
| 1024 | Tablets landscape, small laptops |
| 1280 | Laptops |
| 1440 | Desktops |
| 1920 | Large displays |

These are validation points, not required CSS breakpoints. Use content-driven breakpoints: add one
where the layout stops working, using the framework's conventions (Tailwind screens, CSS custom
media, container queries).

## 3. Layout principles

- Mobile-first CSS; enhance for larger screens.
- Fluid layouts with flexbox and grid; `minmax()`, `clamp()` and relative units instead of fixed
  pixel widths.
- Container queries for components that appear in containers of different widths.
- Limit line length for reading (roughly 45-90 characters) on large screens; use the extra space
  purposefully rather than stretching content.
- Never cause page-level horizontal scrolling. Common causes: fixed widths, long unbroken strings,
  wide tables or code blocks, negative margins, `100vw` with scrollbars, absolutely positioned
  elements.
- Use `overflow-wrap: anywhere` or `break-word` for user-generated content, URLs and identifiers.
- Reserve space for images and embeds (`width`/`height` or `aspect-ratio`) to avoid layout shift.
- Respect safe-area insets on devices with notches when using full-bleed layouts.

## 4. Component behavior

| Component | Expected adaptation |
|---|---|
| Navigation | Collapses to an accessible menu on small screens; the menu button has a name and `aria-expanded`; focus is managed; all destinations remain reachable |
| Headers and footers | Do not consume excessive vertical space on phones; sticky headers stay small |
| Sidebars | Become drawers, collapsible sections or move below content |
| Data tables | Contained horizontal scroll region with keyboard access and a visible cue, or a card/stacked layout that keeps every column's data; header context preserved |
| Cards and grids | Reflow column count with available width; consistent gaps |
| Forms | Single column on small screens; labels visible; inputs full width; correct `type`, `inputmode` and `autocomplete`; errors next to fields |
| Search, filters, pagination | Filters collapse into an accessible panel; applied filters stay visible; pagination controls remain tappable |
| Dialogs and drawers | Fit the viewport, scroll internally, trap and restore focus, close with Escape |
| Dropdowns and menus | Stay within the viewport; usable with touch and keyboard |
| Dashboards and charts | Reflow to a single column; charts resize and remain legible or offer an accessible table alternative |
| Images and media | `srcset`/`sizes` or the framework's image component; never upscale beyond intrinsic size |
| Notifications and toasts | Do not cover primary actions; announced to screen readers; dismissible |

Do not hide essential information or functionality on small screens to make them look cleaner.
Progressive disclosure is acceptable when content remains reachable.

## 5. Accessibility baseline (WCAG 2.2 Level AA)

- Semantic HTML first (landmarks, headings in order, lists, buttons for actions, links for
  navigation); ARIA only to fill genuine gaps.
- Every interactive element is reachable and operable by keyboard in a logical order, with a
  clearly visible focus indicator that is not obscured by sticky content.
- Form controls have programmatic labels; required fields and errors are conveyed in text and
  associated with their inputs; error summaries for long forms.
- Text contrast at least 4.5:1 (3:1 for large text); non-text UI components and focus indicators
  at least 3:1.
- Touch targets at least 24x24 CSS px (WCAG 2.2 minimum), 44x44 recommended for primary controls.
- Content reflows at 320 CSS px without horizontal scrolling, except genuinely two-dimensional
  content such as maps, complex data tables and diagrams.
- Content remains usable at 200% zoom and with increased text spacing.
- Respect `prefers-reduced-motion`; avoid flashing content.
- Functionality that uses dragging (sliders, sortable lists, maps) also works with single taps or
  clicks (2.5.7 Dragging Movements).
- Authentication does not require a cognitive test such as remembering or transcribing a code:
  allow paste and password managers, and offer alternatives to puzzle-style challenges
  (3.3.8 Accessible Authentication (Minimum)).
- Images have appropriate alternative text; decorative images are hidden from assistive technology.
- Dynamic updates are announced where users need them (live regions used sparingly).

## 6. Verification procedure

Use the project's browser-testing tooling (for example Playwright, Cypress, or the framework's
test runner). If none exists, propose one and ask before adding it. Inspect rendered pages, not
only source.

At every representative width, and in landscape for phone and tablet widths where relevant:

1. Horizontal overflow: `document.documentElement.scrollWidth > document.documentElement.clientWidth`
   must be false.
2. Clipped or overlapping content, including sticky and fixed elements.
3. Navigation open, close and focus behavior.
4. Dialogs, drawers and dropdowns stay within the viewport and are dismissible.
5. Forms: labels, validation messages, keyboard and mobile keyboards.
6. Data tables: contained scrolling or alternative layout; no lost columns.
7. Touch target sizes for primary controls.
8. Images scale without distortion or layout shift.
9. Long text, long words and empty, loading and error states.
10. Browser zoom at 200%.
11. Keyboard-only pass and an automated accessibility scan (for example axe) where tooling allows.

Report results per page and width: what was checked, how, what passed, what failed and what was
not verified. Never claim responsive behavior without having inspected it.

## 7. Acceptance criteria template

For each user-facing feature, include in `docs/engineering/IMPLEMENTATION_PLAN.md`:

- Works without page-level horizontal scrolling from 320 to 1920 px.
- Primary workflow completes on a phone-sized viewport using touch only.
- Primary workflow completes using keyboard only, with visible focus.
- Meets WCAG 2.2 AA for contrast, labels, target size and reflow.
- Verified at the representative widths with results recorded in the pull request.
