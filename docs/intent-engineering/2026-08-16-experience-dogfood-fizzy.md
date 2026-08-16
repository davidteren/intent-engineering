# Experience lens dogfood — fizzy (Hotwire/Rails, second app)

**Date:** 2026-08-16
**Context:** review (experience lens only)
**Scope:** `fizzy` — a large, independently-authored Hotwire/Rails Kanban app (341 ERB views, 63 Stimulus controllers). Three read-only lens passes: boards/cards, forms/destructive/auth, and lists/notifications.
**Intent:** Second calibration of the experience lens. The cards were hardened against a first app (ongela, 2026-08-14); this run tests whether the tightened cards still over-fire on a different author's conventions and scale, and what new interaction patterns a bigger app exposes. Part of issue #23.
**Config:** plugin defaults.
**Product code:** not edited. fizzy is third-party OSS; findings are advisory to its owner and are not filed.

## Why a second app

ongela earned the first five guards. fizzy is the same stack but a different codebase: drag-and-drop boards, inline card edit, real-time notification broadcasts, magic-link auth, and a much larger Stimulus surface. It confirms the ongela guards held and, more importantly, exposes patterns ongela did not have — which is where the new cards come from.

## Confirmed findings (real, in fizzy)

Reported to fizzy's owner; not part of this PR.

| # | File | Issue | Smell | Conf |
|---|------|-------|-------|------|
| 1 | `app/controllers/signups_controller.rb:19` | Invalid signup replies `head :unprocessable_entity` on a `turbo: false` form — the browser lands on a blank dead-end page | error state / dead-end | 100 |
| 2 | `app/controllers/join_codes_controller.rb:37` | Same bodyless-`head` pattern blanks the join-by-code screen | error state / dead-end | 100 |
| 3 | `app/controllers/users/joins_controller.rb:10` | Onboarding uses `update!`; a whitespace-only name passes HTML5 `required` but fails the model, raising an unhandled 500 (a sibling action handles it) | error state | 100 |
| 4 | `app/models/notification.rb:25` | Real-time notification broadcasts prepend to regions with no `aria-live`; screen-reader users get no signal | live region / announce | 100 |
| 5 | `app/views/my/access_tokens/_access_token.html.erb:10` | Revoke button's screen-reader name says "Edit"; the accessible name lies about a destructive action | name/action mismatch | 100 |
| 6 | `app/views/tags/index.html.erb:3` | "All tags" list has no empty state | empty state | 100 |
| 7 | `app/views/my/pins/index.html.erb:12` | `/my/pins` full-page route has no empty state (the tray toggle guards, the route does not) | empty state | 100 |
| 8 | `app/views/events/event/attachments/_attachment.html.erb:6` | Attachment/remote images have no `alt` at all | a11y name | 100 |
| 9 | `app/views/cards/steps/edit.html.erb:13` | Step delete has no confirm while every sibling destroy does | destructive / inconsistency | 75 |
| 10 | `app/views/reactions/_reaction.html.erb:14` | `role="button"` hardcoded for all reactions, but operability is added by JS only for the author | role vs behavior drift | 75 |
| 11 | `app/views/cards/container/_content.html.erb:11` | Draft-card autosave ignores its response **by design** (cannot observe a failure), and its navigate-away submit is not awaited, so a fast navigation can still drop the last edit. A prior merged PR already fixed the earlier 406 / in-flight keystroke loss (see PR-history below); this is the residual design gap | autosave / no failure signal | 75 |
| 12 | `app/views/sessions/magic_links/show.html.erb:11` | Magic-link code entry has no visible submit button (Enter/paste only) | implicit-submit-only | 75 |

## False positives / where the hardened cards still over-fired → the fold-back

Every row below is a place the already-tightened cards mis-fired on fizzy. Each is now guarded.

| Over-fire on fizzy | Why it was wrong | Card change |
|---|---|---|
| Drag/drop reorder flagged as "no keyboard alternative" | The keyboard path is a `role="radiogroup"` of buttons three navigation hops away, in a different controller/route | New drag/gesture bullet: check cross-surface equivalence (same mutation via another route/view), not just the same file |
| Empty-state copy "Drag cards here" flagged for naming only the drag modality | A persistent global "Add a card" button is on the same screen | Cross-surface & affordance guard: a visible global affordance caps the finding to advisory (confidence 50 / P3), reportable not suppressed — and it does not excuse a genuinely missing empty-state *message* |
| `role="radio"` on individually-tabbable buttons flagged as broken | Each option is a real, Tab-and-Enter-operable `<button>`; only the announced pattern differs | Toggle bullet: do not flag many tab stops in `role=radio` unless arrow-key nav is advertised or operability breaks |
| Icon-only buttons using `title:` flagged as unnamed | `title` is a valid accessible name; fizzy leans on it | Icon-only bullet: `title` added to the accepted-name list |
| Reversible unsave/unpin toggles flagged as "destructive without confirm" | A one-click toggle whose inverse renders right back is not data loss | Destructive bullet: second exemption for pure reversible state toggles |
| Mobile unread red dot flagged as color-only signal | The signal is the dot's presence/absence (shape), not its hue | Handled by the "color must be the *only* differentiator" reading; not flagged |

## New smells added (fizzy earned these)

Patterns ongela did not have, now named in the cards:

- **Bodyless error dead-end** — `head :4xx` with no `render`/`redirect_to ... alert:` on a form path (findings 1, 2).
- **Live-updating region with no `aria-live`** — a broadcast/`turbo_stream` target replaced with no announced ancestor (finding 4).
- **Accessible name that contradicts the action** — an sr-only/label verb disagreeing with the real effect (finding 5).
- **Role set in markup, operability added conditionally by JS** — role/behavior drift between server and client render (finding 10).
- **Fire-and-forget autosave that cannot observe failure by design** — needs an alternate failure signal (finding 11).
- **Implicit-submit-only control** — only a key/paste submit path, no button (finding 12).
- **Cross-surface & affordance guard** in the confidence anchors — check other routes/views before scoring a missing keyboard path or thin empty state.

## Coverage

**Reviewed:** boards, cards, columns, reactions, tags, account, users, sessions, signups, join_codes, filters, prompts, client_configurations, my, activities, notifications, events, event_summaries, searches, bar, entropy, plus the Stimulus controllers, controllers, and models needed to confirm each finding. Read-only.

**Held from ongela (no change):** the sibling-consistency, framework-default, and error-tier guards all behaved correctly on fizzy — no regression, and they caught real inconsistencies (steps delete, the onboarding 500).

## PR-history learnings

Beyond reading the current code, I mined fizzy's own merged PR history (the `ie-from-pr-learnings` idea: enforce what human reviewers already fought for). Two findings changed the cards:

- **A merged PR fixed drafted-card autosave** so it persists via JSON and stops dropping keystrokes typed while a save is in flight (the earlier code POSTed with a default `Accept: text/html` to a `turbo_stream`/`json`-only action, getting a silent **406** — edits never persisted). This validates the new "autosave that cannot observe failure by design" smell and sharpened it: the card now names the two real failure modes (wrong request format answered by a silent 406, and in-flight keystroke loss), not just "no spinner".
- **A merged PR deliberately removed input autofocus from the mobile jump menu.** That is the signal that *moving focus in on open* is a **modal** expectation, not a blanket one. The focus bullet now carves out non-modal drawers/menus that intentionally do not autofocus, so the lens will not flag a deliberate choice.

Reverts in the history (e.g. a "Go to board" button in the card perma view, a filter-clear navigation change) confirm the team treats these interaction details as contested design decisions — the kind of context that keeps the lens from flagging intentional choices as defects.

## Verdict

**Second fold-back complete.** The tightened cards held on an independent, larger Hotwire app, and fizzy earned six new named smells plus a cross-surface guard. Two real apps, same dogfood loop the architecture packs used — the experience half is now calibrated, not just principled.
