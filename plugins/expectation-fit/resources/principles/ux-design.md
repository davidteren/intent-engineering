# User Experience (UX) Design
> Designing the whole experience of using a product so users can accomplish real goals with the least friction, confusion, or surprise.

## What it is
UX design is a user-centered discipline that defines the entire experience a person has when interacting with a product, service, or company — not just the screen they see. It spans usability, usefulness, desirability, findability, accessibility, and brand perception.

The term "user experience" was coined by Don Norman (cognitive scientist, then at Apple) in the early 1990s. In his words: "I invented the term because I thought human interface and usability were too narrow. I wanted to cover all aspects of the person's experience with the system." The field's roots trace back to human factors and ergonomics research from the late 1940s.

UX is an umbrella that contains, but is broader than, several sub-disciplines:
- **Usability** — can users accomplish goals effectively and efficiently?
- **Information architecture (IA)** — structuring, organizing, and labeling content so it is findable and understandable.
- **Interaction design** — designing how users act and how the system responds, state by state.
- **Visual design** — communicating through color, type, imagery, hierarchy.
- **User research** — interviews, surveys, contextual inquiry, usability testing, A/B testing.
- **Accessibility** — designing for people with disabilities (WCAG: Perceivable, Operable, Understandable, Robust).

UI (the interface layer) is a subset of UX, not a synonym for it.

## Core frameworks (the checkable ones)

### Nielsen's 10 usability heuristics
General principles for interaction design. Each is phrased here as a signal a reviewer can check.

1. **Visibility of system status** — Check: does the UI keep the user informed about what's happening, with timely feedback (loading, progress, saved/unsaved, current location)?
2. **Match between system and the real world** — Check: does it speak the user's language with familiar words/concepts, not internal jargon or codes?
3. **User control and freedom** — Check: is there a clearly marked "emergency exit" — undo, redo, cancel, back — for actions taken by mistake?
4. **Consistency and standards** — Check: do the same words/actions/elements mean the same thing throughout, and do they follow platform and industry conventions?
5. **Error prevention** — Check: are error-prone conditions designed out (confirmation on destructive actions, constraints, sensible defaults) rather than just reported?
6. **Recognition rather than recall** — Check: are options, actions, and needed information visible, so the user doesn't have to remember things across steps/screens?
7. **Flexibility and efficiency of use** — Check: are there accelerators (shortcuts, presets, bulk actions) for experts that stay out of a novice's way?
8. **Aesthetic and minimalist design** — Check: is irrelevant or rarely needed content removed, so it doesn't compete with what matters?
9. **Help users recognize, diagnose, and recover from errors** — Check: are error messages in plain language, precise about the problem, and constructive about the fix (no raw codes)?
10. **Help and documentation** — Check: is help available, searchable, task-focused, and concrete where the design can't be fully self-explanatory?

### Norman's design principles
From *The Design of Everyday Things*. The bridge between intent and action — each maps to a checkable signal.

- **Affordance** — Check: do elements' inherent properties suggest their use (a button looks pressable, a field looks editable)? An object should imply what can be done with it.
- **Signifiers** — Check: are there explicit perceivable cues (labels, icons, placeholder text, visual states) telling the user where and how to act? Signifiers communicate the affordance; affordances alone are often not enough.
- **Feedback** — Check: does every action get an immediate, clear response confirming what happened (and what's next)?
- **Mapping** — Check: is the relationship between a control and its effect natural and spatially/logically obvious (e.g., the right toggle controls the right thing)?
- **Constraints** — Check: are invalid or harmful actions prevented or limited (disabled states, masked inputs, guard rails) to steer correct use?
- **Conceptual model** — Check: does the design project a coherent mental model so the user can predict what will happen? Do names, structure, and behavior reinforce one consistent story?

## Why it matters
Good UX is the difference between a feature that ships and a feature that gets used. Poor experience design produces abandonment, errors, support load, and rework — costs that are invisible in a function-only spec but very real in production. For a reviewer, UX is the lens that catches problems a purely functional review misses: the code is correct, the feature "works," but the user gets stuck, confused, or surprised. Treating UX as checkable signals (not taste) lets reviewers flag concrete, fixable gaps before they reach users.

## Violation smells (detectable signals)

### User flows & states
- A flow that only documents the happy path — no error path, no empty state, no loading state. (Heuristic 1, 9)
- An action with no feedback — the user clicks and nothing visibly changes. (Norman: feedback; Heuristic 1)
- A dead-end screen with no forward action and no way back. (Heuristic 3)
- A destructive action with no undo/confirm. (Heuristic 3, 5)
- A state the user can reach but not leave; missing entry points to a feature that "exists" but is unreachable.
- First-run / zero-data state undefined.

### Information architecture
- No clear content hierarchy — everything looks equally important, so nothing is. (Heuristic 8)
- Unclear what the user sees first, second, third; no primary action per screen.
- Labels and categories that use internal jargon instead of user language. (Heuristic 2)
- Navigation that doesn't tell the user where they are or how to get back. (Heuristic 1, 3)
- Findability gap: content exists but there's no plausible path or search to reach it.

### Forms & input
- No validation feedback, or validation only on submit with a vague "error occurred." (Heuristic 5, 9)
- Required vs. optional fields not indicated. (Heuristic 6)
- Input lost on error — the form clears the user's work after a failed submit. (Heuristic 3, 5)
- Inline errors that don't say how to fix the problem. (Heuristic 9)
- No affordance/signifier for interactive elements (a clickable thing that doesn't look clickable). (Norman: affordance, signifiers)
- Disabled controls with no explanation of why or what unlocks them. (Norman: constraints + Heuristic 9)

### Planning / specs
- Feature described by function but not interaction: "users can filter results" — but how? what controls, what defaults, what happens with zero matches? (interaction-state coverage gap)
- "User-friendly" / "intuitive" / "clean UX" asserted with no specifics. (vague, unmeasurable)
- Interaction states marked TBD, or only the success state specified.
- No mention of empty, loading, error, or permission-denied states.
- Accessibility unaddressed (keyboard, focus, contrast, labels).
- Unresolved decisions hidden as prose ("we'll figure out the layout later") instead of flagged as open.

## Good vs bad examples
- **Bad:** "Add a delete button." → **Good:** "Delete shows a confirm dialog; on confirm, the row animates out and a toast offers Undo for 5s; on failure, the row stays and an inline error explains the cause." (covers feedback, error recovery, user control)
- **Bad spec:** "Users can search their orders." → **Good spec:** "Search field with placeholder 'Search by order # or item'; shows results live; empty query shows recent orders; no matches shows a 'No orders match' empty state with a clear-filters action; errors show a retry." (interaction-state coverage, IA, findability)
- **Bad UI:** A gray rectangle labeled "OK" that is actually disabled until a hidden condition is met. → **Good UI:** The button is visibly disabled with helper text "Enter a valid email to continue," satisfying constraints + error diagnosis.

## How to apply

### In UX / frontend review
- Walk every flow through all states: empty, loading, partial, success, error, permission-denied, offline. Flag any missing.
- Run the screen against Nielsen's 10 and Norman's 6 as a checklist; cite the specific heuristic/principle for each finding.
- Verify every interactive element has an affordance and a signifier, and every action produces feedback.
- Check destructive/irreversible actions for confirm + undo (user control & freedom).
- Check forms: required indicators, inline validation, fix-oriented errors, input preserved on failure.
- Check IA: one clear primary action per screen, a visible "you are here," user-language labels.
- Check a11y basics: keyboard reachable, visible focus, sufficient contrast, labeled controls.

### In planning / plan validation
Rate the plan/spec along these dimensions and surface low scores as actionable gaps:
- **IA** — Is content hierarchy and the "what does the user see first/second" defined?
- **Interaction-state coverage** — Are empty/loading/error/success/edge states all specified, not just the happy path?
- **Flow completeness** — Does every flow have entry points, a forward path, an exit, and error/undo handling?
- **Accessibility** — Are keyboard, focus, contrast, and labeling addressed?
- **Unresolved decisions** — Are open interaction questions explicitly flagged (not buried as vague prose or silent TBDs)?
A spec that describes only function ("users can X") without interaction detail should score low on interaction-state coverage and flow completeness, regardless of how complete the functional description is.

## Relationship to other principles
[[human-interface-guidelines]], [[look-and-feel]], [[wysiwyg]], [[least-astonishment]], [[dwim]].

## Sources
- User experience design — https://en.wikipedia.org/wiki/User_experience_design
- 10 Usability Heuristics for User Interface Design (Nielsen Norman Group) — https://www.nngroup.com/articles/ten-usability-heuristics/
- Who is Don Norman? / fundamental design principles (Interaction Design Foundation) — https://www.interaction-design.org/literature/topics/don-norman
- What are Affordances? (Interaction Design Foundation) — https://www.interaction-design.org/literature/topics/affordances
- What is Information Architecture (IA)? (Interaction Design Foundation) — https://www.interaction-design.org/literature/topics/information-architecture
