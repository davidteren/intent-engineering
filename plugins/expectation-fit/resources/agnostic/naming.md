# Naming
> one-line essence: a name is a promise about behavior — keep the promise.

## Why naming is a least-astonishment problem
A name is the first and most-read piece of documentation a reader meets. Before
they open the body of a function or trace a variable's lifetime, they form an
expectation from its name alone. The name sets a contract: `total`, `isReady`,
`fetchUser`, `save` each tell the reader what to expect — a number, a boolean, a
read, a write. When the behavior behind the name differs from that expectation,
the reader is astonished, and astonishment is where bugs are born. A `getX()`
that quietly mutates state, an `isValid` that returns a string, a `count` that
is actually a list — each forces the reader to stop, distrust the name, and read
the implementation. Every such name taxes every future reader.

Naming is therefore the densest meeting point of two ideas: **convention** (use
the words and shapes the ecosystem already uses) and **predictability** (the
name accurately forecasts behavior). Ousterhout puts it directly: names should
be *precise* and *consistent*; a vague or inconsistent name is a small but
relentless source of complexity, because the reader must hold extra context in
their head to compensate. Clean-code guidance reaches the same place from the
other side: names should *reveal intent* so that a comment becomes unnecessary.
A good name is the cheapest abstraction you can buy.

## Principles
- **Reveal intent.** The name should answer why this exists, what it holds, and
  how it is used — without a comment. If a comment is needed to explain a name,
  the name is wrong.
- **Name == behavior.** The name is a contract. The body must do exactly what
  the name says — no more, no less, no surprises.
- **No hidden side effects in query-shaped names.** `get*`, `fetch*`, `read*`,
  `find*`, `is*`, `has*`, `to*`, `as*` imply *no observable mutation*. Commands
  that change state get verb names: `save`, `update`, `delete`, `apply`. This is
  Command–Query Separation expressed through naming.
- **Consistent vocabulary.** One concept gets one word, everywhere. Don't mix
  `fetch`/`get`/`retrieve`/`load` for the same operation, or `user`/`account`/
  `member` for the same entity. Pick one; use it.
- **Length proportional to scope.** A loop index `i` is fine; a module-level
  export named `d` is not. The wider the scope and the longer the lifetime, the
  more descriptive (usually longer) the name must be. Inversely, very local,
  short-lived names may be short.
- **Avoid encodings / Hungarian.** Don't bake type or scope into names
  (`strName`, `m_count`, `arrUsers`). Modern types and tools carry that; the
  encoding just rots when the type changes.
- **Pronounceable and searchable.** If you can't say it in a code review, rename
  it. Avoid single letters and numeric constants that can't be grepped; a name
  you can search for is a name you can safely change.
- **One concept = one word.** And conversely, don't reuse one word for two
  concepts (e.g. `add` meaning both "append to list" and "sum two numbers").

## Detectable smells (feed the lenses)

### Name/behavior mismatch (predictability lens)
- `get*` / `fetch*` / `load*` / `read*` that also writes, caches destructively,
  increments a counter, or mutates the receiver.
- `is*` / `has*` / `can*` / `should*` returning a non-boolean (a string, an
  object, `null`, a count) — the name promises yes/no.
- `validate*` / `check*` that mutates or coerces its input instead of just
  reporting.
- Plural/singular wrong: `user` holding a collection, or `items` holding one.
- A boolean parameter that flips the meaning of the call (`render(true)`),
  forcing the reader to look up what `true` means at every call site.
- `*Count` / `*Size` / `*Length` that returns something other than a number.
- `create*` / `build*` that returns an existing instance, or `find*` that
  creates one when missing (a `findOrCreate` should say so).

### Convention drift (convention lens)
- The same concept named differently across files: `customerId` here,
  `clientId` there, `userId` elsewhere — for the same value.
- Inconsistent casing within one codebase (`HTTPServer` vs `HttpClient`,
  `user_id` vs `userId` in the same layer).
- Abbreviations used in some places but spelled out in others (`cfg`/`config`,
  `msg`/`message`, `idx`/`index`).
- A name that ignores the ecosystem's established term (calling it `getList`
  where every peer module uses `index`, or `remove` where the framework says
  `destroy`).
- Event/handler naming that breaks the local pattern (`onClick` vs
  `handleClick` vs `clickHandler` mixed in one component tree).

### Vague / misleading (both lenses)
- Catch-all nouns with no specifics: `data`, `info`, `manager`, `processor`,
  `handler`, `helper`, `util`, `temp`, `obj`, `val`, `flag`. They name a role,
  not a thing.
- Name narrower than behavior: `saveUser` that also sends an email and writes an
  audit log — the name hides two of three effects.
- Name wider than behavior: `processPayment` that only validates and never
  charges.
- Disinformation: `accountList` that is actually a `Map`; `xs` that holds one
  element; `whitespace` that includes tabs and newkines but is named `spaces`.
- Noise words that add no information: `theData`, `userObject`, `dataInfo`,
  `valueVariable`.

## Good vs bad examples

```
// 1. Query name, command behavior — mismatch
getActiveUser()        // BAD: also clears the session cache as a side effect
currentUser()          // GOOD: pure read
refreshActiveUser()    // GOOD: separate command for the mutation
```

```
// 2. Boolean-shaped name, non-boolean return
function hasPermission(u) { return u.roles }   // BAD: returns an array
function permissionsFor(u) { return u.roles }  // GOOD: noun for the data
function hasPermission(u) { return u.roles.length > 0 }  // GOOD: real boolean
```

```
// 3. Vague catch-all vs intent-revealing
const data = fetch(url)             // BAD: data of what?
const flag = true                   // BAD: flag for what?
const invoicePdf = fetch(url)       // GOOD
const isOverdue = true              // GOOD
```

## How to apply (review checklist)
- Does the name let me predict the behavior without reading the body? If not,
  flag it.
- Do query-shaped names (`get/fetch/find/is/has/to/as`) avoid all observable
  mutation? Do state changes use verbs?
- Is the return type what the name implies (boolean for `is*`, number for
  `*Count`, collection for plurals)?
- Is this concept named the same way everywhere else in the codebase?
- Is the casing and abbreviation style consistent with its neighbors and the
  ecosystem's conventions?
- Is the name as specific as its behavior — no narrower, no wider? Does it hide
  any side effect?
- Are there catch-all/noise words (`data`, `manager`, `temp`, `flag`, `info`)
  that could be replaced with something specific?
- Is the name length proportional to its scope, pronounceable, and searchable?
- Could a boolean parameter be replaced by two well-named functions or an enum?

## Relationship
[[../principles/least-astonishment]] — a mismatched name is the canonical
surprise. [[../principles/convention-over-configuration]] — consistent
vocabulary and casing are conventions that remove decisions.
[[../principles/dwim]] — names should let callers do what the reader means.
Per-stack naming conventions (casing, idioms, framework verbs): see
`frameworks/*.md` — `frameworks/ruby.md`, `frameworks/rails.md`,
`frameworks/python.md`, `frameworks/typescript.md`, `frameworks/react.md`,
`frameworks/swift-ios.md`.

## Sources
- A Philosophy of Software Design (Ousterhout) — names should be precise and consistent — https://newsletter.techworld-with-milan.com/p/my-learnings-from-the-book-a-philosophy
- A Philosophy of Software Design summary (good names: precise, meaningful) — https://dev.to/markadel/a-philosophy-of-software-design-summary-pk9
- Clean Code Ch. 2, Meaningful Names (intention-revealing, searchable, pronounceable, no encodings) — https://www.fabrizioduroni.it/blog/post/2017/09/11/clean-code-meaningful-names
- Clean Code naming principles (name length proportional to scope) — https://www.bti360.com/clean-code-naming-principles/
- Command–Query Separation (a method is a command or a query, not both) — https://khalilstemmler.com/articles/oop-design-principles/command-query-separation/
- The Art of Unix Programming / Principle of Least Astonishment — see [[../principles/least-astonishment]]
