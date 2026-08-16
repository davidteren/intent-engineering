# UX interaction smells (greppable)

> one-line essence: if a user can click, type, or submit it, every critical state must
> exist in the code, not only in the happy path.

Experience failures are often **structural** — missing states and non-semantic controls —
not taste. This doc lists greppable / inspectable signals the experience lens uses, so
UX review can approach architecture-pack rigor without inventing pixel scores.

> Calibrated against a real Hotwire/Rails app on 2026-08-14. The sibling-check,
> framework-default, and error-tier guards below come from folding that run's false
> positives back in. (The dogfood report lives in the development repo, not the installed
> plugin.)

## Detectable smells

### Missing interaction states
- Interactive control with no **loading** state while async work runs (button that stays
  enabled and unlabeled during fetch).
- List/detail region with no **empty** state (blank panel when length is 0). Check the
  actual zero-item render path first: does the region render a *meaningful* empty state — at
  minimum a message that the list is empty, plus the next action where one applies — via an
  inline branch, a shared empty-state partial, or a component fallback? A bare heading,
  filter bar, or empty wrapper does not count. If nothing meaningful renders, that is the finding. Then use
  sibling consistency to *adjust* confidence — a
  lone outlier among guarded siblings is stronger; a whole directory missing it is a
  broader gap — not as a precondition for flagging.
- Form or mutation path with no **error** state (submit fails with no field or form
  message in the UI tree).
- No **disabled** / pending guard while a request is in flight (double-submit). Keep the
  two concerns separate. Turbo Drive disables the submitting control by default, so on a
  standard Turbo form double-submit is already prevented — do not raise a double-submit
  finding there; a missing `turbo_submits_with` is a separate, minor *feedback* advisory
  (no visible pending state), not a double-submit gap. Rails-UJS does **not** auto-disable:
  it needs `data-disable-with` (or equivalent), so verify that mechanism is present before
  clearing a UJS form. The Turbo auto-disable covers form *submitters* only — a
  state-changing `link_to ... data: { turbo_method: ... }` is not a form submit and is not
  disabled, so it still needs its own guard. Anywhere the in-flight disable is absent, the
  double-submit gap is real.
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
  the same file/scope does confirm and this one does not (local inconsistency). The Rails
  nested-attributes mark-for-delete pattern (a `_destroy` checkbox/button applied on a
  later bulk save) is exempt *only after you verify* the row carries an observable
  pending-delete indication (a strike-through, a "will be removed" label) **and** a clear,
  understandable un-mark control before the save. Technically-reversible-but-invisible does
  not qualify. If the
  markup or JS hides the row, or there is no un-mark path, it is not reversible — keep the
  finding.
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
- **Framework-default guard** — before scoring, check whether the stack *actually*
  supplies the state in this instance, not whether it could. Turbo's submit-disable is
  automatic; but `form_with` does not render errors unless the view does, and a native
  `<dialog>` is modal only when opened with `showModal()`. Score ≤25 (suppress) only when
  you confirm the default is in effect here; otherwise score the gap on its own merits.

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
