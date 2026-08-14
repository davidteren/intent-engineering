# UX interaction smells (greppable)

> one-line essence: if a user can click, type, or submit it, every critical state must
> exist in the code, not only in the happy path.

Experience failures are often **structural** — missing states and non-semantic controls —
not taste. This doc lists greppable / inspectable signals the experience lens uses, so
UX review can approach architecture-pack rigor without inventing pixel scores.

> Calibrated against a real Hotwire/Rails app (ongela) on 2026-08-14. The sibling-check,
> framework-default, and error-tier guards below come from folding that run's false
> positives back in. See `docs/intent-engineering/2026-08-14-experience-dogfood-ongela.md`.

## Detectable smells

### Missing interaction states
- Interactive control with no **loading** state while async work runs (button that stays
  enabled and unlabeled during fetch).
- List/detail region with no **empty** state (blank panel when length is 0). In
  partial/component-driven apps, check siblings first: flag only when other list views
  in the same directory consistently render an empty state and this one does not. A lone
  `.each` with no adjacent `.empty?` is not enough on its own.
- Form or mutation path with no **error** state (submit fails with no field or form
  message in the UI tree).
- No **disabled** / pending guard while a request is in flight (double-submit). On
  Hotwire (Turbo Drive) and Rails-UJS the framework disables the submitting control by
  default, so a missing `disabled` attribute is not the signal. Check instead for
  `turbo_submits_with` or a loading-label swap; absence of *those* is the real gap.
- No **focus** style on custom controls (and no visible focus on native ones after CSS reset).
- Success path with no confirmation when the action is not obvious from navigation alone.

### Non-semantic / unlabelled controls
- Clickable `div` / `span` / `li` with `onClick` / `click` / Stimulus action and no
  `button` / `a` / `role="button"` (or equivalent native control). Downgrade the
  modal/drawer backdrop-click-to-dismiss layer when a keyboard-equivalent close already
  exists in the same controller (an Escape handler plus an explicit toggle button): that
  is an accepted convenience layer, not a blocked user.
- Icon-only control without accessible name (`aria-label`, `aria-labelledby`, or
  visually-hidden text). Empty `<button></button>` or `<button><svg></svg></button>`
  with no name.
- Custom toggle/checkbox that does not expose `aria-pressed` / `aria-checked` / native
  input state.

### Forms & destructive actions
- Submit handler or form without an error-display path. Three tiers, not binary: (a) no
  error path at all; (b) page-level flash only (`role="alert"` / `status`, no per-field
  association) — common in Rails, real but weaker; (c) field-level errors bound to the
  inputs. Flag (a) firmly. Flag (b) as advisory, and only when the validation targets a
  specific field that should carry the message.
- Destructive action (`delete`, `destroy`, `remove`, `reset`) without confirm dialog,
  undo, or soft-delete recovery. Raise confidence when a sibling destructive control in
  the same file/scope does confirm and this one does not (local inconsistency). Carve out
  the Rails nested-attributes mark-for-delete pattern (a `_destroy` checkbox/button applied
  on a later bulk save): it is visible and reversible before submit, so it needs no
  per-row confirm.
- Required fields with no visible required marker and no client/server error association.

### Feedback & progress
- Long-running action (upload, export, multi-step save) with no progress or busy indicator.
- Action that changes server state with no visible result and no navigation change.

### Stack-thin recognition notes
- **React / TSX:** `onClick` on non-interactive tags; `disabled` missing next to
  `isLoading` / `isPending`; icon buttons without `aria-label`.
- **Hotwire / ERB / Stimulus:** `data-action=.*click` on `div`/`span`; forms without
  `error` partial or flash; `button_to` destroy without `data-turbo-confirm`.
- **CLI UX:** commands that mutate state with no confirmation flag and no dry-run.

## Confidence anchors (experience lens)

- **100** — control/action is in scope and the corresponding state or a11y name is
  demonstrably absent in the same file/component tree.
- **75** — a normal user will hit the gap (submit error, double-click, icon-only).
- **50** — incomplete state set suspected but sibling components may supply it
  (advisory until checked).
- **≤25** — pure visual preference; suppress.
- **Framework-default guard** — before scoring, check whether the stack already supplies
  the state by default (Turbo submit-disable, `form_with` flash/error rendering, native
  `<dialog>`, sibling empty-state partials). A default-covered gap scores ≤25 unless the
  app's own convention is locally inconsistent (a sibling does it, this one does not).

## What this is not

- Pixel-perfect design critique or brand taste.
- Replacing WCAG detail in `accessibility.md` (use both: this doc for interaction
  structure, a11y for POUR).
- A required numeric threshold file (UX stays recognition-first).

## Relationship

[[accessibility]] — name/role/value and keyboard. [[ux-design]] — Nielsen / Norman checks.
[[human-interface-guidelines]] — platform conventions. [[information-architecture]] —
hierarchy and exit paths.

## Sources
- [Nielsen Norman Group — 10 usability heuristics](https://www.nngroup.com/articles/ten-usability-heuristics/)
- [W3C WAI — ARIA Authoring Practices](https://www.w3.org/WAI/ARIA/apg/)
- [WebAIM — Keyboard accessibility](https://webaim.org/techniques/keyboard/)
- [GOV.UK Design System — Error messages](https://design-system.service.gov.uk/components/error-message/)
- [Apple HIG — Feedback / modality](https://developer.apple.com/design/human-interface-guidelines/)
