# WYSIWYG — What You See Is What You Get
> The representation a user or developer sees must equal the actual result or state — no hidden divergence between preview and reality.

## What it is
WYSIWYG ("what you see is what you get") originally described editing software that lets a
user manipulate content so it "resembles its appearance when printed or displayed as a
finished product," without memorizing formatting commands or markup tags.

**Origin.** The first program generally credited with WYSIWYG editing is **Bravo**,
developed at **Xerox PARC** in 1974 by Butler Lampson, Charles Simonyi, and colleagues. It
displayed text on screen with real formatting — justification, proportional spacing, fonts.
The phrase itself was popular slang (Flip Wilson's "Geraldine" character, 1969) appropriated
by PARC engineers. Commercial milestones followed: HP's BRUNO (1978), WordStar (1981), and
Apple's LisaWrite (1983) / MacWrite (1984), which brought WYSIWYG editing to personal
computers.

**The hard part, even in 1974.** Perfect fidelity is elusive. Screen resolution (~72 PPI)
differs from print (300+ PPI), so "one occasionally finds characters and words that are
slightly off." This honesty about imperfect fidelity produced jokey variants like
WYSIMOLWYG ("what you see is **more or less** what you get").

**The generalized principle.** Beyond editors, WYSIWYG is a consistency contract: **the
representation shown == the actual result or state**. A preview equals the saved artifact. A
dry-run equals the real run. The optimistic UI equals what the server will confirm. The
mockup equals what ships. When the shown thing and the real thing diverge silently, the
principle is violated — regardless of whether any "editor" is involved.

**Contrast — WYSIWYM** ("what you see is what you *mean*"). WYSIWYM deliberately shows
*semantic structure* (heading, citation, section) rather than final pixels, deferring
appearance to stylesheets (LyX, LaTeX, TeXmacs, WYMeditor). It is not a violation of
WYSIWYG — it is a *different, explicit contract*: the user sees meaning, not rendered output,
and knows it. The danger is a tool that *claims* WYSIWYG (promises pixel fidelity) but
silently behaves like WYSIWYM (output differs). Choose one contract and make it honest.

## Core tenets
- **What is shown is what will happen.** The preview, render, or status reflects the real,
  committed result — not an idealized or stale approximation.
- **No hidden divergence.** Any gap between representation and reality is surfaced
  explicitly (a "pending" badge, a diff, a "preview only" label), never concealed.
- **Single source of truth.** The thing displayed is derived from the same state that
  governs the actual outcome, not a parallel copy that can drift.
- **Round-trip integrity.** What you see, save, and reload is what you saw — formatting,
  precision, and structure survive the trip.
- **Honest fidelity.** When perfect fidelity is impossible (resolution, async, environment
  differences), the residual gap is named, not pretended away.

## Why it matters
Divergence between representation and reality is a trust failure and a defect generator.
Users make decisions based on what they see; when the real state differs, they ship the
wrong thing, lose data, or distrust the tool. Developers reason about systems through
previews, logs, and dry-runs; when those lie, debugging time explodes and "works on my
preview" bugs reach production. WYSIWYG fidelity is what lets both groups *act on the
representation directly* instead of second-guessing it.

## Violation smells (detectable signals)

### Code & state
- A **preview / render endpoint** uses a different code path, template, or data than the
  **save / publish** path — they can diverge and there is no test asserting they match.
- **Optimistic UI** updates local state and shows success, but there is no rollback on
  server rejection — the screen keeps "lying" after the request fails.
- A **`--dry-run` flag** that builds its plan differently from the real execution (e.g.
  dry-run skips a filter the real run applies), so the printed plan ≠ what actually runs.
- A "**what will be deleted/changed**" summary computed from a stale or cached snapshot
  rather than the live state the operation will act on.
- A `format`/`getDisplayValue` function that **rounds or truncates** for display while the
  stored/computed value is different, with no indication the shown value is lossy.
- Diff/preview generated client-side while the server applies its own normalization
  (whitespace, ordering, escaping) — committed result differs from the shown diff.
- Cached or memoized render not invalidated when the underlying state changes → screen
  shows a result that no longer matches reality.

### UX / frontend
- **Edit view differs from published view** (different CSS, fonts, container width), so the
  author cannot trust the editor to predict the reader's experience.
- **Truncated display** (`text-overflow: ellipsis`, cut-off cells, `…`) hides the real value
  with no tooltip, expand, or copy-of-full-value affordance — the user cannot see what they
  have.
- **Formatting lost on save**: pasted/typed content (lists, links, line breaks, emoji) looks
  right in the editor but is stripped or mangled after submit/reload.
- A **success toast** appears before the operation is confirmed; the item later vanishes or
  reverts because the write actually failed.
- **Placeholder vs value** confusion — greyed placeholder text reads like a real entered
  value, so the user thinks data is present when the field is empty.
- A progress bar / spinner that completes while the real job is still running (fake
  progress), implying a done state that isn't true.
- WYSIWYG editor produces markup the published renderer interprets differently (e.g. nested
  block elements collapsed), so authored layout ≠ rendered layout.

### Planning / specs
- **Mockups that cannot be faithfully implemented as specified** — pixel-perfect comps using
  fonts, spacing, or interactions the chosen framework/component library cannot reproduce, so
  the shipped UI necessarily diverges from the approved design.
- A spec/acceptance criterion describes a screenshot or prototype state that depends on data
  or timing the real system never produces (e.g. a populated empty state).
- A plan's "expected output" sample was hand-written and never round-tripped through the
  actual tool, so it silently differs from what the tool emits.
- Design tokens in the mockup (exact hex, exact px) that don't map to the design system's
  scale, guaranteeing a gap between comp and build.

## Good vs bad examples

**1. Preview vs publish (CMS / markdown)**
- *Bad:* Preview pane renders markdown with the editor's bundled CSS; the public page uses
  the site theme. Authors approve content that looks broken once live.
- *Good:* Preview renders inside the *same* template and theme as the published page (same
  component, same stylesheet), so the preview is a faithful proxy for the result.

**2. Optimistic UI on a "like" button**
- *Bad:* Click increments the count and shows it filled; the POST fails 500; the count stays
  incremented until a hard refresh. The UI permanently disagrees with the server.
- *Good:* Click optimistically fills + increments, but on failure it rolls back to the prior
  state and surfaces a brief error within ~2s. State shown always reconverges to truth.

**3. CLI dry-run**
- *Bad:* `deploy --dry-run` prints "would update 3 services" by listing the config files;
  the real deploy reads live cluster state and updates 5. The dry-run misled the operator.
- *Good:* `--dry-run` runs the identical planning code as the real run and only stubs the
  final apply call, so the printed plan is exactly what execution would do.

## How to apply

### In code review
- Ask: **is the thing shown derived from the same source as the thing done?** Flag any
  preview/dry-run/summary that uses a separate code path from the real operation.
- Require optimistic updates to have an explicit rollback/reconcile path on failure; reject
  "fire-and-forget then show success."
- Treat display-side rounding/truncation as lossy: require a way to reach the full/exact
  value, or a clear marker that the display is abbreviated.
- Ask for a test that asserts **preview output == committed output** (or dry-run plan == real
  plan) for at least the common cases.

### In UX / frontend
- Verify the **edit surface matches the consumption surface** (same fonts, widths, theme).
- Ensure truncation, placeholders, and skeletons cannot be mistaken for real values or a
  finished/true state; progress must reflect actual progress.
- Confirm a full round-trip: type/paste → save → reload renders identically. No silent
  stripping of formatting or precision.
- Make any unavoidable gap explicit ("Preview — final layout may vary", "Pending sync").

### In planning / plan validation
- Validate mockups against the real component library and rendering constraints *before*
  sign-off; name anything that can't be reproduced faithfully as an explicit deviation.
- Require "expected output" samples in specs to be generated by the actual tool, not
  hand-authored, so the spec's WYSIWYG promise is real.
- Where fidelity is genuinely impossible, document the residual divergence rather than
  implying pixel/behavior parity.

## Relationship to other principles
- [[least-astonishment]] — WYSIWYG is the *fidelity* face of least astonishment: the result
  matches the shown representation, so the user is never surprised by divergence.
- [[dwim]] — "Do What I Mean" concerns intent→action; WYSIWYG concerns representation→result.
  A tool can do what you mean yet still misrepresent the outcome (and vice versa).
- [[look-and-feel]] — consistent look-and-feel across edit/preview/published surfaces is a
  precondition for the edit view to faithfully predict the final view.
- [[ux-design]] — WYSIWYG fidelity is a concrete, testable UX property: previews, status, and
  feedback must reflect true state.

## Sources
- WYSIWYG — https://en.wikipedia.org/wiki/WYSIWYG
- WYSIWYM — https://en.wikipedia.org/wiki/WYSIWYM
- What You See is What You MEAN (WYSIWYM) — Scenari — https://scenari.software/en/co/wysiwym.xhtml
- Forget WYSIWYG editors—use WYSIWYM instead — 456 Berea Street — https://www.456bereastreet.com/archive/200612/forget_wysiwyg_editors_use_wysiwym_instead/
- Being optimistic in UI — Front-End Weekly (Medium) — https://medium.com/front-end-weekly/being-optimistic-in-ui-e921d3b2d8d5
