# Python — Conventions
> Write code a Pythonista would recognise: explicit, readable, idiomatic, and surprising no one.

## The Zen of Python (PEP 20) as a checklist

The Zen has 19 aphorisms; these are the ones a reviewer can actually *check* against code.

| Aphorism | What to check |
|---|---|
| **Explicit is better than implicit** | No hidden side effects, no magic globals, no relying on import side effects. Names say what they do. Behaviour is visible at the call site, not buried. |
| **Simple is better than complex** | Prefer the straightforward solution. Flag clever one-liners, nested ternaries, and metaprogramming used where a plain function would do. |
| **Complex is better than complicated** | When complexity is unavoidable, it should be structured and explainable — not tangled. If you can't explain the implementation simply, it's a bad idea (see #17). |
| **Flat is better than nested** | Deeply nested `if`/`for` blocks are a smell. Use early returns, guard clauses, and comprehensions to flatten. |
| **Readability counts** | The code is read far more than written. Naming, spacing, and obvious control flow matter more than brevity. |
| **Errors should never pass silently / unless explicitly silenced** | No bare `except:`, no `except Exception: pass`. If an error is intentionally ignored, it must be narrow and commented. |
| **In the face of ambiguity, refuse the temptation to guess** | Don't silently coerce types or invent defaults to paper over an unclear input. Fail loudly. |
| **There should be one — and preferably only one — obvious way to do it** | Prefer the canonical idiom (`enumerate`, comprehension, `with`) over ad-hoc reinventions. |
| **If the implementation is hard to explain, it's a bad idea** | Use as a tie-breaker in review: hard-to-explain code loses. |
| **Namespaces are one honking great idea** | Prefer modules and qualified names over a flat soup of globals; avoid `from module import *`. |

## Naming & style (PEP 8)

- **Functions / variables / methods:** `snake_case` — lowercase words separated by underscores.
- **Classes / exceptions:** `PascalCase` (CapWords). Exceptions should end in `Error` when they are errors.
- **Constants:** `UPPER_CASE_WITH_UNDERSCORES`, defined at module level.
- **Non-public:** one leading underscore (`_internal`). Use a double leading underscore (`__name`) only when you actually want name-mangling.
- **Module-level dunders** (`__all__`, `__version__`): placed after the module docstring but before imports, except `from __future__` imports which come first.
- **Line length:** limit lines to **79 characters**; docstrings and comments to **72**. (Many teams relax to 88/99 via Black/Ruff — match the project's configured limit.)
- **Indentation:** 4 spaces per level. Spaces, never tabs.
- **Imports:** on separate lines, grouped and blank-line-separated in this order:
  1. Standard library
  2. Third-party
  3. Local application / library
  Avoid wildcard imports (`from x import *`).
- **Comparisons to singletons** (`None`, `True`, `False`): use `is` / `is not`, never `==`. Prefer `is not x` over `not ... is x`.
- **Type checks:** use `isinstance(obj, Cls)`, not `type(obj) == Cls`.
- **Lambdas:** use `def` for a named function; don't bind a lambda to a name.

## Idiomatic Python (what a Pythonista expects)

### Iteration
- Loop over items directly: `for item in items:` — not `for i in range(len(items)): items[i]`.
- Need the index? `for i, item in enumerate(items):`.
- Parallel sequences? `for a, b in zip(xs, ys):`.
- Building a list/dict/set from a loop? Use a **comprehension**: `[f(x) for x in xs if cond(x)]`, `{k: v for ...}`, `{x for ...}`.
- Lazy / large streams? Use a **generator expression** `(f(x) for x in xs)` or `yield`, not a materialised list.
- Don't build an index counter by hand; don't `append` in a loop where a comprehension reads cleaner.

### EAFP vs LBYL, context managers, truthiness
- **EAFP** ("easier to ask forgiveness than permission") is the Python default: `try: value = d[k] except KeyError: ...` is preferred over checking `if k in d` first when the key usually exists. LBYL ("look before you leap") invites race conditions and double lookups.
- **Context managers:** always use `with open(path) as f:` (and `with lock:`, `with conn:`) so resources close even on exception. Never rely on manual `f.close()`.
- **Truthiness:** test emptiness directly — `if items:` / `if not items:` — not `if len(items) > 0` or `if items != []`. Test `None` explicitly with `if x is None:` (don't conflate "None" with "empty/falsy").

### Data structures
- `dict.get(key, default)` and `dict.setdefault` over `if key in d` branching; `collections.defaultdict` / `collections.Counter` for accumulation.
- Iterate `for k, v in d.items():`; membership test on `set`/`dict` (O(1)), not `list` (O(n)).
- Use `set` for uniqueness and fast membership; use set operations (`&`, `|`, `-`) instead of manual loops.
- For structured records, prefer `@dataclass` (mutable, typed) or `typing.NamedTuple` / `collections.namedtuple` (immutable) over bare tuples/dicts with positional/string access.
- Unpack instead of indexing: `first, *rest = seq`; swap with `a, b = b, a`.

## Convention violation smells (detectable — feed the convention lens)

- C-style index loops: `for i in range(len(x)):` then `x[i]` — should be direct iteration / `enumerate` / `zip`.
- **Mutable default argument**: `def f(x, acc=[])` or `def f(cfg={})` — shared across calls.
- **Bare `except:`** or `except Exception: pass` — silently swallows errors (including `KeyboardInterrupt` for bare except).
- Manual resource handling: `f = open(...)` … `f.close()` without `with` (leaks on exception).
- Manual list-building loop where a comprehension is the obvious form.
- `type(x) == SomeType` instead of `isinstance`.
- `== None` / `!= None` / `== True` instead of `is None` / direct truthiness.
- `if len(seq) == 0:` / `if seq == []:` instead of `if not seq:`.
- `camelCase` or `PascalCase` function/variable names; `snake_case` class names.
- Wildcard imports (`from x import *`); imports not grouped std/third-party/local.
- String concatenation in a `+=` loop instead of `''.join(...)`.
- `d.keys()` membership test (`if k in d.keys()`) instead of `if k in d`.
- Lambda bound to a name (`f = lambda x: ...`) instead of `def`.

## Least-astonishment traps specific to Python

- **Mutable default argument:** the default is evaluated *once* at definition time, so a `[]`/`{}` default is shared and mutated across calls. Use `None` and create inside: `def f(x, acc=None): acc = [] if acc is None else acc`.
- **Late-binding closures:** functions created in a loop capture the *variable*, not its value at creation time — all closures see the final loop value. Bind it with a default arg: `lambda x, i=i: ...`.
- **`is` vs `==`:** `is` tests identity, `==` tests equality. `a is b` may be `True` for small cached ints/interned strings and `False` for equal-but-distinct objects. Use `==` for value comparison; reserve `is` for `None`/singletons.
- **Silent exception swallowing:** `except Exception: pass` hides bugs. Catch the narrowest exception, and log or re-raise rather than discard.
- **Truthiness of empty collections:** `[]`, `{}`, `()`, `""`, `0`, `0.0`, `None` are all falsy. `if value:` cannot distinguish "empty" from "missing" — use `if value is None:` when that distinction matters.
- **Default args evaluated at def time:** any expression (not just mutables) in a default is computed once; don't put "now" timestamps or config lookups there expecting per-call evaluation.
- **Integer/float division & equality:** `/` is always float division; `==` on floats is unreliable — compare with a tolerance (`math.isclose`).

## Idiomatic vs non-idiomatic examples

**1. Iteration with index**
```python
# Non-idiomatic
for i in range(len(names)):
    print(i, names[i])

# Idiomatic
for i, name in enumerate(names):
    print(i, name)
```

**2. Mutable default argument**
```python
# Surprising — `items` is shared across all calls
def add(value, items=[]):
    items.append(value)
    return items

# Safe
def add(value, items=None):
    items = [] if items is None else items
    items.append(value)
    return items
```

**3. Resource handling + filtering**
```python
# Non-idiomatic: manual close, manual list build, leaks on error
f = open("data.txt")
lines = []
for line in f.readlines():
    if line.strip():
        lines.append(line.strip())
f.close()

# Idiomatic: context manager + comprehension
with open("data.txt") as f:
    lines = [line.strip() for line in f if line.strip()]
```

## Sources
- PEP 8 — Style Guide for Python Code — https://peps.python.org/pep-0008/
- PEP 20 — The Zen of Python — https://peps.python.org/pep-0020/
- Common Gotchas — The Hitchhiker's Guide to Python — https://docs.python-guide.org/writing/gotchas/
- Python Glossary ("Pythonic", EAFP, LBYL) — https://docs.python.org/3/glossary.html
- Early and late binding closures in Python — https://jellis18.github.io/post/2022-11-23-late-binding-python/
