# TypeScript — Conventions
> Let the type system carry the meaning: be specific, be honest about null, and never lie with a cast.

## Naming & style
- **PascalCase** — classes, interfaces, type aliases, enums, enum *types*, decorators, type parameters (`T`, `TKey`), and TSX component functions.
- **camelCase** — variables, parameters, functions, methods, properties, module aliases.
- **CONSTANT_CASE** — module-level constants and enum *values*.
- **No `_` prefix/suffix** on identifiers (no `_private`, no trailing `_`). Use the language's `private`/`#` instead.
- **No `I`-prefix on interfaces** (`IUser` → `User`). The `I` is a community/Google anti-pattern: a consumer should not care whether a type is an interface or a class. Name by role (`UserStore`, not `IUserStore`).
- **Files** — kebab-case or the project's existing convention; one primary export concept per file. Match the existing repo style over personal preference.
- Prefer `interface` over a `type` alias when describing the shape of an *object*; reserve `type` for unions, intersections, tuples, mapped/conditional types, and primitives.

## Core conventions (what a TS dev expects)

### Types
- **Prefer the most specific type.** Model the real domain (`status: "active" | "archived"`) instead of `string`.
- **Avoid `any`.** `any` disables type checking from that expression onward — it is `@ts-ignore` applied silently to everything downstream. Use it only during JS→TS migration, and document why.
- **Prefer `unknown` over `any`** for genuinely-unknown values. `unknown` accepts anything but forbids use until you narrow it, so type safety is preserved.
- **Discriminated unions** for "one of N shapes": a shared literal tag (`kind: "circle" | "square"`) lets the compiler narrow exhaustively. Pair with a `never` default branch so a missing case is a compile error.
- **`readonly`** on properties never reassigned after construction, and `readonly T[]` for arrays you don't mutate. Communicates intent and blocks accidental writes.
- **Array syntax:** `T[]` / `readonly T[]` for simple element types; `Array<T>` only when the element type is itself complex.
- **Never the boxed types** `Number`, `String`, `Boolean`, `Symbol`, `Object` — use lowercase `number`, `string`, `boolean`, `symbol`, and `object` (or a precise shape) instead.

### Functions
- **Make return types explicit on exported/public functions.** Inferred returns are fine internally, but an annotation on the API surface documents intent and prevents silent return-type drift.
- **Callbacks whose result is discarded return `void`, not `any`** (`(e: Event) => void`). `void` stops a caller from accidentally consuming a meaningless return.
- **Overloads: specific before general** — TypeScript picks the *first* matching signature, so a general overload listed first hides the specific ones.
- **Prefer optional parameters / union params over multiple overloads** that differ only in trailing args or a single position (`utcOffset(b: number | string)` beats two overloads). Better compatibility and strict-null behaviour.
- **`async` functions return `Promise<T>`** — type the resolved value, not the promise. Don't mix returning a `Promise` with also taking a callback; pick one.

### Null/undefined handling
- **Enable `strict` (and thus `strictNullChecks`).** Non-strict mode hides the entire class of null bugs the type system exists to catch.
- **Use optional chaining `?.` and nullish coalescing `??`** to read possibly-absent values, rather than manual `&&` ladders or `||` (which also swallows `0`/`""`).
- **Do not abuse the non-null assertion `!`.** `x!.foo` tells the compiler "trust me, not null" with no runtime check — if you're wrong it throws at runtime with a lying type. Narrow with a guard (`if (x)`), or add an explicit assertion/throw, instead.
- **Add nullability at the use site, not in the alias.** Don't bake `| null | undefined` into a shared type alias; mark the *field* optional (`name?: string`) or union it where it's actually nullable.

### Modules & exports
- **Prefer named exports; avoid default exports.** Named exports give consistent identifiers, better refactors, and reliable auto-import.
- **No mutable exports** (`export let`). Export `const` or a getter.
- **Use `import type` / `export type`** for type-only references so bundlers and isolated-module transpilers can erase them cleanly.

## Convention violation smells (detectable — feed the convention lens)
- `any` used to silence a compiler error (`const x: any = …`, `(x as any).foo`, `// @ts-ignore` / `@ts-expect-error` without justification).
- `as` casts that *widen-then-narrow* or otherwise lie (`JSON.parse(s) as User` with no validation; `x as unknown as Y` double-cast).
- Non-null assertion `!` on a value that is genuinely nullable at runtime (esp. `arr.find(...)!`, `document.getElementById(...)!`).
- Boxed primitive types `String`/`Number`/`Boolean`/`Object`, or the bare `Function` type instead of a real signature.
- `const enum` (breaks isolated modules / hides values from JS consumers) — use a plain `enum` or a `const` object + union.
- `I`-prefixed interfaces, `_`-prefixed identifiers, or `Array<string>` where `string[]` is conventional.
- `strict: false`, `noImplicitAny: false`, or per-file `// @ts-nocheck` — strictness disabled.
- Default exports in a codebase that otherwise uses named exports (inconsistent import names).
- `==`/`!=` used for non-null comparisons.

## Least-astonishment / predictability traps specific to TS
- **The cast that lied.** A value typed `User` because of `as User` but actually `undefined` at runtime — the type says non-null, the program crashes. Types are erased; an unchecked assertion has zero runtime force.
- **Function typed to return `X` but can return `undefined`.** `Array.prototype.find`, `Map.get`, and index access (`arr[i]`) are common sources; without `noUncheckedIndexedAccess` the type hides the `undefined`.
- **Structural typing surprises.** Two unrelated types with the same shape are assignable to each other — an object literal may satisfy a type it was never "meant" for. Excess-property checks only fire on *fresh* literals, so a variable can sneak extra fields through.
- **`==` vs `===`.** `==` does coercion (`0 == ""`, `null == undefined` are `true`). Use `===`/`!==` everywhere except a deliberate `== null` to catch both `null` and `undefined`.
- **Enums aren't plain numbers.** Numeric enums accept any number at the assignment site and reverse-map; this can surprise. Prefer string enums or union literals.
- **`void` vs `undefined` in callbacks.** A `() => void` type still *allows* a function that returns a value — `void` means "the caller ignores it", not "must return nothing".
- **Type narrowing lost across `await`/closures.** A guard that proved `x` non-null can be invalidated after an `await` or inside a later callback; the compiler may re-widen.

## Idiomatic vs non-idiomatic examples

**1. unknown over any**
```ts
// Non-idiomatic — disables all checking downstream
function parse(json: string): any {
  return JSON.parse(json);
}

// Idiomatic — forces the caller to narrow/validate before use
function parse(json: string): unknown {
  return JSON.parse(json);
}
```

**2. Guard instead of non-null assertion**
```ts
// Non-idiomatic — `!` lies; throws "cannot read .name of undefined" at runtime
const user = users.find(u => u.id === id)!;
return user.name;

// Idiomatic — honest type, explicit failure
const user = users.find(u => u.id === id);
if (!user) throw new NotFoundError(id);
return user.name;
```

**3. Discriminated union over loose flags**
```ts
// Non-idiomatic — invalid combos representable (loading && error?)
interface State { loading: boolean; data?: Data; error?: Error; }

// Idiomatic — only valid states exist; switch can be exhaustive
type State =
  | { status: "loading" }
  | { status: "success"; data: Data }
  | { status: "error"; error: Error };
```

## Sources
- Do's and Don'ts — TypeScript Handbook — https://www.typescriptlang.org/docs/handbook/declaration-files/do-s-and-don-ts.html
- Google TypeScript Style Guide — https://google.github.io/styleguide/tsguide.html
- TypeScript Style Guide (ts.dev) — https://ts.dev/style/
- Why `unknown` is Better Than `any` — https://medium.com/@ignatovich.dm/why-unknown-is-better-than-any-a-typescript-safety-guide-073be8c301e0
- When to use `never` and `unknown` in TypeScript — LogRocket — https://blog.logrocket.com/when-to-use-never-unknown-typescript/
