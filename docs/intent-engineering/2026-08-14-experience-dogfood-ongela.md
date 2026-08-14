# Experience lens dogfood — ongela (Hotwire/Rails)

**Date:** 2026-08-14
**Context:** review (experience lens only)
**Scope:** `ongela` — a real Hotwire/Rails app (97 ERB views, 13 Stimulus controllers). Three read-only lens passes: chat/widget, forms/destructive, and list/dashboard surfaces.
**Intent:** Earn the experience half of the product to architecture-pack parity: run the greppable UX-interaction smells against real code, then fold the false positives back into the smell cards. Closes the remaining ask on issue #23.
**Config:** plugin defaults.
**Product code:** not edited. ongela is the dogfood target, not a change target. Findings are advisory to that app's owner.

## What ran

The `ie-experience-reviewer` lens read `ux-interaction-smells.md` and `accessibility.md`, then inspected the actual views, Stimulus controllers, controllers, and models. Each finding carries a confidence and an explicit false-positive judgment (did a sibling partial, a shared flash, or a framework default already supply the state).

## Confirmed findings (real, in ongela)

These are genuine gaps in ongela, kept after the false-positive check. They are reported to ongela's owner; they are not the point of this dogfood, but they show the cards find real things.

| # | File | Issue | Smell | Conf |
|---|------|-------|-------|------|
| 1 | `app/views/relationships/index.html.erb:57` | "Revoke" invite has no `data-turbo-confirm`, while the sibling "Remove" member button (line 43) does | destructive without confirm | 100 |
| 2 | `app/views/council_sessions/show.html.erb:35` | "Running" deliberation has no progress/auto-poll; only a manual Refresh link | feedback & progress | 100 |
| 3 | `app/views/widget/_widget.html.erb:32` | "Report" tabpanel has no `aria-live` wrapper, unlike the sibling "Ask" panel; screen-reader users hear neither the error nor the success | announced result | 100 |
| 4 | `app/views/budgets/_want_list.html.erb:38` | Goal quick-add `label`/`target` are model-required but carry no required marker | required without marker | 100 |
| 5 | `app/views/registrations/new.html.erb:19` | Required `name` field has no required marker, while the adjacent `email` field does | required without marker | 100 |
| 6 | `app/views/dashboard/_financial_health.html.erb:20` | Fallback copy tells non-admin household members to "set a link in Admin" — an internal instruction they cannot act on | system/real-world match | 75 |
| 7 | `app/views/investments/index.html.erb:28` | Investments list has no explicit empty state, unlike every sibling list view | empty state | 75 |
| 8 | `app/controllers/goals_controller.rb:16` | Failed goal quick-add on the budget sheet redirects with a flash and discards the typed input, unlike the sibling path just below | error state / input loss | 75 |
| 9 | `app/views/obligations/index.html.erb:60` | "Log payment" amount has no required marker and its failure path drops the typed amount/date/note | required + error state | 75 |
| 10 | `app/views/widget/_widget.html.erb:12` | Panel has `role="dialog"` but no modal enforcement (no focus move-in, no trap, no `aria-modal`) | ARIA role vs behavior | 75 |

## False positives → the fold-back

This is the point of the dogfood. Each false positive below is a place a naive card over-fired on real Hotwire code. Every one is now guarded in `ux-interaction-smells.md`.

| Over-fire on ongela | Why it was wrong | Card change |
|---|---|---|
| ~15 `.each` loops flagged as "no empty state" | Most primary lists in the app *do* guard; the signal is the one outlier, not every loop | Empty-state bullet: check the actual zero-item render path first, then use sibling consistency to adjust confidence (not as a precondition) |
| Every `button_to` flagged for "no disabled guard" | Turbo Drive already prevents the double-submit by disabling the control | Disabled/pending bullet: do not flag double-submit on a Turbo form (Turbo auto-disables); Rails-UJS is *not* automatic and needs `data-disable-with`, so verify it there; a missing `turbo_submits_with` is a separate minor feedback advisory |
| Mobile-nav backdrop `div` flagged as non-semantic clickable | An Escape handler and an explicit toggle button already make the drawer keyboard-operable | Clickable bullet: downgrade backdrop-click-to-dismiss when a keyboard-equivalent close exists in the same controller |
| Nested-attributes `_destroy` checkboxes flagged as "destructive without confirm" | The mark-for-delete is visible and reversible before the bulk save | Destructive bullet: exempt only *after verifying* the marked row stays visible and reversible before save |
| Page-level flash forms flagged as "no error path" | A `role="alert"` flash is a real (if weaker) middle tier, not an absence | Error bullet: three named tiers (none / page-flash / field-level); flag page-flash only as advisory |
| Two P3 empty-state edges (household/memberships lists) | A signed-in user always has ≥1 member/household, so the state is unreachable | Covered by the zero-item-path check + framework-default guard |

Two cross-cutting guards were added from these: a **sibling-consistency** rule (a gap is stronger when the app's own convention is locally inconsistent, applied *after* checking the real zero-item/behavior path) and a **framework-default guard** in the confidence anchors (a gap scores ≤25 only when the default is confirmed in effect here — Turbo submit-disable is automatic, but `form_with` errors and native `<dialog>` modality are not).

## Coverage

**Reviewed:** chat, widget, council_sessions, settings, invitations, onboarding, registrations, sessions, budgets, income, obligations, vault_items, waitlist, dashboard, overview, activity, goals, accounts, documents, receipts, investments, vault, relationships, mail_inbox, plus 13 Stimulus controllers and the relevant controllers/models. Read-only.

**Well-calibrated already (no change):** the icon-only-control and non-semantic-clickable cards produced zero false hits on a Rails/ERB stack that leans on `button`/`link_to`/`button_to` — correct behavior, the pattern simply is not present.

## Verdict

**Fold-back complete.** The experience lens ran on a real app, found 10 genuine gaps, and its five most over-firing signals are now guarded against Hotwire/Rails defaults and partial-driven structure. This is the experience half reaching the same dogfood loop the architecture packs used.
