# Error Handling
> one-line essence: fail loudly, fail early, fail in a way the caller expects

## Principles
Error handling is where the Principle of Least Astonishment is most often
violated, because the surprising path is the one that doesn't run on the happy
day. A caller forms a mental model from the function's name, signature, and
return type; the error path must honour that same model. The recurring failure
is the *silent* failure — code that hits a problem and keeps going as if it
didn't, so the surprise lands somewhere far away, long after the cause is gone.

- **Explicit failures, never silent.** The Zen of Python states it directly:
  "Errors should never pass silently. Unless explicitly silenced." A failure
  must surface — as a raised exception, a returned error value, a non-zero exit,
  a rejected promise — somewhere the caller can see and act on it. Swallowing it
  is the cardinal sin; suppressing it *deliberately and visibly* is fine.
- **Fail-fast vs forgiving (Postel), and when each applies.** A *fail-fast*
  system immediately reports, at its interface, any condition likely to indicate
  a failure (Wikipedia, *Fail-fast system*). The opposite stance is Postel's
  robustness principle: "be conservative in what you do, be liberal in what you
  accept from others." They aren't contradictory once you locate the boundary.
  *Be liberal at the system's outer edge* — tolerate messy human input, optional
  fields, version skew — but *be fail-fast on internal invariants* — a violated
  precondition between your own components is a bug, and the longer it runs the
  worse the corruption. Validate at the boundary; assert in the core.
- **Consistent error model.** Pick one way to signal a given class of failure
  and use it everywhere. Don't have one path raise, a sibling return `-1`, and a
  third return `null` for the same condition — the caller can't write one correct
  handler. One concept, one signal.
- **Preserve context.** An error is a story: what was attempted, with what
  inputs, and the original cause. Wrap-and-rethrow with the cause attached
  (`raise ... from err`, `fmt.Errorf("...: %w", err)`, `new Error(msg, {cause})`)
  so the stack reads top to bottom. Throwing away the cause throws away the
  debugging.
- **Don't mask failures with fallback values.** Returning an empty list, a zero,
  a default config, or `null` to "keep things working" converts a loud failure
  into a quiet wrong answer. The caller can no longer tell "no results" from
  "the query blew up." A fallback is only safe when the absent value is a
  legitimate, expected outcome — not a disguised error.
- **The tension: robustness vs fail-fast — flag it, don't dogmatically pick.**
  Postel's law has drawn sustained criticism: being liberal in what you accept
  lets divergent implementations accrete, ossifies bugs into de-facto protocol,
  and pushes correctness debt downstream (a critique now baked into the IETF's
  own "robustness principle considered harmful" discussions). Fail-fast, pushed
  too far, makes systems brittle to benign variation. The right call is
  contextual: protocol/library boundaries facing many clients lean strict;
  forgiving UX and human input lean liberal. A reviewer's job is to *notice which
  one a given boundary chose* and ask whether it's the right choice there — not
  to enforce one globally.

## Detectable smells (feed the lenses)

### Silent failure (predictability — high value)
- Empty `catch {}` / bare `except:` / `rescue => e` with no re-raise, no log, no
  handling — the error is caught and discarded.
- Returning `null`, `nil`, `None`, `[]`, `{}`, `0`, or a default to hide an error,
  so the caller cannot distinguish "no results" from "the operation failed."
- A swallowed promise rejection: `.then()` with no `.catch()`, an `async` call
  without `await`, a fire-and-forget that never observes its result.
- Logging-and-continuing past a broken invariant: `log.warn("shouldn't happen")`
  then executing the next line as if the impossible state were fine.
- `catch (e) { /* ignore */ }` justified by "this rarely fails" — rare is not
  never, and the one time it fails you'll have no signal.
- Checking a return code and then not acting on the failure branch.
- `on_error: continue` / blanket retry that masks a deterministic error as a
  transient one.

### Inconsistent error model
- The same failure raises in one path, returns an error code in another, returns
  `null` in a third — no single handler can cover it.
- A function that sometimes throws and sometimes returns a sentinel for
  conditions the caller would treat identically.
- An error mapped to the wrong type/class, so it routes to a handler meant for a
  different failure (e.g. a validation error caught as a generic 500).
- Mixing exceptions and error-as-value in one layer with no stated convention —
  callers can't tell which to expect (see Go's "errors are values" stance vs
  exception-based languages; the problem is *mixing*, not the choice).
- HTTP/status semantics misused: returning `200 OK` with an error body, or `404`
  for "server failed to look it up."

### Lost context
- Re-raise without the cause: `raise NewError()` inside an `except` that drops
  the original (`from None` or no chaining), severing the stack trace.
- Generic, contextless message: `throw new Error("error")` / "something went
  wrong" with no inputs, operation, or identifiers.
- Catch-all `except Exception` / `catch (Throwable)` that flattens specific,
  actionable failures into one indistinguishable bucket.
- Stringifying an exception (`str(e)`) and discarding the typed object and stack.
- Crossing a layer boundary without translating the error into that layer's
  vocabulary, leaking implementation detail or losing meaning.

## Good vs bad examples

**Silent fallback hides a failure (language-agnostic).**
```
# BAD: caller can't tell "no user" from "DB unreachable"
getUser(id):
    try:    return db.find(id)
    except: return null          # both paths look identical to the caller

# GOOD: absent is a value; failure is an error
getUser(id):
    row = db.find(id)            # let DB errors propagate
    return row                   # may be null = "not found", a real answer
```

**Lost cause on re-raise (Python).**
```python
# BAD: original traceback and type are gone
try:
    charge(card)
except StripeError:
    raise PaymentError("payment failed")        # cause severed

# GOOD: chain the cause; the stack reads end to end
try:
    charge(card)
except StripeError as err:
    raise PaymentError("payment failed") from err
```

**Liberal at the edge, fail-fast in the core (language-agnostic).**
```
# Boundary: tolerant — accept missing optional field, coerce, default
parseRequest(body):
    name = body.get("name", "").strip()
    if not name: reject(400, "name required")    # explicit, at the edge

# Core: strict — an invalid state here is our bug, so assert loudly
applyDiscount(price, pct):
    assert 0 <= pct <= 100, f"discount out of range: {pct}"
    return price * (1 - pct/100)
```

## How to apply (review checklist)
- No empty/bare catch blocks; every caught error is re-raised, returned, or
  genuinely handled — and any deliberate swallow is commented with why.
- No fallback value (`null`/empty/default/0) standing in for an error the caller
  would want to know about; "absent" is a real outcome, not a disguised failure.
- One consistent signal per failure class across sibling functions and layers.
- Errors carry their cause and context (chained, typed, with the inputs that
  triggered them); re-raises preserve the original.
- Boundaries validate untrusted/human input liberally; internal invariants
  fail-fast (assert/raise) rather than limping on.
- No swallowed async rejections; every promise/future is awaited or has a
  rejection handler.
- Error types map to the handler that's actually meant for them; status codes
  and result types tell the truth.
- Where a boundary chose forgiving-over-strict (or vice versa), the choice fits
  that boundary — flag it if the surprise is unjustified, per least-astonishment.

## Relationship
[[../principles/least-astonishment]], [[../principles/dwim]];
[[../principles/software-philosophies]] (fail-fast, Postel's robustness
principle). DWIM and Postel share a forgiving-input stance; least-astonishment
governs the error path: the failure mode must match what the caller expects.

## Sources
- Fail-fast system — Wikipedia — https://en.wikipedia.org/wiki/Fail-fast_system
- What does "Fail Early" mean, and when would you want to? — Stack Overflow — https://stackoverflow.com/questions/2807241/what-does-the-expression-fail-early-mean-and-when-would-you-want-to-do-so
- Robustness principle (Postel's law) — Wikipedia — https://en.wikipedia.org/wiki/Robustness_principle
- Postel's Law — Laws of UX — https://lawsofux.com/postels-law/
- Avoiding Silent Failures in Python ("Errors should never pass silently") — PyBites — https://pybit.es/articles/python-errors-should-not-pass-silently/
- Errors Are Not Exceptions (Go's errors-as-values convention) — swyx, DEV — https://dev.to/swyx/errors-are-not-exceptions-1g0b
- Conventions for exceptions or error codes — Stack Overflow — https://stackoverflow.com/questions/253314/conventions-for-exceptions-or-error-codes
