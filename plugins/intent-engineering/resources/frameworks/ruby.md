# Ruby (language) — Conventions
> Write code a Rubyist expects: snake_case, blocks over loops, `?`/`!` that mean what they say, and no surprises.

## Naming & style
- **Methods & variables:** `snake_case`. Don't separate digits from letters (`some_var1`, not `some_var_1`).
- **Classes & modules:** `CamelCase` (UpperCamelCase). Keep acronyms uppercase: `SomeXMLParser`, not `SomeXmlParser`.
- **Constants:** `SCREAMING_SNAKE_CASE` for non-class/module constants.
- **Symbols:** `snake_case`, same as methods/variables.
- **Files & directories:** `snake_case`. One class/module per file, filename matching the class (`HTTPClient` → `http_client.rb`).
- **Predicate methods:** end in `?` and return a boolean. Avoid `is_`, `does_`, `can_` prefixes — `empty?`, not `is_empty`.
- **Bang (dangerous) methods:** end in `!` to signal mutation or "the dangerous version". Define `!` only when a safe counterpart exists (`sort` / `sort!`). The convention is *relative*: `!` means "more dangerous than the version without".
- **Attribute accessors:** use `attr_reader` / `attr_writer` / `attr_accessor` macros; never hand-write trivial getters/setters.
- **Unused variables/params:** prefix with `_` (`_unused`, or just `_`).
- **Indentation:** two spaces, no tabs. UTF-8, Unix line endings.

## Idiomatic Ruby (what a Rubyist expects)

### Blocks, enumerable, each vs map
- Iterate with `Enumerable` methods, never `for`. `for` does not create a new scope and leaks the loop variable.
- Pick the method that names the intent: `each` (side effects, returns the receiver), `map` (transform → new array), `select`/`filter` & `reject` (filter), `reduce`/`inject` (fold), `find`/`detect`, `any?`/`all?`/`none?`, `sum`, `count`, `group_by`, `flat_map`, `each_with_object`, `tally`.
- Use `{ ... }` for single-line blocks, `do ... end` for multi-line.
- Use the numbered/`it` block param or short names for trivial blocks; descriptive names otherwise. `arr.map { |item| item.name }` reads better than `arr.map(&:name)` only when there's real logic — prefer `&:symbol` for a bare method call: `arr.map(&:name)`.

### Method conventions (predicate ?, bang !, attr_*)
- Predicate `?` → returns `true`/`false`, no side effects.
- Bang `!` → mutates in place or raises where the safe version wouldn't; pairs with a non-bang variant.
- Omit explicit `return` except for early exits — the last expression is the return value.
- Avoid an explicit `self.` receiver unless required (e.g. assignment to a setter inside the object: `self.attr = x`).
- Prefer keyword arguments over positional optional args for clarity at the call site.

### Error handling (raise/rescue, custom errors)
- Raise with `raise SomeError, 'message'`, not `raise SomeError.new('message')`.
- Custom exceptions inherit from `StandardError` (or a domain base that does), never from `Exception` directly.
- Rescue the *narrowest* class that fits; a bare `rescue` catches only `StandardError`, which is usually what you want. Never `rescue Exception` (it traps `SignalException`, `SystemExit`, `NoMemoryError`).
- Use method-level `rescue`/`ensure` without an explicit `begin` block where possible.
- Order multiple `rescue` clauses most-specific first.
- Never swallow an exception with an empty `rescue` and no comment explaining why.

### Idioms (guard clauses, ||=, safe navigation &.)
- **Guard clauses** over nested conditionals: `return unless valid?` at the top instead of wrapping the body in `if`.
- **`||=`** for lazy init / defaulting: `@cache ||= compute`. Do *not* use it for booleans (`enabled ||= true` is a bug when `enabled` is legitimately `false`).
- **Safe navigation `&.`** for an optional receiver: `user&.address&.city`. Keep chains short; a long `&.` chain usually hides a missing object you should handle explicitly.
- **`&&` / `||`** for boolean logic; reserve `and` / `or` for low-precedence control flow only (many teams ban them entirely).
- Ternary `a ? b : c` for simple single-line conditionals only — never nested.
- Use `Array()`, `Integer()`, `Hash()` and `fetch` (with a default) instead of unguarded `[]` access when a missing key is an error.

## Convention violation smells (detectable — feed the convention lens)
- `for x in collection` loop instead of `collection.each` / `.map`.
- Manual index loop (`i = 0; while i < arr.length; ... i += 1; end`) instead of an enumerable.
- Building a result array with `each` + `<<` where `map`, `select`, or `each_with_object` is the right tool.
- Method named with `is_`, `has_`, `get_`, or `set_` prefix (Java-style) instead of `?`, a noun, or `attr_*`.
- A `?` predicate that returns a non-boolean (returns the object, `nil`, or an integer).
- A `!` method that does **not** mutate or is **not** more dangerous than a non-bang counterpart — or a `!` method with no safe counterpart at all.
- Hand-written `def name; @name; end` / `def name=(v); @name = v; end` instead of `attr_accessor`.
- `raise SomeError.new('msg')` instead of `raise SomeError, 'msg'`.
- `rescue Exception` or a bare empty `rescue` swallowing errors silently.
- Custom error inheriting from `Exception` instead of `StandardError`.
- Explicit `return` on the last line of a method.
- Unnecessary `self.` receiver on reads.
- `if !condition` instead of `unless condition`; `x == nil` instead of `x.nil?`.
- Long method (>~10 lines) that should be decomposed.

## Least-astonishment traps specific to Ruby
- **Bang that doesn't mutate / has no safe pair.** Readers assume `do_it!` is the dangerous twin of `do_it`. A lone `process!` with no `process` surprises everyone.
- **Predicate returning truthy non-boolean.** `valid?` returning the error object "works" in conditionals but breaks `valid? == true`, serialization, and reader expectations. Return real booleans (`!!value` or an explicit comparison).
- **Monkey-patching core classes.** Reopening `String`, `Array`, `Hash`, etc. changes behavior globally and astonishes every other file. Prefer refinements (scoped) or a helper module/object.
- **Truthiness surprises.** Only `nil` and `false` are falsey — `0`, `""`, and `[]` are all truthy. Code that assumes "empty is falsey" (Python/JS habit) is wrong in Ruby; check `.empty?` / `.zero?` explicitly.
- **`||=` on a boolean** silently overwrites a legitimate `false`.
- **Mutating shared default arguments / frozen literals.** A mutated default `arg = []` is fresh per call (unlike Python), but mutating a shared constant array/hash is a global side effect.
- **`return` inside a block / proc vs lambda.** `return` in a `proc`/block returns from the enclosing method; in a `lambda` it returns from the lambda. Subtle and surprising.
- **Methods with hidden side effects.** A `fetch_user` or `current_total` that also writes/mutates violates the read-name contract.

## Idiomatic vs non-idiomatic examples

**1. Loop → enumerable**
```ruby
# non-idiomatic
result = []
for user in users
  result << user.name if user.active?
end

# idiomatic
result = users.select(&:active?).map(&:name)
```

**2. Java-style getter & guard nesting → attr_reader & guard clause**
```ruby
# non-idiomatic
def get_total
  if @items != nil
    @items.sum
  end
end

# idiomatic
attr_reader :items

def total
  return 0 if items.nil?
  items.sum
end
```

**3. Misleading bang/predicate → honest names**
```ruby
# non-idiomatic — bang doesn't mutate, predicate returns non-boolean
def save!(record); persist(record); end   # no safe counterpart, never mutates `self`
def ready?; @status; end                  # returns a String, not a boolean

# idiomatic
def save(record); persist(record); end
def ready?; @status == :ready; end
```

## Sources
- Ruby Style Guide (community / RuboCop) — https://rubystyle.guide/
- Shopify Ruby Style Guide — https://ruby-style-guide.shopify.dev/
- Airbnb Ruby Style Guide — https://github.com/airbnb/ruby
