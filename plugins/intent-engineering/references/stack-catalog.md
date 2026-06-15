# Stack Catalog

The single source of truth for **which stacks the plugin knows, how to detect them, and
which resource packs each one loads.** Every skill and the architecture lens reads this
catalog instead of re-encoding stack detection inline — add a stack here (plus its packs)
and the whole pipeline picks it up. This is the registry that keeps stack knowledge as
*data*, so the lens agents stay stack-neutral no matter how many stacks ship.

## How it's used

- **Convention lens** (`ie-convention-reviewer`) — every stack with a `Convention doc`
  row applies. Detect the stack(s), read the matching `frameworks/<stack>.md`.
- **Architecture lens** (`ie-architecture-reviewer`) — runs only for a stack whose
  **Arch pack** is `✅` (both `frameworks/<stack>-architecture.md` and
  `patterns/<stack>.yaml` exist, plus a `<stack>.*` namespace in `thresholds.yaml`). The
  agent gates on that pair; this catalog is the human-readable index of the same fact.
- **`ie-init`** — detects the stack, then scaffolds the matching `thresholds.yaml`
  namespace and seeds `patterns.yaml` policy from that stack's catalog ids. Unknown stack →
  scaffold the stack-agnostic `ways-of-working.yaml` only and say the pack isn't available.
- **Selection is agent judgment, not keyword matching.** Detection signals are a starting
  point; the lens still reasons about whether the change/codebase actually involves the
  stack. Config `lenses:` toggles override (`config-resolution.md`).

## Catalog

| Stack id | Detection signals | Convention doc | Arch pack | Architecture doc | Pattern catalog | Threshold ns |
|----------|-------------------|----------------|:---------:|------------------|-----------------|--------------|
| `rails` | `Gemfile` with `rails`; `config/application.rb`; `app/models` + `app/controllers` | `frameworks/rails.md` | ✅ | `frameworks/rails-architecture.md` | `patterns/rails.yaml` | `rails.*` |
| `python` | `pyproject.toml` / `setup.py` / `setup.cfg`; `.py` sources (FastAPI-first, any layered service) | `frameworks/python.md` | ✅ | `frameworks/python-architecture.md` | `patterns/python.yaml` | `python.*` |
| `laravel` | `composer.json` with `laravel/framework`; an `artisan` file; `app/` + `routes/` + `bootstrap/app.php` | `frameworks/laravel.md` | ✅ | `frameworks/laravel-architecture.md` | `patterns/laravel.yaml` | `laravel.*` |
| `express` | `package.json` with `express`; `app.js`/`server.js` + `routes/` (any layered Node HTTP service) | `frameworks/express.md` | ✅ | `frameworks/express-architecture.md` | `patterns/express.yaml` | `express.*` |
| `ruby` | `.rb` sources without Rails (gems, plain Ruby); `*.gemspec` | `frameworks/ruby.md` | ⬜ | — | — | — |
| `typescript` | `tsconfig.json`; `.ts`/`.tsx` sources | `frameworks/typescript.md` | ⬜ | — | — | — |
| `react` | `react` in `package.json`; `.jsx`/`.tsx` components | `frameworks/react.md` | ⬜ | — | — | — |
| `swift-ios` | `.swift` sources; `Package.swift`; `.xcodeproj`/`.xcworkspace` | `frameworks/swift-ios.md` | ⬜ | — | — | — |

**Arch pack `⬜`** = convention coverage only; the architecture lens skips the stack until
both architecture files + a threshold namespace land. The next candidate as a real dogfood
target appears is Elixir/Phoenix (research first, then author the packs, then flip the row
to ✅).

## Adding a stack

Per `AGENTS.md` "How to extend". An **architecture** stack ships only when **all** exist:

1. `resources/frameworks/<stack>-architecture.md` — researched smells doc (detection
   "smells" section + ≥2 cited Sources; the contract check enforces this).
2. `resources/patterns/<stack>.yaml` — design-pattern catalog (`id`/`name`/`intent`/
   `recognition`/`good_use`/`misuse`; snake_case ids).
3. `config/defaults/thresholds.yaml` — a `<stack>.*` namespace (every metric the doc cites
   must be defined; the contract check cross-references both ways).
4. A row here flipped to ✅, and a row in `principle-index.md`.

A **convention-only** stack needs just `frameworks/<stack>.md` + a row here (Arch pack ⬜).
The architecture lens and `ie-init` read this catalog, so no skill edits are needed to add a
stack — only the data packs and the catalog row.
