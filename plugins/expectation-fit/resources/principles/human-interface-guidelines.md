# Human Interface Guidelines (HIG)
> Platform-published rulebooks that make interfaces intuitive, learnable, and consistent — so software behaves the way users already expect.

## What it is
Human Interface Guidelines (HIGs) are software-development documents that give application builders a set of recommendations for designing user interfaces. Their stated aim is to improve the user experience by making interfaces **more intuitive, learnable, and consistent**, usually grounded in human–computer interaction (HCI) research.

Each major platform publishes its own:
- **Apple Human Interface Guidelines** — macOS, iOS, iPadOS, watchOS, etc. Organized around the themes **Clarity, Deference, Depth** and foundational principles including **Consistency, Feedback, and Accessibility**. (Apple may withhold endorsement / App Store privileges for apps that ignore them.)
- **Google Material Design (Material 3 / M3)** — Google's open-source, cross-platform design system. "Foundations" cover accessibility, layout, interaction states, and components.
- **GNOME HIG** — the primary design reference for the GNOME/Linux desktop platform.
- **Microsoft (Fluent Design System / Windows app design)** — guidance for Windows 10/11 app experiences.
- Others: KDE, elementary OS, Xfce; mobile-specific Android and watchOS guides.

These guides differ in visual styling but **converge on the same usability principles**. A useful platform-agnostic synthesis is **Nielsen's 10 usability heuristics** (NN/g), which most HIGs restate in their own vocabulary. A reviewer that doesn't know the exact target platform should evaluate against these shared principles.

## Core tenets (cross-platform)
These hold regardless of platform; treat them as the checkable baseline.

- **Consistency & standards** — same word/control/action means the same thing everywhere; follow platform and industry conventions. (Nielsen #4; Apple "Consistency".)
- **Feedback / visibility of system status** — the system always tells the user what is happening, with timely response to every action. (Nielsen #1; Apple "Feedback".)
- **Affordance & discoverability** — controls look and behave like what they do; important actions and options are visible, not hidden. (Supports Nielsen #6, Recognition over recall.)
- **User control & freedom** — clearly marked exits, undo/redo, cancel; users are never trapped. (Nielsen #3.)
- **Error prevention, and graceful recovery** — eliminate error-prone conditions; when errors happen, explain them in plain language and suggest a fix. (Nielsen #5, #9.)
- **Match the real world** — familiar language and conventions, not internal jargon. (Nielsen #2.)
- **Respect platform conventions** — adopt the host platform's native patterns (back gesture, system menus, navigation model) and adapt across window sizes / displays.
- **Accessibility** — usable by people with low vision, blindness, motor, hearing, or cognitive differences; never rely on a single sensory channel.
- **Flexibility & minimalism** — shortcuts for experts, simple defaults for novices; show only what's relevant. (Nielsen #7, #8.)

## Why it matters
- **Lower learning cost.** Users transfer knowledge from every other app on the platform. Conforming UIs feel "obvious"; non-conforming ones force relearning.
- **Trust and predictability.** Visible status and reversible actions let users act confidently; silent or surprising behavior erodes trust.
- **Reach.** Accessibility and platform conformance widen the audience and, on some platforms, are gating requirements for endorsement or store placement.
- **Reduced support and error cost.** Error prevention and clear recovery cut failed tasks and support load.
- It is the operational backbone of the **experience** review lens: most "this feels wrong" UI feedback traces back to a violated HIG tenet.

## Violation smells (detectable signals)

### UI components & states
- An interactive element (button, list, form, async view) is specified or built **without one of its states**: loading, empty, error, disabled, focus, hover, selected.
- **No feedback after an action** — a click/submit/save with no spinner, toast, state change, or confirmation; long operations with no progress indication.
- **Non-standard control for a standard job** — a custom widget where a native checkbox/select/date-picker/menu is expected.
- **Destructive action without a safety net** — delete/overwrite/irreversible action with no confirm, no undo, and no warning.
- **Inconsistent labels/behaviors** — the same action named differently across screens, or the same word triggering different behavior.

### Platform consistency
- **Ignores platform conventions** — overriding the iOS back/edge-swipe gesture, intercepting the Android system back button, replacing native menus or navigation patterns, fighting the platform's window/resize behavior.
- **Reinvented controls** — bespoke scrollbars, dropdowns, or modals that don't match platform behavior (keyboard, focus, dismissal).
- **Non-adaptive layout** — fixed layout that doesn't adapt across window sizes, orientations, or displays.

### Accessibility
- **Touch targets too small** / hit areas below platform minimums or too close together.
- **No keyboard path** — actions reachable only by mouse/touch; focus order broken or invisible focus ring.
- **Missing labels for screen readers** — icon-only buttons, inputs, or images with no accessible name/alt text.
- **Color-only signaling** — status (error/success/required) conveyed by color alone, with no text/icon/shape; insufficient contrast.

### Planning / specs
- A plan **names a UI feature but omits its states** (no empty/error/loading described).
- A plan adds a UI feature with **no accessibility commitment** (keyboard, labels, contrast, target size).
- A plan introduces a custom control where a **standard platform control** would do, without justification.
- A flow with destructive or irreversible steps but **no mention of confirm/undo**.

## Good vs bad examples
- **Save button (feedback).** Bad: click "Save", nothing visibly changes; the user clicks again, creating a duplicate. Good: button shows a loading state, then a "Saved" confirmation and a disabled/changed state.
- **Delete (control & freedom).** Bad: a small trash icon deletes immediately, permanently. Good: confirm dialog *or* immediate delete with a persistent "Undo" toast.
- **Form error (recovery + accessibility).** Bad: invalid field outlined in red only, with a generic "Error" banner. Good: inline message in plain language next to the field ("Email is missing an @"), an icon plus the color, and focus moved to the first error.

## How to apply

### In UX / frontend review
- For every interactive element, confirm the full **state set** exists: default, hover/focus, active, loading, empty, disabled, error.
- Confirm **every action produces feedback** proportional to its duration; long work shows progress.
- Check **destructive/irreversible** actions have confirm or undo.
- Run the **accessibility pass**: keyboard-only reachable, visible focus, accessible names on icon/inputs, contrast adequate, status not color-only, targets large enough.
- Check **platform fit**: native controls used where expected; platform navigation/gestures/menus not broken; layout adapts.
- Flag **inconsistencies** in naming and behavior against the rest of the product and the platform.

### In planning / plan validation
- When a plan introduces a UI feature, require it to enumerate **states + accessibility commitments**; flag the gap if missing.
- Challenge any **custom control** that replaces a standard one without a stated reason.
- Require **error and recovery** behavior for any flow that can fail or destroy data.
- Treat "respects platform conventions" and "keyboard + screen-reader usable" as **acceptance criteria**, not afterthoughts.

## Relationship to other principles
[[look-and-feel]], [[ux-design]], [[wysiwyg]], [[least-astonishment]].

HIGs are how the abstract goal of [[least-astonishment]] gets operationalized for UI: the conventions a HIG encodes are precisely the expectations a user already holds.

## Sources
- Human interface guidelines (overview, major HIGs) — Wikipedia — https://en.wikipedia.org/wiki/Human_interface_guidelines
- Human Interface Guidelines (Clarity/Deference/Depth; Consistency, Feedback, Accessibility) — Apple Developer — https://developer.apple.com/design/human-interface-guidelines
- Foundations & Accessibility — Material Design 3 — https://m3.material.io/foundations
- 10 Usability Heuristics for User Interface Design — Nielsen Norman Group — https://www.nngroup.com/articles/ten-usability-heuristics/
- GNOME Human Interface Guidelines — https://developer.gnome.org/hig/
- Design Windows apps overview (Fluent) — Microsoft Learn — https://learn.microsoft.com/en-us/windows/apps/design/
