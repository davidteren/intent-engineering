# Accessibility (a11y)

> one-line essence: usable by everyone, including keyboard, screen reader, and low-vision users

Accessibility is not a feature bolted on at the end — it is a property of correctly
built UI. Most failures are a small set of repeat offenders: per the 2026 WebAIM
Million, **96% of detected errors** fall into six categories (low-contrast text,
missing alt text, missing form labels, empty links, empty buttons, missing page
language). An automated reviewer that catches these covers most of the real-world
harm. WCAG organizes the rules under **POUR**: Perceivable, Operable, Understandable,
Robust.

## POUR (WCAG) as a checklist

### Perceivable — content can be sensed (seen/heard/read)
- **Text alternatives (1.1.1, A):** every non-text element (`<img>`, icon, chart) has a text alternative, or is marked decorative (`alt=""`).
- **Info & relationships (1.3.1, A):** structure is in the markup, not just visual — real headings, lists, labels, table headers; not faked with bold text or spacing.
- **Contrast (1.4.3, AA):** text ≥ **4.5:1**; large text (≥18.66px bold or 24px) ≥ **3:1**. Non-text/UI parts (1.4.11, AA) ≥ **3:1**.
- **Reflow & resize (1.4.10 / 1.4.4, AA):** usable at 320px width and at 200% zoom with no loss of content or horizontal scrolling.

### Operable — every control can be driven
- **Keyboard (2.1.1, A):** all functionality works from the keyboard alone; no mouse-only actions.
- **Focus visible (2.4.7, AA):** the focused element always has a clear visible indicator (never `outline: none` with no replacement).
- **Focus not obscured (2.4.11, AA):** sticky headers/toolbars must not fully hide the focused element.
- **Target size (2.5.8, AA):** interactive targets ≥ **24×24 CSS px** (Apple/Material recommend ~44px).

### Understandable — behavior and language are predictable
- **Labels & instructions (3.3.2, A):** inputs have visible, programmatic labels; required/format expectations stated up front.
- **Error identification (3.3.1, A):** errors are described in text, point to the field, and are announced — not color-only.
- **Predictable:** language of the page is set (`<html lang>`); focus/context does not change unexpectedly on input.

### Robust — works with assistive tech
- **Name, role, value (4.1.2, A):** every control exposes an accessible **name**, correct **role**, and current **state** (checked/expanded/disabled) to AT.
- **Valid semantics:** prefer native HTML; ARIA only fills gaps and must not lie about role or state.

## Detectable smells (feed the experience lens)

### Keyboard & focus
- Interactive element not reachable by Tab (e.g. clickable `<div>` with no `tabindex`).
- `outline: none` / `outline: 0` with no replacement focus style.
- Focus trap: focus enters a widget (modal, menu) and cannot leave with Tab/Esc.
- Custom control (`role="button"`, `role="tab"`, slider) with no key handlers (Enter/Space/arrows).
- Positive `tabindex` values (`tabindex="3"`) overriding natural DOM order.
- Modal/dialog that does not move focus in on open or restore it on close.

### Screen reader / semantics
- Non-semantic clickable `<div>`/`<span>` used instead of `<button>`/`<a>`.
- `<img>` with no `alt` attribute at all (vs. intentional `alt=""` for decoration).
- Icon-only button with no accessible name (no text, `aria-label`, or `title`).
- Heading levels skipped (h1 → h4) or headings used purely for visual size.
- ARIA abuse: `role` that contradicts the element, `aria-hidden="true"` on a focusable control, redundant `role="button"` on a `<button>`.
- Link/button text that is non-descriptive out of context ("click here", "read more").
- Missing `<html lang="…">`.

### Visual
- Color as the only signal (red text for errors, color-only required fields, link distinguished only by hue).
- Text contrast below **4.5:1** (or **3:1** for large text); UI/icon contrast below **3:1**.
- Touch/click targets smaller than ~**24px** (ideally ~44px) or crowded with no spacing.
- Fixed `px` font sizes or `user-scalable=no` / `maximum-scale=1` that block zoom (breaks Dynamic Type / browser zoom).
- Layout that breaks or scrolls horizontally at 320px width or 200% zoom.
- Motion/animation with no `prefers-reduced-motion` respect.

### Forms & feedback
- `<input>` with no associated `<label>` (no `for`/`id` pairing, no wrapping, no `aria-label`/`aria-labelledby`).
- Placeholder text used as the only label (disappears on input, low contrast).
- Validation error shown only by color/border, not announced (no `aria-live`, no `aria-describedby` link).
- Required fields conveyed only visually (asterisk styling) without `required`/`aria-required`.
- Error summary or toast that is not focused or announced after submit.

## Good vs bad examples

**Icon button needs a name**
```html
<!-- bad: screen reader announces "button" with no purpose -->
<button><svg>…</svg></button>

<!-- good -->
<button aria-label="Close dialog"><svg aria-hidden="true">…</svg></button>
```

**Use the real element, not a styled div**
```jsx
/* bad: not focusable, no role, no Enter/Space, no disabled state */
<div className="btn" onClick={save}>Save</div>

/* good: keyboard + semantics + state for free */
<button type="button" onClick={save}>Save</button>
```

**Label + announced error**
```html
<!-- bad: placeholder-as-label, color-only error -->
<input placeholder="Email" class="has-error" />

<!-- good: real label, error linked and announced -->
<label for="email">Email</label>
<input id="email" type="email" aria-describedby="email-err" aria-invalid="true" required />
<p id="email-err" role="alert">Enter a valid email address.</p>
```

## How to apply (review checklist)

1. **Tab through it.** Can you reach and operate every control by keyboard, in a sensible order, with a visible focus ring? Can you escape menus/modals?
2. **Name, role, state.** Does each interactive element have an accessible name and correct role? Are toggles/expanded/disabled states exposed (not just styled)?
3. **Images & icons.** Every meaningful image has alt text; decorative ones use `alt=""`; icon-only buttons have a label.
4. **Contrast & color.** Text ≥ 4.5:1 (3:1 large), UI ≥ 3:1, and no information carried by color alone.
5. **Forms.** Every input has an associated label; required/format stated; errors are in text, linked, and announced.
6. **Structure.** Logical heading order, native lists/tables, `<html lang>` set.
7. **Zoom & target size.** Usable at 200% zoom / 320px width; targets ≥ ~24px; zoom not disabled.
8. **Prefer native HTML.** Flag custom widgets that reimplement native controls without the keyboard + ARIA contract.

## Relationship
[[../principles/human-interface-guidelines]], [[../principles/ux-design]], [[../principles/look-and-feel]]

## Sources
- WCAG 2.2 Quick Reference (How to Meet WCAG) — https://www.w3.org/WAI/WCAG22/quickref/
- WebAIM Million 2026 (annual accessibility analysis of top 1,000,000 home pages) — https://webaim.org/projects/million/
- WAI-ARIA Authoring Practices — Read Me First — https://www.w3.org/WAI/ARIA/apg/practices/read-me-first/
- Using ARIA (W3C) / First Rule of ARIA — https://www.w3.org/TR/using-aria/
