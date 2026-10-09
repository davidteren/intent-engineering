# Swift / iOS — Conventions
> Clarity at the point of use, value types by default, optionals over crashes — and UI that behaves the way Apple's platform conventions already trained users to expect.

## Naming (Swift API Design Guidelines)

The overriding goal is **clarity at the point of use** — code is read far more than written, and clarity beats brevity (though redundant words still hurt).

- **Case:** types and protocols `UpperCamelCase`; everything else (methods, properties, vars, enum cases, functions) `lowerCamelCase`. Treat acronyms as words and match surrounding case: `utf8Bytes`, `isRepresentableAsASCII`, `userID`.
- **Name by role, not type:** `var greeting = "Hello"` not `var string`; `func restock(from supplier: WidgetFactory)` not `from widgetFactory`.
- **Omit needless words:** every word at the call site must carry weight. `allViews.remove(cancelButton)` not `allViews.removeElement(cancelButton)` — the type already says it is an element.
- **Argument labels read like English phrases.** Use prepositions as labels when they form a grammatical phrase: `x.insert(y, at: z)` ("insert y at z"), `x.removeBoxes(havingLength: 12)`. Omit the first label when the base name already implies the role: `view.addSubview(y)`. Keep a label when meaning would be ambiguous: `view.dismiss(animated: false)`.
- **Booleans read as assertions** about the receiver: `x.isEmpty`, `line1.intersects(line2)`, `subview.isHidden`. Prefer `is`/`has`/`can` prefixes.
- **Mutating / nonmutating pairs** follow grammar so both read naturally:
  - verb-based: `x.sort()` mutating, `x.sorted()` nonmutating (past participle)
  - with object: `s.stripNewlines()` vs `t.strippingNewlines()` (present participle)
  - noun-based: `y.formUnion(z)` mutating, `y.union(z)` nonmutating (`form` prefix)
- **Factory methods** begin with `make`: `iterator.makeIterator()`. The first argument should not form a phrase with the base name — `factory.makeWidget(gears: 42)` not `makeWidget(havingGearCount:)`.
- **Protocols** describing what something *is* are nouns (`Collection`); those describing a capability use `-able`/`-ible`/`-ing` (`Equatable`, `ProgressReporting`).

## Idiomatic Swift (what a Swift dev expects)

### Optionals
Optionals model "value may be absent" in the type system — lean on them rather than fighting them.

- Unwrap with `guard let` (early-exit, keeps the happy path unindented) or `if let`. Swift 5.7+ shorthand: `guard let user else { return }`.
- Provide defaults with nil-coalescing: `let name = user.name ?? "Anonymous"`.
- Chain with optional chaining: `user?.profile?.avatarURL`.
- **Avoid force-unwrap `!`** except where absence is a genuine programmer error you want to trap loudly (and even then, prefer a `guard` with a clear message). `!` in production paths is a latent crash.
- Avoid implicitly-unwrapped optionals (`var foo: Foo!`) outside of `@IBOutlet` and a few init-ordering cases.

### Value vs reference types
- **Default to `struct`** (and `enum`). Value semantics give predictable copy-on-assignment, thread-safety by isolation, and no aliasing surprises. The standard library is value-types-first (`Array`, `String`, `Dictionary`).
- Reach for `class` only when you genuinely need reference semantics: shared mutable identity, inheritance, Objective-C interop, or a single source of truth observed by many (e.g. an `@Observable` model).
- Make value types `Equatable`/`Hashable`/`Codable` via synthesis where it adds value.

### Error handling
- Use `throws` / `try` for recoverable failures; define a domain `enum SomeError: Error`. Catch with typed `do/catch`, or convert to `Result` at boundaries where you want to defer handling.
- `try?` (→ optional) and `try!` (traps) are conveniences — `try!` only when failure is impossible by construction.
- Model exclusive states with **enums + associated values** instead of multiple optional/boolean fields: `enum LoadState { case idle; case loading; case loaded([Item]); case failed(Error) }`. This makes illegal states unrepresentable.

### Concurrency (brief)
- Prefer **`async/await`** over completion handlers and over raw GCD for new code; use `Task { }` to bridge sync→async.
- UI-touching code must run on the main actor — annotate view models / UI types with **`@MainActor`** rather than manually hopping with `DispatchQueue.main.async`.
- Protect shared mutable state with an **`actor`**; actor isolation prevents data races at compile time. Mark cross-boundary types `Sendable`.

## SwiftUI / UIKit & HIG expectations (experience lens)

### State management (iOS 17+ `@Observable` model)
SwiftUI's view "body" is a pure function of state; you describe the UI for a given state and the framework diffs and re-renders. Use the right property wrapper for ownership:

| Wrapper | Use for |
|---|---|
| `@State` | Local, view-owned mutable data — simple values *and* `@Observable` instances created by the view |
| `@Binding` | A read-write reference to state owned by a parent; pass with `$value` |
| `@Observable` (macro) | Marks a model class; properties are auto-tracked. Replaces `ObservableObject` + `@Published` |
| `@Bindable` | Create `$model.property` bindings to an observable passed in (replaces `@ObservedObject` for editing) |
| `@Environment(Type.self)` | App-wide shared models / settings injected via `.environment(_:)` (replaces `@EnvironmentObject`) |

Legacy (iOS ≤16) `ObservableObject`/`@StateObject`/`@Published`/`@EnvironmentObject` still work, but new code on iOS 17+ should use `@Observable`. Keep view bodies cheap and side-effect-free; do work in `.task`/`.onChange`, not during body evaluation.

### HIG essentials
- **Use standard platform controls** (`NavigationStack`, `List`, `TabView`, `.sheet`, `Button`, `Toggle`) — they come with accessibility, Dynamic Type, dark mode, and platform behavior for free.
- **Navigation patterns:** hierarchical push/pop via `NavigationStack`; flat sections via `TabView`; modal/transient via sheets. Respect the system back gesture and back button.
- **Accessibility is not optional:**
  - **Dynamic Type** — use semantic text styles (`.body`, `.headline`) not fixed point sizes; layouts must survive text scaling up to ~200%.
  - **VoiceOver** — every meaningful/interactive element needs a clear `accessibilityLabel`; group and order logically.
  - **Touch targets ≥ 44×44 pt** (Apple's recommended minimum).
  - **Color contrast** — 4.5:1 for body text, 3:1 for large (18pt+); never convey state by color alone (pair with icon/text).
  - **Reduce Motion / Reduce Transparency** — honor `accessibilityReduceMotion` and offer calmer alternatives.

## Convention violation smells (detectable)

**Code:**
- Force-unwrap `!` on a value that can realistically be `nil` (crash waiting to happen).
- Force-try `try!` on a call that can actually throw.
- `class` used where a `struct` would fit (no identity/inheritance/sharing need) — or vice versa.
- Non-idiomatic naming: `get`-prefixed pure accessors, type names in argument labels, non-asserting booleans (`var visible` instead of `isVisible`), `NSObject`-era prefixes.
- Reference cycles: a closure or delegate strongly capturing `self` without `[weak self]` (esp. in `Task`, Combine sinks, escaping closures).
- UI mutated off the main thread / outside `@MainActor` (`DispatchQueue.main.async` sprinkled to "fix" crashes is a smell of missing isolation).
- Heavy work or side effects inside a SwiftUI `body`.

**Experience:**
- A custom-built control that reimplements a standard one (custom switch, custom nav bar) without reason.
- Missing accessibility labels / no Dynamic Type support / hard-coded fonts.
- Fighting platform navigation (blocking the swipe-back gesture, custom modal dismissal that breaks expectations).
- Tap targets below 44pt; state communicated only via color.

## Least-astonishment traps specific to Swift/iOS

- **Force-unwrap crash:** `let url = URL(string: userInput)!` crashes on any malformed input. Unwrap and handle.
- **Implicitly-unwrapped optionals** (`var x: Thing!`): look like ordinary values but crash silently when accessed before assignment.
- **UI update off the main thread:** mutating UI from a background task is undefined behavior — surprising flicker, crashes, or nothing. Use `@MainActor`.
- **Value-type copy semantics:** mutating a `struct` copy does *not* affect the original; passing a struct into a function and expecting outside mutation will astonish. Conversely, a `class` shared in two places mutates in both.
- **`@State` with a reference type vs value type:** SwiftUI only re-renders on the changes it tracks; storing a non-`@Observable` class in `@State` and mutating its fields won't refresh the view.
- **`lazy` and `var` capture:** `lazy var` is not thread-safe; capturing it across actors surprises.

## Idiomatic vs non-idiomatic examples

**1 — Unwrapping**
```swift
// non-idiomatic: crashes on bad input
let url = URL(string: input)!
load(url)

// idiomatic
guard let url = URL(string: input) else { return }
load(url)
```

**2 — Naming & booleans**
```swift
// non-idiomatic
func getIsEmptyValue() -> Bool { items.count == 0 }
collection.removeElement(at: index)

// idiomatic
var isEmpty: Bool { items.isEmpty }
collection.remove(at: index)
```

**3 — Modeling state with an enum**
```swift
// non-idiomatic: illegal combinations representable
var isLoading = false
var items: [Item]?
var error: Error?

// idiomatic: one value, no illegal states
enum LoadState { case idle, loading, loaded([Item]), failed(Error) }
var state: LoadState = .idle
```

## Sources
- Swift API Design Guidelines — https://www.swift.org/documentation/api-design-guidelines/
- Apple Human Interface Guidelines (overview) — https://developer.apple.com/design/human-interface-guidelines
- Apple HIG — Accessibility — https://developer.apple.com/design/human-interface-guidelines/accessibility
- iOS 17+ SwiftUI State Management (@Observable / @Bindable / @Environment) — https://zoewave.medium.com/new-swiftui-state-management-3a6c9b737724
