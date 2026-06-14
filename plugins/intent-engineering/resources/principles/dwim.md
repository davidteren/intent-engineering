# DWIM — Do What I Mean
> Meet the user's evident intent, not just the literal input — without guessing so hard you surprise them.

## What it is
DWIM ("Do What I Mean") is the design stance that a system should interpret
reasonable-but-imperfect input the way the author obviously intended, rather
than failing on a technicality or demanding ceremony.

**Origin.** Warren Teitelman coined the term and built the first DWIM package
for BBN Lisp (part of his PILOT system) in the late 1960s; it was introduced
into the Lisp environment around 1968 and later became a pillar of the
**Interlisp** programming environment, which Teitelman and Larry Masinter
developed at Xerox PARC. DWIM was effectively a semi-intelligent autocorrect
for programming: when the interpreter hit an unrecognized symbol or a small
syntax/spelling error, DWIM would attempt a correction (often with minimal user
intervention) and let execution continue. Teitelman framed it as part of a
broader "Programmer's Assistant" philosophy: *system facilities should make
reasonable interpretations when given unrecognized input.*

**The criticism that shaped the name.** Skeptics quipped that DWIM was "tuned to
the particular typing mistakes to which Teitelman was prone," re-expanding the
acronym as **"Do What Teitelman Means"** or **"Damn Warren's Infernal Machine."**
That joke is the whole tension in one line: a correction that fits *one* mental
model can be wrong — and astonishing — for everyone else.

**Perl association.** DWIM became a touchstone of Perl's design philosophy. As
*Modern Perl* puts it: "Perl adepts often call this principle DWIM, or do what I
mean. You could just as well call this the principle of least astonishment."
Perl leans on *context* (numeric vs. string vs. boolean; void/scalar/list) to
infer intent — `$a + $b` is treated as arithmetic because you reached for a
numeric operator. The same book names the cost: "This expressivity allows master
craftworkers to create amazing programs but also allows the unwary to make
messes."

**Plain-language restatement.** Be forgiving about *form*, strict about
*meaning*. Accept the input a competent person would obviously consider valid;
infer the obvious; but never silently invent intent the user didn't express.

The balance: **anticipate intent WITHOUT surprising guesswork.** Good DWIM is
invisible because it does what you already expected. Bad DWIM is "clever" — it
does something you didn't ask for and can't easily see or undo.

## Core tenets
- Accept obviously-valid input even when its form is imperfect (whitespace, case, trailing slash, equivalent encodings).
- Infer only the *unambiguous* intent. If two readings are plausible, do not pick one silently.
- Make every inference observable: echo what you assumed, or make it trivially reversible.
- Prefer correct defaults over mandatory configuration — but let the user override.
- Fail loudly on genuine ambiguity instead of guessing. A clear error beats a confident wrong answer.
- Magic is debt: every hidden behavior is something a future reader must already know to not be surprised.
- Destructive or irreversible actions get *less* DWIM, not more. Never guess your way into data loss.

## Why it matters
Software that rejects obviously-valid input on a technicality wastes human time
and trains users to distrust it. But software that guesses too aggressively is
worse: it produces results that look right, hides the assumption it made, and
fails in ways that are hard to trace because nothing visibly went wrong. DWIM
sits on a knife's edge between these two failure modes, and the edge is exactly
where [[least-astonishment]] lives. For an automated reviewer, both edges are
detectable — rigidity shows up as needless rejection; over-magic shows up as
silent inference, especially around coercion, defaults, and irreversible acts.

## Violation smells (detectable signals)

### Too rigid (fails DWIM)
- Rejects input that differs only in case, surrounding whitespace, or a trailing slash (`" Foo "`, `"foo@x.com\n"`, `https://x.com/`).
- Requires a config value, flag, or argument that is deterministically inferable from context (e.g. forcing `--format=json` when the output path ends in `.json`).
- Errors on a near-miss enum/spelling with no suggestion (`"didn't recognize 'utf8'"` instead of accepting it or suggesting `utf-8`).
- Demands exact types where an obvious conversion exists and is safe (rejects the string `"42"` where an int is wanted, in a context where coercion is unambiguous).
- Date/number parsing that only accepts one rigid format and rejects common equivalents.
- Forces the user to repeat information the system already has (re-entering a known email, re-selecting an already-known locale).

### Too magic (DWIM gone wrong — violates least-astonishment)
- Silent type coercion that can hide bugs: `"5" + 3` quietly yields `8` or `"53"` with no signal; `null`/`""`/`0`/`"0"` all collapse to the same branch.
- A function named `get`/`fetch`/`find` that also writes, mutates, creates-on-miss, or caches as a side effect.
- "Helpful" auto-correction of a value the user typed deliberately (auto-pluralizing a table name, rewriting a URL, "fixing" a regex).
- Guessing intent on ambiguous input and committing to it irreversibly (auto-deleting, auto-merging, auto-force-pushing because "you probably meant to").
- Inferred defaults that change behavior across environments without being surfaced (picks prod credentials because `NODE_ENV` was unset).
- Inconsistent return types across branches: returns an object on success, `false` on miss, `null` on error — caller can't tell apart.
- Overloaded one symbol/flag meaning different things in different contexts with no signal which applies.
- "Smart" reformatting/normalization applied silently to user data on save (stripping leading zeros from an ID, lowercasing a case-sensitive token).

### UX / frontend
- Rigid: a phone/card field that rejects spaces, dashes, or parentheses the user naturally typed.
- Rigid: search that returns zero results for an obvious typo with no "did you mean."
- Magic: autocomplete or autocorrect that overwrites a deliberate entry on blur/submit with no undo.
- Magic: a control whose label implies one action but which also triggers another (a "Save" that also publishes).
- Magic: silent destructive defaults (a bulk action that selects "all" when nothing is checked).
- Magic: form silently discards or "cleans" pasted content (strips formatting, truncates) with no notice.

### Planning / specs
- Spec says "be lenient with input" but never enumerates *which* variations are accepted vs. rejected — leaves DWIM scope to chance.
- Spec adds inference/auto-correction but is silent on the ambiguous case and on how the assumption is surfaced to the user.
- Spec introduces a "smart default" without stating the override path or where the chosen value is shown.
- Acceptance criteria cover the happy path only; no case for "obviously-valid-but-malformed" input and no case for "genuinely ambiguous → must error."
- Plan applies the same forgiving behavior to a destructive/irreversible action as to a read — no carve-out for "less magic when stakes are high."

## Good vs bad examples

**1. Forgiving input (good DWIM)**
```python
# bad — rigid: rejects obviously-valid input
def parse_email(s: str) -> str:
    if s != s.strip().lower():
        raise ValueError("email must be trimmed and lowercase")
    return s

# good — normalizes the obvious, still validates meaning
def parse_email(s: str) -> str:
    s = s.strip().lower()
    if "@" not in s:
        raise ValueError(f"not an email address: {s!r}")
    return s
```

**2. Hidden coercion (bad magic) vs. explicit intent (good)**
```javascript
// bad — silent coercion hides the bug; "" + 0 + items.length all collapse
function total(a, b) { return a + b; }      // total("5", 3) === "53"

// good — names the intent, fails the ambiguous case loudly
function total(a, b) {
  if (typeof a !== "number" || typeof b !== "number")
    throw new TypeError("total() expects numbers");
  return a + b;
}
```

**3. Inference surfaced, not silent (good DWIM)**
```bash
# bad — guesses output format silently from nothing, can't tell what it did
$ convert report

# good — infers from the extension AND echoes the assumption
$ convert report.csv
# -> "No --format given; inferred 'csv' from extension. Use --format to override."
```

## How to apply

### In code review
- For each input boundary, ask: does this reject input a reasonable person calls valid? (too rigid) — and: does this infer something the caller didn't state? (too magic).
- Flag every silent coercion and every inferred default. Require it to be either surfaced (logged/echoed/returned) or trivially reversible.
- Check name-vs-behavior: a reader should predict side effects from the name. `get*`/`fetch*`/`find*` must not mutate.
- Require consistent return types across all branches of a function.
- Hold irreversible operations to a higher bar: no guessing, explicit confirmation, no DWIM shortcuts.

### In UX / frontend
- Normalize cosmetic input differences (trim, case-fold, strip separators) before validating — accept what the user obviously meant.
- When the system corrects or infers, show it and offer undo; never silently overwrite deliberate input.
- Keep labels honest: a control does exactly what it says, nothing extra.
- Default selections must never default to a destructive scope.

### In planning / plan validation
- Require specs to enumerate accepted input variants *and* the cases that must still error.
- For any inferred value or smart default: spec must state how it is surfaced and how to override.
- Require an explicit "ambiguous input → fail loudly" rule rather than a silent best-guess.
- Carve out destructive/irreversible flows from forgiving behavior; call the carve-out out by name.

## Relationship to other principles
[[least-astonishment]] (the counterweight — DWIM is the *forgiving* half, least-astonishment is the *no-surprises* half; good DWIM satisfies both), [[convention-over-configuration]] (smart defaults are DWIM applied to setup), [[wysiwyg]] (visible state is the antidote to hidden magic), [[software-philosophies]].

## Sources
- DWIM — https://en.wikipedia.org/wiki/DWIM
- Warren Teitelman — https://en.wikipedia.org/wiki/Warren_Teitelman
- The Medley Interlisp Project: Reviving a Historical Software System — https://interlisp.org/documentation/young-ccece2025.pdf
- The Perl Philosophy (Modern Perl, 4e) — https://www.modernperlbooks.com/books/modern_perl_2016/01-perl-philosophy
