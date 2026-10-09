# Defaults & Configuration
> one-line essence: the best default needs no configuration.

This is the cross-cutting reference where three lenses meet: **convention** (follow the agreed path), **simplicity** (every knob is a cost), and **predictability** (a default must not surprise). A default is a decision the author makes *once* so that every user doesn't re-decide it. The quality of that single decision — and the restraint to not expose it as a knob at all — is what this doc helps a reviewer judge.

## Principles

- **Sensible defaults for the common case.** The most common invocation should require zero configuration. If 90% of callers set the same value, that value should *be* the default, and the flag should only exist to override it. ripgrep made recursive search the default precisely because its author typed `-rn` every single time — "flags should override defaults, not enable them."
- **Convention over configuration.** When desired behavior matches the framework's convention, it should just work, silently. Configuration exists only for the genuinely unusual. (See [[../principles/convention-over-configuration]].)
- **Every config knob is a cost.** A knob is not free flexibility — it is a permanent tax: another combination to test, another line of docs, another support question, another way two environments can silently diverge. Each option roughly *doubles* the configuration state space the system must behave correctly across. The paradox of choice applies to APIs as much as to UIs: more knobs make the common path harder to find and erode satisfaction.
- **Secure / safe by default.** The out-of-the-box configuration must be the safe one. CISA's *Secure by Default* guidance is explicit: the most important protections should be **on by default, at no extra cost or configuration**. The dangerous capability (delete, overwrite, expose publicly, disable verification) is the thing you *opt into*, never the thing you *opt out of*.
- **Defaults match the common case, not the author's test rig.** A default tuned to a dev machine, a single tenant, or yesterday's hardware quietly mismatches production. The default should reflect how the tool is actually used, "not how people used tools in 1976."
- **Make the right thing the easy thing.** The path of least resistance and the correct/safe path should be the same path. If doing it right requires extra flags and doing it wrong is the default, users will do it wrong at scale.
- **The DWIM balance: infer intent without surprising magic.** Smart defaults should *Do What I Mean* — fix the obvious, fill the omitted — but only where the cost of being wrong is low, the inference is unambiguous, and the action is visible/reversible. The DWIM test: *if I'm wrong about what was meant, what's the cost of undo?* Low → infer, but surface it. High → don't infer; require an explicit choice. Beeminder's "Anti-Magic Principle" is the counterweight: prefer "dumb, consistent, predictable" over "impeccably right but surprisingly clever," because magical behavior that occasionally misfires costs more trust than it saves keystrokes.

## Detectable smells (feed the lenses)

### Needless configuration (simplicity lens)
- **A config option no one sets**, or that is always set to the same value across every caller/environment — it isn't flexibility, it's dead weight. Inline the default and delete the knob.
- **Required configuration that could be inferred.** Forcing the caller to specify something derivable from context (a table name from the class name, a path from the project root, a format from the file extension). If the framework *could* know it, it should.
- **A knob added "for flexibility" with exactly one caller** (often the author's own test). Speculative configurability is YAGNI; the second caller can add the knob when they actually exist.
- **Parallel knobs that must agree.** Two options that are only ever valid in one combination — collapse them into one.
- **A config file / env var documented but never read**, or read but with no effect — pure testing-and-docs surface for zero behavior.

### Surprising defaults (predictability lens)
- **A default that does the dangerous thing**: deletes without confirm, overwrites silently, creates a resource *public*, skips TLS/signature verification, binds to `0.0.0.0`, logs secrets. Safety must be the default; danger must be opt-in.
- **A default that differs across environments silently** — dev permissive, prod strict (or vice versa) with no visible signal. The difference must be explicit and reviewed, not emergent from environment detection.
- **Off-by-default safety**: timeouts, retries-with-backoff, input validation, rate limits, auth that are present but disabled unless someone remembers a flag. If it's a safeguard, it should be on by default.
- **Magic that fires invisibly.** A default that auto-corrects, auto-widens, auto-reconnects, or reshapes input *without saying so* — DWIM in the dark. The smell is a behavior the caller can't predict from the call and can't see in the result.
- **A "smart" default that depends on hidden state** (wall-clock time, locale, ambient env, prior call) so the same input yields different output. Same call → same result is the predictability floor.

### Convention available but ignored
- **Bespoke config where a framework convention already exists.** Hand-written wiring (explicit `self.table_name`, a manual route the resourceful router would generate, a custom config loader) for something the framework conventions for free. (See [[../principles/convention-over-configuration]] violation smells.)
- **Non-standard file/dir layout** fighting the framework's expected structure, forcing configuration to point back at where things "should" already be.
- **Reinvented naming / lifecycle** for a thing the platform already names, requiring config to reconcile the deviation.

## Good vs bad examples

**1 — Inferable config (simplicity)**
```python
# bad: caller must spell out what's derivable
load_model(path="model.bin", format="binary", arch="resnet50", device="cpu")

# good: infer from the artifact; override only the unusual
load_model("model.bin")              # format from extension, arch from header, device auto-detected
load_model("model.bin", device="cuda")  # one explicit override, the rest stays silent
```

**2 — Dangerous default (predictability + security)**
```python
# bad: safety is opt-in; the easy call is the unsafe one
def upload(file, visibility="public", verify_checksum=False): ...

# good: safe/common case is the default; danger is explicit and named
def upload(file, visibility="private", verify_checksum=True): ...
upload(f, visibility="public")   # the surprising choice is now visible at the call site
```

**3 — Visible DWIM vs silent magic (DWIM balance)**
```text
bad  (silent): tool sees "modle.bin", quietly opens "model.bin", proceeds. User never told.
good (visible): "no file 'modle.bin'; using closest match 'model.bin'"  → inference surfaced,
                still reversible, matches Teitelman's original DWIM ("using FOOBAR instead").
```

## How to apply (review checklist)

Ask, for each option and each default in the diff:
- **Could this default be inferred?** From the class name, the file extension, the project layout, the runtime context? If yes, infer it and drop the requirement.
- **Is the default the safe and common case?** Would the 90% caller want it? Does it fail *closed* (safe) rather than *open*? Is any destructive/exposing behavior opt-in rather than opt-out?
- **Does this knob earn its keep?** Who is the second caller? How many config combinations does it add to the test matrix and the docs? Could it be deleted by inlining the value everyone uses?
- **Is any inference visible and reversible?** If the code "does what it thinks you meant," does it surface that, and is the cost of being wrong low? If undo is expensive, it should ask, not guess.
- **Do environments differ silently?** Is the dev-vs-prod default difference explicit and intentional, or an emergent surprise?
- **Is the convention being ignored?** Is this bespoke configuration standing in for a default the framework already provides?

## Relationship
[[../principles/convention-over-configuration]], [[../principles/occams-razor]], [[../principles/dwim]], [[../principles/least-astonishment]]

## Sources
- Convention over configuration — Wikipedia — https://en.wikipedia.org/wiki/Convention_over_configuration
- Patterns in Practice: Convention Over Configuration — Microsoft Learn (MSDN Magazine) — https://learn.microsoft.com/en-us/archive/msdn-magazine/2009/february/patterns-in-practice-convention-over-configuration
- Sensible defaults for configuration — Stack Overflow — https://stackoverflow.com/questions/785983/sensible-defaults-for-configuration
- Secure by Design (Secure by Default) — CISA — https://www.cisa.gov/sites/default/files/2023-10/SecureByDesign_1025_508c.pdf
- SA-8(23): Secure Defaults — NIST SP 800-53 / CSF Tools — https://csf.tools/reference/nist-sp-800-53/r5/sa/sa-8/sa-8-23/
- Building CLI Tools: The Forgotten Art of Good Defaults — unixy.io — https://unixy.io/blog/building-cli-tools-good-defaults/
- The Anti-Magic Principle — Beeminder Blog — https://blog.beeminder.com/magic/
- DWIM — Encyclopedia of Agentic Coding Patterns — https://aipatternbook.com/dwim
- Designing something complex? Use smart defaults — UX Collective — https://uxdesign.cc/designing-something-complex-use-smart-defaults-943465a47eff
- The Paradox of Choice — The Decision Lab — https://thedecisionlab.com/reference-guide/economics/the-paradox-of-choice
