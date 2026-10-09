# Occam's Razor — Simplicity (with KISS & YAGNI)
> Prefer the simplest design that meets the actual requirement; don't add entities, layers, or features beyond what is genuinely needed.

## What it is
Occam's razor is a problem-solving heuristic attributed to the 14th-century friar William of Ockham, popularly phrased "entities must not be multiplied beyond necessity" (Ockham's own wording: "plurality must never be posited without necessity"). When two explanations account for the facts equally well, prefer the one that introduces the fewest assumptions. It is a *heuristic*, not a proof — it favours the simpler candidate, it does not guarantee correctness.

Translated to software design, the "entities" are the things we add to a system: classes, layers, abstractions, config options, dependencies, services, and features. The razor says: do not introduce any of them unless the current, real requirement forces you to. When two implementations satisfy the requirement equally well, choose the one a reader will understand fastest and that has the fewest moving parts.

Two closely-related engineering principles operationalise this:

- **KISS — "Keep It Simple, Stupid."** A design maxim (popularly traced to Lockheed engineer Kelly Johnson) that systems work best when kept simple rather than made complicated; simplicity should be a key goal and needless complexity avoided. KISS is the razor applied to a *single artifact* — this function, this class, this module.
- **YAGNI — "You Aren't Gonna Need It."** An Extreme Programming mantra (popularised by Martin Fowler / Kent Beck) against building *presumptive features*: capability added now because you anticipate needing it later. Fowler enumerates four costs of ignoring it — **build, delay, carry, repair**. YAGNI is the razor applied across *time* — don't multiply entities for a future that hasn't arrived.

**Essential vs accidental complexity (Brooks, "No Silver Bullet", 1986).** Brooks splits software difficulty in two. *Essential complexity* is inherent to the problem domain — "if users want a program to do 30 different things, then those 30 things are essential." *Accidental complexity* is what engineers themselves introduce and can remove (clumsy tooling, needless indirection, ceremony). The razor's target is **accidental complexity**: you cannot simplify away the problem, but you can refuse to pile on complexity that the problem never asked for. KISS and YAGNI are disciplines for keeping accidental complexity near zero.

## Core tenets
- The default is the simplest thing that could possibly work; complexity must be *earned* by a present, demonstrated need.
- Fewer moving parts (entities, layers, branches, dependencies) is better when behaviour is equal.
- Solve the problem in front of you, not the hypothetical one you imagine for later.
- Distinguish essential complexity (keep it — it's the job) from accidental complexity (remove it).
- Simplicity is measured by the next reader's effort to understand, not by line count or cleverness.
- The razor cuts toward simpler, but it is a tie-breaker among *correct* options — never an excuse to drop a real requirement.

## Why it matters
Every entity you add is carried for the life of the codebase: it must be read, tested, maintained, and reasoned about by everyone who comes after. Fowler's "cost of carry" is the key insight — speculative or needless structure doesn't just cost once to build; it taxes *every future change*. Simpler systems have fewer interactions to go wrong, fewer states to test, and a lower barrier to onboarding. Accidental complexity is the largest controllable drag on a team's velocity, and it compounds silently.

## Violation smells (detectable signals)

### Code & architecture
- An interface, abstract base class, or strategy with exactly **one implementation** and no concrete second use case.
- A configuration option, feature flag, or parameter that **no caller ever sets to a non-default value**.
- Speculative generality: comments or names like "for future use", "in case we need", "generic handler", `*Manager`, `*Factory`, `Abstract*` wrapping a single trivial concrete.
- A layer of indirection (wrapper, adapter, façade, repository) that only forwards calls and adds no behaviour, validation, or substitution point.
- A design pattern (Visitor, Strategy, Observer, dependency-injection container) applied where a plain function, a conditional, or a direct call would read more clearly.
- Premature optimization: caching, pooling, micro-tuning, or hand-rolled data structures added before any measurement showed a problem.
- Deep inheritance hierarchies or excessive parameterisation/generics to handle cases that don't yet exist.
- Multiple ways to do the same thing in the same codebase (parallel abstractions) where one would do.
- Configuration/plugin/extension machinery built before there is a second thing to plug in.

### Project
- A **dependency added for a one-liner** (e.g. a whole library to left-pad a string or check if an array is empty).
- A framework, ORM, message queue, or microservice introduced for a need a single function or a flat file would satisfy.
- A build/codegen/DSL step added to save typing that was never the bottleneck.
- Two libraries pulled in that do substantially the same job.

### Planning / specs
- A plan that **builds for hypothetical future scale** ("so it'll handle 10M users") with no current or near-term evidence of that load.
- Scope creep: deliverables that go beyond the stated goal of the ticket ("while we're in here, let's also make it pluggable").
- Requirements phrased as "should be flexible/generic/configurable" with no named second use case driving the flexibility.
- Architecture decisions justified by "might need it later" rather than a present requirement.

## Good vs bad examples

**1. One-implementation abstraction (KISS / speculative generality)**
```python
# Bad — interface + factory for a single concrete type "in case we swap later"
class PaymentGateway(ABC):
    @abstractmethod
    def charge(self, amount): ...
class StripeGateway(PaymentGateway):
    def charge(self, amount): ...
class GatewayFactory:
    def create(self): return StripeGateway()

# Good — there is one gateway, so use it directly; abstract when a second arrives
def charge(amount): ...   # Stripe call inline
```

**2. Speculative configuration (YAGNI)**
```python
# Bad — knobs nobody asked for; each one is now a tested, documented surface
def export(data, format="csv", compression=None, encoding="utf-8",
           chunk_size=1000, parallel=False, retry_policy=None):
    ...
# Good — the requirement is "export a CSV"
def export_csv(data): ...
```

**3. Dependency for a one-liner (Project)**
```js
// Bad — a package, a version to track, a supply-chain surface
import isEven from "is-even";
if (isEven(n)) { ... }
// Good
if (n % 2 === 0) { ... }
```

## How to apply

### In code review
- For each new abstraction/layer/option, ask: **what present requirement forces this?** If the honest answer is "we might need it", flag it (YAGNI).
- Count implementations behind each interface; one implementation with no concrete second consumer is a smell.
- For each new dependency, ask whether a few lines of plain code would do; weigh the carry cost (updates, security surface) against the saving.
- Prefer the version a newcomer understands fastest. If the "clever" version needs a comment to explain *why it's so complex*, prefer the plain one.
- Treat optimization without a benchmark as accidental complexity until proven otherwise.

### In planning / plan validation
- Tie every structural choice to a stated requirement in the ticket. Strike work justified only by hypothetical future scale or flexibility.
- Push back on "generic/configurable/pluggable" goals that lack a named second use case — defer the abstraction until the second case is real (rule of three).
- Right-size the solution to the *stated* goal; call scope creep out explicitly rather than absorbing it.
- Remember Fowler: making software *easy to change later* (clean code, tests, refactorability) is **not** a YAGNI violation — that is how you safely defer the speculative work.

### The flip side — when simple is TOO simple
The razor breaks ties between *correct* options; it never licenses dropping a real requirement. Watch for over-application:
- **Essential complexity is not optional.** If the domain genuinely needs 30 behaviours, "simplifying" to 25 is a bug, not elegance.
- Don't collapse genuinely distinct concepts into one overloaded function/flag just to reduce entity count — that trades reader-clarity for a lower line count and usually *increases* accidental complexity.
- Don't strip error handling, validation, security, accessibility, or edge-case coverage in the name of "simple." Those are requirements.
- A second real implementation, a measured performance problem, or a confirmed near-term need is exactly when an abstraction or optimization stops being speculative and becomes warranted — apply the razor again, this time it cuts the other way.
- Historical caution (from the razor's own literature): appeals to simplicity have been wrongly used to reject correct-but-complex explanations. Simpler is a *prior*, not a verdict.

## Relationship to other principles
[[convention-over-configuration]], [[least-astonishment]], [[software-philosophies]].

## Sources
- Occam's razor — https://en.wikipedia.org/wiki/Occam%27s_razor
- Yagni — Martin Fowler — https://martinfowler.com/bliki/Yagni.html
- No Silver Bullet (essence and accident / essential vs accidental complexity), Fred Brooks — https://en.wikipedia.org/wiki/No_Silver_Bullet
- KISS (Keep It Simple, Stupid) — A Design Principle, IxDF — https://ixdf.org/literature/article/kiss-keep-it-simple-stupid-a-design-principle
- Do The Simplest Thing That Could Possibly Work (XP/c2 wiki) — http://xp.c2.com/DoTheSimplestThingThatCouldPossiblyWork.html
