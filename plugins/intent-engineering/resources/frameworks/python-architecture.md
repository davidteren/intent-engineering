# Python — Architecture Smells

> one-line essence: structural anti-patterns that make a Python service (FastAPI-first)
> hard to change.

## How the lens uses this doc

Heuristic-first (count + responsibility judgment via Read/Grep/Glob/Bash); optionally
enrich with `ruff`, `vulture`, `radon`, or `import-linter` if installed (never required).
Thresholds come from resolved config (`config/defaults/thresholds.yaml` ->
`.intense/thresholds.yaml` override). A threshold is a SIGNAL to look closer, not an
automatic verdict — judge responsibilities.

This pack targets **service-shaped Python**: a web/API service or a background worker
with a layered shape (transport -> validation -> application logic -> integration). The
dominant idiom is **FastAPI** (routers, `Depends` dependency injection, Pydantic models,
`pydantic-settings`, an app factory), but the structural smells apply to any Python
service that separates an HTTP/transport edge from its business logic. The healthy shape
is **thin edges, explicit middle**: route handlers and dependencies orchestrate, Pydantic
validates shape, a service layer owns behaviour, and integration code (DB, external APIs,
file formats) hides behind named seams. The smells below detect where that has broken
down. When a repo states its own layering rules in `CLAUDE.md`/`AGENTS.md`, those win.

## Smells (detectable)

**Canonical smell ids** (the stable vocabulary used by the finding `smell` field, the
`severity_overrides` keys in `.intense/ways-of-working.yaml`, and the architecture lens).
Smell ids are **kebab-case**; design-pattern ids (in `patterns/python.yaml`) are
**snake_case** — two adjacent id systems, deliberately distinct casing so a value's kind
is obvious at a glance.

| Smell id | Section |
|----------|---------|
| `fat-router` | 1. Fat router (logic in route handlers) |
| `god-module` | 2. God module (dumping-ground module) |
| `god-object` | 3. God object (high fan-out class) |
| `misused-service` | 4. Misused service layer |
| `business-logic-in-schema` | 5. Business logic in Pydantic schema |
| `fat-dependency` | 6. Fat / side-effecting dependency |
| `layer-leak` | 7. Layer leak (transport ↔ domain bleed) |
| `law-of-demeter` | 8. Law of Demeter violations |

### 1. Fat router (logic in route handlers) — `fat-router`
- **Signal:** A router module over `python.router.max_loc`, any single handler body over
  `python.router.max_handler_loc`, or a router declaring more than `python.router.max_routes`
  operations. Grep `@router.(get|post|put|patch|delete)` / `@app.(get|post|...)` to find
  handlers; measure the function body. Beyond counts, flag handlers that compute results,
  build queries, transform DataFrames, call external APIs, or branch on business rules
  instead of delegating to a service and shaping the HTTP response.
- **Why it matters:** Route handlers are the hardest layer to reuse and test — they are
  bound to the HTTP harness, request parsing, and auth. Logic trapped in a handler is
  unreachable from a worker, a CLI, or another endpoint, and gets duplicated across routes.
- **Confirm (not just count):** A handler that validates input via its Pydantic model,
  calls one service function, and maps the result to a `Response`/status code is *thin* —
  even if it spans a few lines of response shaping (headers, `Content-Disposition`,
  status negotiation). Count the *work*, not the decorator metadata or the `responses={...}`
  OpenAPI dict. Exception-to-HTTP translation (`except ValueError: raise HTTPException`) is
  legitimate transport work.
- **Fix direction:** Move computation into a `service` function that receives and returns
  Pydantic models / dataclasses and knows nothing about HTTP; keep the handler as
  validate -> call service -> shape response. Param/aggregate shaping that isn't a request
  body belongs in a dependency or a small request object.
- **Default severity:** P2 when business logic lives in the handler; P3 for route sprawl
  with otherwise-thin handlers.

### 2. God module (dumping-ground module) — `god-module`
- **Signal:** A module over `python.module.max_loc`, exposing more than
  `python.module.max_public_functions` public functions or `python.module.max_public_classes`
  public classes (names without a leading underscore). The classic offenders are
  `utils.py` / `helpers.py` / `common.py` that accrete unrelated functions. Count
  top-level `def`/`class` not prefixed with `_`. Module-level **mutable global state**
  (a top-level `dict`/`list`/`set` reassigned or mutated at runtime, a cache that hides
  config) is a strong corroborating signal — it couples every importer to shared state.
- **Why it matters:** A module is Python's primary namespace. One that holds many unrelated
  responsibilities becomes a coordination hub every other module imports, so a change for
  one concern risks unrelated ones and import cycles cluster around it.
- **Confirm (not just count):** A cohesive module with many small functions that all serve
  one concept (e.g. one Excel-rendering module, one date-math module) is fine — size alone
  is weak evidence. Flag when the public names cluster into 2+ unrelated groups, or the
  module mixes layers (HTTP + DB + formatting + domain rules). A `__init__.py` that only
  re-exports is not a god module. **Format/rendering modules are verbose by nature** —
  openpyxl/pandas/reportlab sheet-and-table assembly runs long and wide; a cohesive
  `document_renderer` (see the catalog) routinely trips the LOC/function-count signals while
  doing exactly one job. Clear it on cohesion, not count; only flag when it also mixes
  unrelated documents or layers.
- **Fix direction:** Split by responsibility into named modules/packages; replace a
  grab-bag `utils.py` with intention-named modules (`file_safety.py`, `invoice_pricing.py`).
  Push module-level mutable state into an explicitly constructed object or a `Settings`/DI
  seam.
- **Default severity:** P2 when distinct responsibilities or shared mutable state are
  mixed; P3 when only counts trip and the module is cohesive.

### 3. God object (high fan-out class) — `god-object`
- **Signal:** Any class that references or instantiates more distinct classes than
  `python.god_object.max_collaborators`, or exceeds `python.god_object.max_loc`. Count
  distinct imported/constructed types and injected dependencies (fan-out).
- **Why it matters:** A high-fan-out class knows about the whole system, so the whole
  system depends on it. It can't be understood, tested, or reused in isolation and attracts
  more responsibility over time.
- **Confirm (not just count):** A composition root, an app factory, or a deliberate facade
  legitimately touches many classes — that is its job (see `app_factory` in the catalog).
  Distinguish *wiring* (acceptable fan-out at the edge) from *logic* (a class doing many
  unrelated things). Count only collaborators it actively drives, not value types or
  Pydantic models it merely passes through.
- **Fix direction:** Split by responsibility; introduce intermediary objects so the hub
  talks to a few abstractions instead of many concretes. Apply
  [[../principles/occams-razor]] — collapse only when one concept is genuinely shared.
- **Default severity:** P2 — high fan-out is a strong structural signal and rarely benign
  outside composition roots.

### 4. Misused service layer — `misused-service`
- **Signal:** A service module/class exposing more than `python.service.max_public_functions`
  public entrypoints, or exceeding `python.service.max_loc`. Three failure modes mirror the
  Rails service-object smells, adapted to Python's module-or-class service style: (a)
  **grab-bag** — many unrelated public functions in one `services/x.py`, really a namespace;
  (b) **god service** — one function that does everything an endpoint needs end to end;
  (c) **anemic pass-through / misplaced logic** — a `services/` module that only forwards
  to another module (commonly a `util/`/`helpers` module) which actually holds the business
  logic. The thin shim satisfies the folder convention while the real application layer
  lives under a name that says "utility". Detect by comparing bodies: `services/` functions
  ~1 line of forwarding vs a non-`services/` module with the orchestration, filtering, and
  domain rules. Recognize a service by **behaviour, not just path** — a module that receives
  Pydantic/dataclasses, returns domain values, imports no transport types, and is named
  `build_*`/`render_*`/`calculate_*` IS the application layer wherever it sits.
- **Why it matters:** The service layer exists to give a business operation a name and a
  testable, HTTP-agnostic seam. A grab-bag dissolves the seam; a god service just relocates
  the bloat; a pass-through adds indirection without value — the opposite of least
  astonishment.
- **Confirm (not just count):** Private helpers (`_foo`) are fine and expected — count only
  public entrypoints. A `services/` module exposing a small set of cohesive, related
  operations on one concept is healthy. For pass-through suspicion, check whether the
  service adds validation, orchestration, transaction boundaries, or error handling; if it
  does, it earns its place.
- **Fix direction:** Grab-bag -> split into one module per concern, or one function per
  operation named after the action. God service -> decompose into composed steps.
  Pass-through -> inline it and delete the layer.
- **Default severity:** P2 for a god service; P3 for grab-bag or pass-through services.

### 5. Business logic in Pydantic schema — `business-logic-in-schema`
- **Signal:** A model over `python.schema.max_validators` validators or
  `python.schema.max_fields` fields, OR a validator that does more than shape/range
  checking. Grep `@field_validator` / `@model_validator` / `@validator` and inspect the
  bodies: flag I/O (DB, HTTP, file, environment reads), cross-record lookups, side effects,
  or genuine business rules living inside a request/response model. This is the Python
  analogue of Rails callback hell — behaviour smuggled into the data layer.
- **Why it matters:** Pydantic runs validators implicitly on every construction, including
  in tests, fixtures, and serialization. Business logic there is hard to disable, runs at
  surprising times, couples your wire contract to your domain, and makes "just build the
  object" have side effects (violating least astonishment).
- **Confirm (not just count):** Pure, local validators (normalising case, bounding a
  string, coercing/validating a date, enforcing `start <= end`) are exactly what validators
  are for — low-risk even in numbers. The danger is *I/O*, *side-effecting*, and
  *cross-entity* validators; weight those far more heavily than count. A security-driven
  size/shape cap is legitimate validation, not a smell.
- **Fix direction:** Keep validators pure and shape-only. Move business rules and any I/O
  into a service function invoked from the route. Split a god schema by the screens/operations
  it really serves; don't share one model across request, response, and persistence.
- **Default severity:** P2 when a validator performs I/O or side effects; P3 for a high
  count of pure validators or an oversized but cohesive model.

### 6. Fat / side-effecting dependency — `fat-dependency`
- **Signal:** A FastAPI dependency callable (used via `Depends(...)`, typically in
  `dependencies.py` or wherever `Annotated[X, Depends(...)]` is wired) over
  `python.dependency.max_loc`, or one that performs business work rather than *resolving a
  value/resource*. Grep `Depends(` and the callables it targets. Flag dependencies that
  run queries for domain data, mutate state, call external services, or hide work behind
  `@lru_cache`/module globals.
- **Why it matters:** Dependencies run implicitly for every request that injects them, in
  an order FastAPI controls. Putting business logic there makes behaviour non-obvious and
  hard to test in isolation, and `@lru_cache`-backed singletons silently share state across
  requests/tests (a least-astonishment trap).
- **Confirm (not just count):** Auth/identity resolution (`verify_jwt`), settings/resource
  resolution (`get_settings`, a DB session/`yield` dependency), and pagination/param parsing
  are exactly what dependencies are for, even with a few branches. Flag when a dependency
  owns a business operation or carries mutable shared state.
- **Fix direction:** Keep dependencies to resolve-and-return (or `yield` a resource and
  clean up); push business operations into a service the handler calls. Prefer resolving
  settings/resources from `app.state` (constructed once in the factory) over `@lru_cache`
  singletons.
- **Default severity:** P2 when a dependency performs domain work or carries mutable shared
  state; P3 for an oversized but purely resolution-focused dependency.

### 7. Layer leak (transport ↔ domain bleed) — `layer-leak`
- **Signal:** Two directions. (a) **Upward leak:** the service/domain layer imports or
  references transport types — `fastapi`, `HTTPException`, `status`, the Starlette
  `Request`/`Response` *types*, raw `dict` request bodies — instead of staying HTTP-agnostic.
  Grep on **import context**, not bare type words: `^\s*(from fastapi|from starlette|import
  fastapi)` and `HTTPException`/`status.HTTP_` in `services/**` and domain modules. **Do
  NOT grep a bare `Request`/`Response`** — those substrings match the Pydantic request/
  response *model names* this pack endorses (`CreateOrderRequest`, `OrderResponse`; see the
  `pydantic_schema` `name_suffix`), so a bare grep is a guaranteed false positive. Match the
  transport `Request`/`Response` only as an imported Starlette/FastAPI type or a bare
  annotation (`: Request`, `-> Response`). (b) **Downward skip:** a route handler reaches
  past the service layer straight into persistence/integration — ORM/session calls,
  `httpx`/`requests`, file/`openpyxl`/`pandas` work — when a service seam exists for exactly
  that. Grep `routers/**` for those imports/calls.
- **Why it matters:** The layering exists so the domain is reusable from a worker/CLI and
  the transport is swappable. Each leak couples the two: a service that raises
  `HTTPException` can't be reused off the request path; a handler that queries directly
  duplicates and scatters data-access rules.
- **Confirm (not just count):** A service raising a *domain* exception that a handler maps
  to HTTP is correct — the leak is the service importing `HTTPException` itself. A tiny
  app with no service layer by design (documented) is not leaking; judge against the repo's
  stated layering.
- **Fix direction:** Services raise domain errors and return domain/Pydantic/dataclass
  values; handlers translate errors to HTTP. Route integration work through a service (or a
  `repository`/`adapter_client` seam), not inline in the handler.
- **Default severity:** P2 when domain logic depends on transport types (upward leak); P3
  for a handler doing integration work that a thin service would own.

### 8. Law of Demeter violations (`a.b.c.d` chains) — `law-of-demeter`
- **Signal:** "Train wreck" chains navigating across object boundaries —
  `request.user.account.plan.name`, `row.invoice.customer.address.city` — more than one dot
  of *navigation* (not fluent builders or stdlib chaining). Grep code and templates for
  attribute chains reaching through intermediate objects.
- **Why it matters:** Each extra dot couples the caller to the internal shape of every
  intermediate object; a change to any link breaks distant code, and an `AttributeError`/
  `None` mid-chain throws far from its cause. It leaks knowledge the caller shouldn't have.
- **Confirm (not just count):** Chains on a fluent/builder API, on a Pandas/`pathlib`
  expression, or on a value object you own are not Demeter violations — they operate on one
  returned object of the same kind. Flag chains that *navigate attributes/associations*
  across distinct objects' internals.
- **Fix direction:** Add a purpose-named accessor on the nearest object that hides the
  traversal (`order.shipping_city`), or pass the needed value in directly. Push the
  knowledge to where the data lives.
- **Default severity:** P3 — usually a localised readability/coupling smell; escalate to P2
  only when the same chain is duplicated widely (systemic coupling).

## General metrics

Beyond the per-unit smells, the lens uses `python.general.*` as cross-cutting signals on
any function: `python.general.max_function_loc` (long method -> extract), `python.general.max_function_params`
(long parameter list -> introduce a dataclass / request object / `**`-free grouping), and
`python.general.max_nesting_depth` (deep `if`/`for` nesting -> guard clauses, early returns;
see [[python]] "Flat is better than nested"). These confirm "long/complex function" vs
"god module/object" — high complexity on one function = refactor that function; complexity
spread across a module = decompose the module. Caveat: **declarative table/sheet/template
assembly tolerates longer bodies** than imperative business logic — a flat, linear,
single-purpose `build_*_workbook` reads better whole than split across helpers. Judge
branching/nesting and mixed responsibilities, not raw line count, for renderer code.

## Tool enrichment (optional)

These sharpen the heuristics; the lens must degrade gracefully when they are absent. Detect
presence first (e.g. `command -v ruff` / `command -v radon` / check the project's
`pyproject.toml`). Never install anything; never block on them.
- **ruff** — fast linter. `C901` (mccabe complexity), `PLR0911`/`PLR0912`/`PLR0913`/`PLR0915`
  (too many returns/branches/arguments/statements) map onto fat-router, god-object, and the
  general metrics. If the project already configures ruff, fold its complexity findings in.
- **radon** — cyclomatic complexity and maintainability index per function/module. Use to
  confirm a long/complex function vs a god module: high CC on one function = refactor it;
  high CC spread across a module = decompose it. Maps onto `python.general.*`.
- **vulture** — dead-code detector. Corroborates god-module (unused public surface) and
  unreferenced helpers worth deleting.
- **import-linter** — declared import-contract checker. Directly corroborates `layer-leak`:
  if the project declares layer contracts, a violation it reports is the smell.

When a tool is present, treat its output as *corroborating evidence* that raises confidence
— not as the source of truth. When absent, fall back to Read/Grep/Glob/Bash heuristics and
say so in the finding (so reviewers know it wasn't machine-confirmed).

## Relationship

[[../principles/occams-razor]], [[../principles/convention-over-configuration]],
[[python]] (conventions), patterns catalog (resources/patterns/python.yaml).

## Sources
- FastAPI — Bigger Applications: structuring routers, dependencies, and an app package — https://fastapi.tiangolo.com/tutorial/bigger-applications/
- FastAPI — Dependencies (what a dependency is for) — https://fastapi.tiangolo.com/tutorial/dependencies/
- Pydantic — Validators (intended scope; keep them about the data) — https://docs.pydantic.dev/latest/concepts/validators/
- Architecture Patterns with Python (Percival & Gregory) — service layer, repository, dependency inversion — https://www.cosmicpython.com/book/preface.html
- The Law of Demeter / "train wreck" chains — https://en.wikipedia.org/wiki/Law_of_Demeter
- Ruff — McCabe (C901) and Pylint refactor (PLR09xx) complexity rules — https://docs.astral.sh/ruff/rules/
