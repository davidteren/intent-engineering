# Principle of Least Astonishment (POLA)
> A component should behave the way most users already expect it to — when correctness allows two designs, pick the one that surprises the least.

## What it is
The Principle of Least Astonishment (POLA), also called the Principle of Least
Surprise (POLS), states that a system component should behave in a way that
most of its users expect, and therefore not astonish or surprise them. The
"user" is whoever touches the interface: an end user clicking a button, a
programmer calling an API, or a maintainer reading the code.

**Origin.** An early reference appears in the *PL/I Bulletin* (1967), and the
idea reached formal print around 1972 in the form: "every construct in the
system should behave exactly as its syntax suggests. Widely accepted
conventions should be followed whenever possible." PL/I itself became a
cautionary example — `25 + 1/3` and `1/3 + 25` could yield different results
because of precision-conversion rules, astonishing anyone who assumed addition
was commutative. The principle was later popularized for software interfaces by
Eric S. Raymond in *The Art of Unix Programming*, where he frames it bluntly as
"Do the least surprising thing," and notes the design corollary: if a necessary
feature has a high astonishment factor, it may need to be redesigned.

**Plain-language restatement.** Don't make people stop and go "wait, what?" A
name, a control, or an API call should do the obvious thing. Match the user's
existing mental model instead of forcing them to learn a new one.

## Core tenets
- Behaviour should match the name, label, syntax, and surrounding conventions.
- Reuse what users already know; novelty is a barrier to entry and a learning
  tax. Find functional similarities to tools they already use, and mimic them.
- One concept means one thing, consistently, everywhere it appears.
- Separate commands (that change state) from queries (that only read) — a query
  must not mutate.
- Surprise focuses the user's limited attention on the interface instead of the
  task; minimizing it keeps them on task (Raymond, citing Raskin).
- This is a bias toward convention, not mechanical conservatism — break an
  expectation only with deliberate judgment, and make the break explicit.

## Why it matters
Astonishment is expensive at every stage. In code, a method that violates its
name (a `get` that writes, a flag that does the opposite of its label) breeds
bugs that survive review because the reader trusts the name and never checks the
body. In APIs, surprising behaviour multiplies across every consumer — each one
re-learns the quirk, works around it, or ships the bug downstream. In UX,
surprise causes user errors, lost work, abandoned flows, and support tickets. In
all cases it burns reviewer and maintainer time: the reader must hold the
exception in their head forever, because the code no longer says what it does.

## Violation smells (detectable signals)
### Code & API
- A `get`/`fetch`/`read`/`find` method that also writes, mutates, caches, logs,
  or sends — any hidden side effect behind a query-shaped name.
- A boolean flag or option whose name implies the opposite of its effect
  (e.g. `disableX = true` that enables X; `skipValidation` that runs it).
- Inconsistent return types across branches of one function (returns an object
  on success, `null` on one error, throws on another, `false` on a third).
- Same operation, different conventions in sibling functions (one returns,
  one mutates in place, one does both).
- A function whose result depends on argument order when it conceptually
  shouldn't, or on hidden global/ambient state.
- Overloaded operators or magic conversions that defy arithmetic/type intuition.
- Default values that surprise (default base 8, default timezone UTC vs local,
  default `force: true`); silent fallbacks instead of explicit failure.
- Naming that breaks convention: nouns for verbs, no `is_`/`has_` on predicates,
  `-able` interfaces that aren't, async functions without an async signal.
- A "clever" one-liner where the straightforward version would read as written.

### UX / frontend
- A control whose label doesn't match what it does ("Save" that also publishes;
  "Cancel" that commits).
- A destructive or irreversible action with no confirmation, no undo, and no
  warning.
- Back button, browser refresh, or deep-link that silently loses entered state.
- Keyboard, focus, or tab order that breaks platform convention; Enter/Esc that
  don't do the conventional thing.
- State change with no visible feedback, or feedback that contradicts the result.
- A button that looks like a link (or vice versa); primary action styled as the
  dismiss action.
- Auto-save vs manual-save ambiguity; data silently discarded or silently kept
  against the user's expectation.
- Conventional shortcut (`?` for help, `/` for search, Ctrl+S) repurposed for
  something unexpected.

### Planning / specs
- Behaviour described one way in the spec but named/labelled another in the
  acceptance criteria or UI copy.
- A feature whose required behaviour is itself high-astonishment with no note
  that the surprise is intentional (the redesign corollary is being ignored).
- A new interaction model invented where an established one already covers the
  case.
- Edge cases (empty, error, partial) left unspecified, so each implementer
  picks a different, surprising default.
- Glossary term used with two different meanings across the same document.

## Good vs bad examples
**Language-agnostic — query that mutates.**
```
# BAD: name says read, body writes
getUser(id):
    user = db.find(id)
    user.last_seen = now()   # surprise: a "get" updates the row
    db.save(user)
    return user

# GOOD: split command from query
getUser(id):           return db.find(id)
touchLastSeen(id):     db.update(id, last_seen = now())
```

**Language-agnostic — flag that lies.**
```
# BAD: caller reads "render(safe=true)" as "be safe"
render(html, safe=true)   # ...but safe=true skips escaping. Opposite of expectation.

# GOOD: name encodes the actual effect
render(html, escape=true)
```

**Concrete (JavaScript) — surprising default base, the classic POLA fix.**
```js
// BAD (pre-ES5 behaviour): leading "0" was read as octal
parseInt("08");        // -> 0   (WAT)
// GOOD: state intent; ES5 also fixed the default to base 10
parseInt("08", 10);    // -> 8
```

## How to apply
### In code review
Read the signature, predict the behaviour, then check the body — flag any gap.
Verify `get`/`fetch`/`is`/`has` names have no side effects, return types are
consistent across all branches, flag names match their effect, and defaults are
conventional. If you must keep a surprising behaviour, require a comment that
names the surprise.

### In UX / frontend
Walk each control and ask "does it do what its label promises?" Check that
destructive actions confirm and are reversible, that back/refresh/deep-link
preserve state, that focus and keyboard behave conventionally, and that every
state change is visible. Compare against the platform's established patterns and
prefer them over novel ones.

### In planning / plan validation
Reconcile the described behaviour with the chosen names and labels — they must
agree. Specify edge-case behaviour explicitly so no one fills the gap with a
surprising default. If a feature is inherently astonishing, flag it and either
redesign it or document that the surprise is intentional and why.

## Relationship to other principles
- [[dwim]] — "Do What I Mean" is POLA applied to lenient input handling; both
  aim to match intent, though DWIM can itself astonish if it guesses wrong.
- [[wysiwyg]] — what the user sees should be what they get; a direct UX-side
  expression of least surprise.
- [[convention-over-configuration]] — sensible, conventional defaults are how
  POLA shows up in framework and API design.
- [[software-philosophies]] — POLA sits alongside the broader Unix/interface
  design philosophies that favour predictability over cleverness.

## Sources
- Principle of least astonishment — Wikipedia — https://en.wikipedia.org/wiki/Principle_of_least_astonishment
- Applying the Rule of Least Surprise, *The Art of Unix Programming*, Eric S. Raymond — http://www.catb.org/~esr/writings/taoup/html/ch11s01.html
- Principle Of Least Surprise (PLS) — Principles Wiki — http://principles-wiki.net/principles:principle_of_least_surprise
- APIs and the Principle of Least Surprise — DZone — https://dzone.com/articles/apis-and-the-principle-of-least-surprise
