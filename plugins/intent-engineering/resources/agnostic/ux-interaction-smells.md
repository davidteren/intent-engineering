# UX interaction smells (greppable)

> one-line essence: if a user can click, type, or submit it, every critical state must
> exist in the code, not only in the happy path.

Experience failures are often **structural** — missing states and non-semantic controls —
not taste. This doc lists greppable / inspectable signals the experience lens uses, so
UX review can approach architecture-pack rigor without inventing pixel scores.

> Calibrated against real Hotwire/Rails apps: ongela on 2026-08-14 (sibling-check,
> framework-default, and error-tier guards) and fizzy on 2026-08-16 (cross-surface
> keyboard paths, reversible-toggle and live-region handling). The guards below come from
> folding those runs' false positives back in. (The dogfood reports live in the
> development repo, not the installed plugin.)

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
  disabled, so it still needs its own guard. A form that opts out with
  `data: { turbo: false }` likewise forfeits the auto-disable. Anywhere the in-flight
  disable is absent, the double-submit gap is real.
- No **focus** style on custom controls (and no visible focus on native ones after CSS reset).
- Focus not moved into a surface that expects it on open: a modal (`role="dialog"` +
  `aria-modal` + a focus trap) or a `role="menu"` (the menu-button pattern moves focus to the
  first item). A plain non-modal **disclosure drawer/panel** that deliberately does not
  autofocus is not a finding — autofocus there often harms screen-reader and mobile users.
  Distinguish a real `role="menu"` widget (focus expected) from a disclosure region (optional).
- Success path with no confirmation when the action is not obvious from navigation alone.
- Drag/gesture-only reordering or state change with **no keyboard path**. Before flagging,
  check whether the same *mutation* is reachable through a different route/view/controller
  (cross-surface equivalence), not just the same widget or file — the keyboard door is
  often elsewhere (a column radiogroup, move-left / move-right buttons).

### Non-semantic / unlabelled controls
- Clickable `div` / `span` / `li` with `onClick` / `click` / Stimulus action and no
  `button` / `a` / `role="button"` (or equivalent native control). Downgrade the
  modal/drawer backdrop-click-to-dismiss layer when a keyboard-equivalent close already
  exists in the same controller (an Escape handler plus an explicit toggle button): that
  is an accepted convenience layer, not a blocked user.
- Icon-only control without accessible name (`aria-label`, `aria-labelledby`, `title`, or
  visually-hidden text). Empty `<button></button>` or `<button><svg></svg></button>`
  with no name.
- Custom toggle/checkbox that does not expose `aria-pressed` / `aria-checked` / native
  input state. Put the state on the actual control, not a wrapper that has no `role`. Do
  not flag individually-tabbable real `<button>`s carrying `role="radio"` / `"checkbox"`
  as broken merely for having many tab stops — escalate only if arrow-key navigation is
  advertised but missing, or operability actually breaks.
- Accessible name that **contradicts the action**: a visually-hidden or `aria-label` verb
  that disagrees with the control's real effect (a `method: :delete` "permanently revoke"
  button whose screen-reader text says "Edit"). Diff the label verb against the nearby
  `method:` / `data-turbo-confirm`.
- Role set in markup, operability added **conditionally** by JS: a hardcoded
  `role="button"` whose `tabindex` and handlers are attached only for some runtime state
  (owner, permission). Other users hear "button" on a control that is unreachable and
  inert. Verify the condition always holds, or move the role next to the behavior.

### Forms & destructive actions
- Submit handler or form without an error-display path. Three tiers, not binary: (a) no
  error path at all; (b) page-level flash only (`role="alert"` / `status`, no per-field
  association) — common in Rails, real but weaker; (c) field-level errors bound to the
  inputs. Flag (a) firmly. Flag (b) as advisory, and only when the validation targets a
  specific field that should carry the message. The sharpest tier-(a) case in Rails is a
  bodyless `head :unprocessable_entity` / `head :too_many_requests` with no
  `render`/`redirect_to ... alert:` on that branch — Turbo (or a native post) then shows a
  blank dead-end page. Grep `head :` on controller form/submit paths.
- Implicit-submit-only control: a form with no visible `<button type="submit">`, submitting
  only via a JS key/paste handler or native Enter. For a form whose single field is a text
  `input`, native Enter submits, so this is mainly a **discoverability / convention** gap
  (one text input plus non-text controls like a `select`, checkbox, or hidden field still
  submits on Enter). But implicit submission does **not** fire when the form has **two or
  more text-entry inputs** (`text`, `search`, `email`, `url`, `tel`, `password`, `number`,
  `date`, and similar single-line types all count), or when the only field is a `textarea` /
  `select` — there the missing button is a real **operability** gap, not just discoverability.
  Score by case.
- Destructive action (`delete`, `destroy`, `remove`, `reset`) without confirm dialog,
  undo, or soft-delete recovery. Raise confidence when a sibling destructive control in
  the same file/scope does confirm and this one does not (local inconsistency). The Rails
  nested-attributes mark-for-delete pattern (a `_destroy` checkbox/button applied on a
  later bulk save) is exempt *only after you verify* the row carries an observable
  pending-delete indication (a strike-through, a "will be removed" label) **and** a clear,
  understandable un-mark control before the save. Technically-reversible-but-invisible does
  not qualify. If the
  markup or JS hides the row, or there is no un-mark path, it is not reversible — keep the
  finding. Also exempt a pure one-click state toggle whose own inverse renders right back
  in place (unsave, unpin, unlike): it is instantly reversible and is not data loss.
- Required fields with no visible required marker and no client/server error association.

### Feedback & progress
- Long-running action (upload, export, multi-step save) with no progress or busy indicator.
- Action that changes server state with no visible result and no navigation change.
- Live-updating region (an ActionCable / `turbo_stream` broadcast target) whose announced
  element does **not persist** across the update: screen-reader users get no signal. The live
  element (`aria-live`, or an implicit `role="status"` / `"alert"` / `"log"`) can be the
  target itself or an ancestor, **as long as that element survives the update** — a target
  that receives `append`/`prepend` and carries `aria-live` is valid. The failure is a
  `turbo_stream.replace` that swaps the live node itself: the new node's `aria-live` does not
  announce, because the region must exist before its contents change. Exception: a
  `role="alert"` / `aria-live="assertive"` region is announced even when freshly inserted or
  replaced (browsers/AT special-case alerts), so do not flag those. Which streams warrant
  announcement: updates the user is waiting on or would otherwise miss — a chat/inbox message,
  a notification, a search/filter result, a status or progress change. Incidental or cosmetic
  streamed updates (reordering, presence dots, view counts) do not need a live region. Grep
  `broadcast_*_to` / `turbo_stream_from` targets, decide if the update is one the user must
  hear, then check that an ordinary live element persists rather than being replaced.
- Fire-and-forget autosave that **cannot observe failure by design** (the response is
  deliberately ignored to avoid clobbering in-flight input): it needs an alternate failure
  signal — a `beforeunload` guard, periodic reconciliation, or a visible "not saved" mark.
  Two real failure modes to check, not just "no spinner": the autosave endpoint must accept
  the request's format (a wrong `Accept` header answered by a `turbo_stream`/`json`-only
  action returns a silent 406 and the edits never persist), and an in-flight save must not
  drop input typed while it is pending. (Grounded in a real fix on a dogfooded app.)

### Stack-thin recognition notes
- **React / TSX:** `onClick` on non-interactive tags; `disabled` missing next to
  `isLoading` / `isPending`; icon buttons without `aria-label`.
- **Hotwire / ERB / Stimulus:** `data-action=.*click` on `div`/`span`; forms without an
  `error` partial or flash; `button_to` destroy without `data-turbo-confirm`; `head :4xx`
  on a form post (dead-end); a `broadcast_*_to` / `turbo_stream_from` update with a missing
  or non-persisting live region; `role` in ERB with behavior added in a Stimulus
  `connect()`; `data: { turbo: false }` forms.
  (Quick greppable pointers — the full carve-outs live in the cards above.)
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
- **Cross-surface & affordance guard** — check the rest of the app, not just the file, but
  keep the two cases distinct. For a *missing keyboard path*: downgrade to ≤50 / advisory
  only when another route or view offers an **equivalent, in-context** keyboard operation
  for the same mutation; a distant or partial alternative does not clear it. For a *thin
  empty state*: a persistent global affordance elsewhere lowers the "only door in"
  severity, but it does **not** excuse a missing empty-state *message* — the user still
  faces a blank panel. Keep it as a finding capped at **confidence 50 (advisory), severity
  P3** — reportable, below the act-now bar, not suppressed at the gate.

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
