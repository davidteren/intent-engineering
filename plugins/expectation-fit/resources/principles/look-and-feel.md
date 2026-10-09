# Look and Feel
> An interface's "look" (how it appears) and "feel" (how it responds) must be consistent and coherent, so the product reads as one designed thing rather than a pile of one-off screens.

## What it is
"Look and feel" describes two coupled dimensions of an interface:

- **Look** — the visual surface: color, typography, spacing/layout, iconography, shape, elevation, imagery. This is what the user sees before touching anything.
- **Feel** — the interaction behavior: how controls respond, motion and transitions, timing, feedback, affordances, and the patterns by which the same action is performed across the product. This is what the user experiences when they act.

The two are inseparable. A button can look correct (right color token, right radius) yet feel wrong (no pressed state, no transition, a 1.2s lag before anything happens), and vice versa. The reviewer's job is to judge both — and, critically, the **consistency** of both across the whole product.

**Consistency is the goal; a design system is the mechanism.** A design system is "a complete set of standards intended to manage design at scale using reusable components and patterns" (NN/G). It typically bundles a style guide (brand, type, color, voice, principles), a component library (reusable UI elements with their states), and a pattern library (how components combine for common tasks). Design tokens — named, reusable values for color, spacing, type, radius, motion — are the lowest layer: they let "look" be defined once and referenced everywhere, so a hardcoded `#3B7DF4` is a smell precisely because it bypasses the token that should own that decision.

Consistency has two directions (NN/G heuristic #4):
- **Internal consistency** — the same element, pattern, or action looks and behaves the same way everywhere within the product or product family (Office's shared ribbon across Word/Excel/PowerPoint).
- **External consistency** — the product follows platform and industry conventions users already know (blue underlined links are clickable; a cart icon means purchases; the back button goes back).

**Brief history note.** The phrase entered wide use through 1980s–90s software copyright litigation, where companies argued the *visual appearance and interaction behavior* of a UI was itself protectable. Notable cases: *Broderbund v. Unison* (1986, an early attempt to apply copyright to a product's look and feel), *Lotus v. Paperback* (1987), Xerox v. Apple (1989), and especially **Apple v. Microsoft** (Apple's look-and-feel claim over the Mac GUI ultimately failed, largely due to a license Apple had granted for Windows 1.0) and **Lotus v. Borland** (the First Circuit rejected copyright over UI "feel"). The legal arc mostly closed the door on copyrighting look and feel, but it cemented the term as the standard name for "the visual + behavioral identity of an interface." For a reviewer, the takeaway is only the vocabulary, not the law.

## Core tenets
- **Consistency** — identical elements and actions are styled and behave identically across screens (internal); the product respects external platform/web conventions.
- **Coherence** — the whole product feels designed by one team to one set of decisions, not assembled from mismatched parts.
- **Predictable interaction** — a control behaves the way its appearance and label promise, and the same way every time (ties directly to least-astonishment).
- **Brand alignment** — visuals and tone express a single, intentional identity rather than drifting per page.
- **Token / system fidelity** — values come from the design system (tokens, components), not from per-instance improvisation.

## Why it matters
- **Reduces cognitive load and builds trust.** When the same things look and act the same, users learn the product once and transfer that knowledge everywhere; inconsistency forces them to re-learn each screen and erodes confidence.
- **Usability.** External consistency means users arrive already knowing how to use conventional controls; breaking conventions (a hamburger menu that opens a centered modal instead of a side drawer) confuses people for no benefit.
- **Brand and credibility.** A coherent look signals competence; a patchwork of styles signals neglect and can make a product feel untrustworthy or unfinished.
- **Scale and maintainability.** Tokens and components let a change (new brand blue, new focus ring) propagate everywhere at once; hardcoded one-offs guarantee drift and expensive manual fixes.
- **It is the experience lens.** "Look and feel" is precisely the surface the user judges the product by. A feature can be functionally correct and still fail here.

## Violation smells (detectable signals)

### Visual ("look")
- Inconsistent spacing/padding for equivalent elements (e.g. cards with 12px, 16px, and 20px gaps on the same view) instead of a spacing scale/token.
- Multiple type sizes, weights, or line-heights doing the same job; ad-hoc font sizes not on the type ramp.
- Color values hardcoded (`#3B7DF4`, `rgb(...)`) instead of referencing a token (`--color-primary`); near-duplicate colors that should be one token.
- Mixed icon sets or styles (outline icons next to filled, two different chevrons, an emoji beside a vector icon).
- One-off components that visually duplicate an existing library component instead of reusing it (a bespoke "card" next to the system `Card`).
- Inconsistent border-radius, shadow/elevation, or button heights for the same control type across screens.
- Misaligned grids; elements that almost line up but don't (off-by-a-few-px), implying manual placement rather than layout primitives.

### Behavioral ("feel")
- The same action implemented with different interaction patterns on different screens (delete is a swipe here, a right-click menu there, a trash icon elsewhere) with no reason.
- Identical-looking controls that respond differently in different places (one primary button submits instantly, an identical one opens a confirm dialog) — surprising and inconsistent.
- Jarring or absent transitions: content popping in/out with no motion, or motion that is inconsistent (200ms ease here, 600ms linear there for the same kind of change).
- Missing or inconsistent interactive states: no hover/focus/active/disabled treatment, or states present on some components and absent on others.
- Inconsistent feedback latency or loading treatment (spinner here, skeleton there, nothing on a third action of the same weight).
- Focus, keyboard, and back-button behavior that varies by screen or breaks convention (modal that traps focus on one page, leaks it on another).
- Destructive actions that behave inconsistently (sometimes confirmed, sometimes silent) — a feel + least-astonishment failure.

### Planning / specs
- "Make it modern and clean" (or "sleek," "minimal," "premium") as the *entire* stated design direction — vague, unmeasurable, and a strong AI-slop risk: it invites a generic, trend-default look with no grounding.
- No reference to an existing design system, component library, or token set when one demonstrably exists in the codebase.
- Specs that describe look but say nothing about feel (states, transitions, feedback, error/empty/loading), or vice versa.
- New components proposed without checking whether the system already provides them ("add a dropdown" when a `Select` exists).
- No mention of how the new surface stays consistent with sibling screens (the plan treats the feature as an island).

## Good vs bad examples
- **Color (look).** Bad: a "Save" button styled `background: #2F80ED` inline, while three other Save buttons use `#2D7FEC`, `#2F81F0`, and the token. Good: every Save button uses `<Button variant="primary">`, which resolves to `--color-action` — change the token, all four update.
- **Action pattern (feel).** Bad: removing an item is a swipe-to-delete on the list screen, a right-click "Remove" in the table, and a small "x" with no confirmation in the detail view. Good: removal is one `DangerConfirm` interaction everywhere — same trigger affordance, same confirm step, same toast.
- **Spec (planning).** Bad: ticket says "redesign settings to look modern and clean." Good: "Rebuild settings using the existing `SettingsRow`, `Toggle`, and `Section` components; spacing per the 8px scale; toggles use the standard 150ms ease transition and the system focus ring; match the layout pattern already used in the Account screen."

## How to apply

### In UX / frontend review
- Diff the change against the design system: are colors, spacing, type, radius, and motion coming from tokens/components, or hardcoded? Flag every hardcoded value that a token already covers.
- Hunt for duplicate components — a new element that re-implements something the library provides.
- Check interactive states exist and match siblings: hover, focus, active, disabled, loading, error, empty.
- Compare the same action across screens for pattern consistency (internal); compare conventions against the platform (external).
- Watch transitions/motion: present, consistent in duration/easing, and not jarring.
- Treat any inconsistency as a finding even when each instance is individually "fine" — the cost is in the divergence.

### In planning / plan validation
- Reject "modern and clean" as a sole design direction; require it to name the design system, the components to reuse, and the sibling screens to stay consistent with.
- Require the spec to cover *both* look and feel — including states, transitions, feedback, and the empty/loading/error cases.
- Confirm the plan reuses existing components and tokens before introducing new ones; new system entries should be justified.
- Ask "how does this stay consistent with what already exists?" — if the plan can't answer, that's the gap to flag.

## Relationship to other principles
[[human-interface-guidelines]] — platform conventions are the source of much external consistency, and HIG is the canonical "feel" rulebook for a platform.
[[ux-design]] — look and feel is the surface layer of broader UX; consistency here serves the larger user-journey goals.
[[wysiwyg]] — what is shown should match what is produced/expected; a sibling promise about visual truthfulness.
[[least-astonishment]] — predictable, consistent "feel" is the same demand as least-astonishment: controls behave the way their look and label imply, every time.

## Sources
- Look and feel — https://en.wikipedia.org/wiki/Look_and_feel
- Design Systems 101 (NN/G) — https://www.nngroup.com/articles/design-systems-101/
- Maintain Consistency and Adhere to Standards, Usability Heuristic #4 (NN/G) — https://www.nngroup.com/articles/consistency-and-standards/
- Why UX design consistency matters and how to achieve it (UX studio) — https://www.uxstudioteam.com/ux-blog/ux-design-consistency
- 12 Design System Examples (Figma) — https://www.figma.com/resource-library/design-system-examples/
