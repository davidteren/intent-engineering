# Software Development Philosophies — Index
> How the broader philosophy landscape maps to the four intent-engineering lenses.

This is a cross-reference map, not deep prose. Reviewer agents use it as a
"see also" index: from any well-known software philosophy, find the lens it
informs and the 1:1 principle doc that covers it in depth.

## The four lenses (recap)
- **Predictability** — least-astonishment, DWIM, WYSIWYG. Code/UI behaves the
  way a reasonable person already expects; no hidden surprises.
- **Convention** — convention-over-configuration, framework idiom. Follow the
  established pattern so the next reader isn't surprised by a one-off.
- **Simplicity** — Occam, KISS, YAGNI. Prefer the simplest design that solves
  the actual problem; don't add structure on speculation.
- **Experience** — HIG, look-and-feel, UX. The human-facing surface is
  coherent, learnable, and pleasant.

## Philosophy → lens map

| Philosophy | One-line | Primary lens | Notes |
|---|---|---|---|
| **DRY** (Don't Repeat Yourself) | Each piece of knowledge has a single authoritative representation. | Simplicity | Reduces surprise too: one source of truth means one place to reason about. |
| **KISS** (Keep It Simple) | Favor the simplest design that works over needless complexity. | Simplicity | Core of the Simplicity lens. |
| **YAGNI** (You Aren't Gonna Need It) | Don't build features until actually needed, not on speculation. | Simplicity | In tension with framework convention (see Tensions). |
| **SOLID** | Five OOP design principles for maintainable, change-tolerant code. | Cross-cutting | Umbrella; see components below. |
| — SRP (Single Responsibility) | A module has one reason to change. | Simplicity | Each unit does one thing — echoes Unix philosophy. |
| — OCP (Open/Closed) | Open for extension, closed for modification. | Convention | Extend via established extension points, not edits. |
| — LSP (Liskov Substitution) | Subtypes must be usable wherever the base type is, without surprises. | Predictability | A subtype that breaks the contract is the definition of astonishing. |
| — ISP (Interface Segregation) | Many small client-specific interfaces beat one fat one. | Simplicity | Clients depend only on what they use. |
| — DIP (Dependency Inversion) | Depend on abstractions, not concretions. | Convention | Wiring follows a conventional seam/boundary. |
| **Separation of Concerns** | Split a system into parts that each address one independent concern. | Simplicity | Adjacent to SRP at the system scale. |
| **Law of Demeter** | "Least knowledge" — talk only to immediate collaborators, not their internals. | Predictability | Limits non-local surprises and hidden coupling. |
| **Principle of Least Privilege** | Grant each component only the access it needs, no more. | Cross-cutting (security) | Predictability + Convention: least surprise, conventional security posture. |
| **Composition over Inheritance** | Prefer assembling behavior from parts over deep class hierarchies. | Simplicity | Avoids fragile, surprising hierarchies; flexible reuse. |
| **Fail-fast** | Detect and report errors immediately, don't let bad state propagate. | Predictability | Explicit failure over silent corruption. In tension with Postel (see Tensions). |
| **Worse-is-better** (New Jersey) | Simplicity of implementation/interface wins over completeness; ship and iterate. | Simplicity | Gabriel's framing; favors simple, spreadable designs. |
| **MIT approach** ("the right thing") | Correctness and completeness win even at the cost of simplicity. | Cross-cutting | The counterpoint to worse-is-better; weigh against Simplicity lens. |
| **Unix philosophy** | Do one thing well; compose small tools via clean interfaces. | Simplicity | Composability + SRP at the program level. |
| **Rule of Least Power** | Choose the least powerful language/tool adequate for the job. | Simplicity | W3C/Berners-Lee; more analyzable, more predictable artifacts. |
| **Robustness / Postel's Law** | Be conservative in what you send, liberal in what you accept. | Predictability | Forgiving inputs; directly tensions fail-fast (see Tensions). |
| **Convention over Configuration** | Sensible defaults reduce the decisions a developer must make. | Convention | Core of the Convention lens; Rails-style idiom. |
| **Least Astonishment** (POLA) | Behavior should match what a reasonable user already expects. | Predictability | Core of the Predictability lens. |
| **DWIM** (Do What I Mean) | Anticipate intent and correct/forgive ambiguous input. | Predictability | Forgiving — can tension least-astonishment (see Tensions). |
| **WYSIWYG** | What you see on screen is what you get in the output. | Experience | Direct-manipulation expectation; also predictability for users. |
| **HIG** (Human Interface Guidelines) | Platform-blessed rules for consistent, learnable UI. | Experience | Convention applied to the human surface. |

## Principle docs in this repo
The 1:1 deep-dive docs each of these lenses/philosophies link out to:

- [[least-astonishment]] — Predictability anchor (POLA, LSP, Law of Demeter, fail-fast).
- [[dwim]] — Predictability, forgiving-input flavor.
- [[wysiwyg]] — Experience + Predictability for end users.
- [[convention-over-configuration]] — Convention anchor (OCP, DIP, HIG idiom).
- [[occams-razor]] — Simplicity anchor (KISS, YAGNI, DRY, SRP, Unix, Least Power).
- [[human-interface-guidelines]] — Experience anchor (HIG).
- [[look-and-feel]] — Experience, surface coherence.
- [[ux-design]] — Experience, end-to-end human journey.

## Tensions to be aware of
The lenses are not always in agreement. When two pull in opposite directions, a
reviewer should **flag the tension and name the trade-off** rather than silently
pick a side.

- **DWIM (forgiving/magic) vs Least Astonishment (no surprises).** Guessing the
  user's intent helps until the guess is wrong — then the "magic" is itself the
  surprise. Forgiveness must stay predictable.
- **Robustness / Postel vs Fail-fast.** Accepting liberal input hides defects
  and accumulates ambiguity; failing fast surfaces them early but rejects
  almost-valid input. Choose per boundary: lenient at trust edges, strict
  internally is a common compromise.
- **Simplicity (YAGNI) vs Convention (frameworks).** A framework adds structure
  you don't strictly need yet, which YAGNI would resist — but that structure is
  the convention the next reader expects. Skipping it can surprise more than it
  saves.
- **Worse-is-better vs MIT "right thing."** Simplicity-of-implementation vs
  completeness/correctness. Neither is universally right; name which you're
  optimizing for.

When a change sits on one of these fault lines, the reviewing lens should call
it out explicitly (in code comment or PR note), per the Least-Astonishment
design principle: if you must break an expectation, make the surprise explicit.

## Sources
- List of software development philosophies — https://en.wikipedia.org/wiki/List_of_software_development_philosophies
- The Rise of "Worse is Better", Richard P. Gabriel — https://dreamsongs.com/RiseOfWorseIsBetter.html
- The Rule of Least Power, W3C TAG — https://www.w3.org/2001/tag/doc/leastPower.html
- The Principle of Least Power, Coding Horror — https://blog.codinghorror.com/the-principle-of-least-power/
