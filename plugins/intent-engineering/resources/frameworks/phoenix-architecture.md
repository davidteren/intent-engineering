# Phoenix / Elixir — Architecture Smells

> one-line essence: structural anti-patterns that make a Phoenix/Elixir app hard to change.

## How the lens uses this doc

Heuristic-first (count + responsibility judgment via Read/Grep/Glob/Bash); optionally
enrich with `mix credo` (`--strict`) or Boundary if installed (never required). Thresholds
come from resolved config (`config/defaults/thresholds.yaml` -> `.intense/thresholds.yaml`
override). A threshold is a SIGNAL to look closer, not an automatic verdict — judge
responsibilities.

Elixir is functional — there are no objects, only **modules and functions** — so "where does
the logic go?" is answered by Phoenix's central idea: **contexts**. *"Phoenix's job is to
provide a web interface into our Elixir application."* The web layer (router, controllers,
LiveViews, components) is a thin interface; the application lives in **context** modules that
*"centralize all functionality"* for a part of the domain and own data access (Ecto) and
validation, "instead of scattering logic around controllers, LiveViews, etc." Below that,
**Ecto schemas/changesets** model and validate data; **OTP** (GenServers, supervisors)
models runtime concerns — concurrency, state, fault isolation — *not* code organization. The
smells below detect where that layering and these idioms break down. When a repo states its
own structure in `CLAUDE.md`/`AGENTS.md`, that wins.

> Scope note: this pack covers **structural/layering** smells (contexts, web layer, Ecto,
> and the *placement* of OTP processes). It is heuristic and does not attempt deep
> supervision-tree or message-protocol correctness — route those to a reliability review.

## Smells (detectable)

**Canonical smell ids** (the stable vocabulary used by the finding `smell` field, the
`severity_overrides` keys in `.intense/ways-of-working.yaml`, and the architecture lens).
Smell ids are **kebab-case**; design-pattern ids (in `patterns/phoenix.yaml`) are
**snake_case** — two adjacent id systems, deliberately distinct casing.

| Smell id | Section |
|----------|---------|
| `fat-controller` | 1. Fat controller (logic that belongs in a context) |
| `context-bypass` | 2. Context bypass (web layer → Repo/schema directly) |
| `god-context` | 3. God context (context grouping unrelated functionality) |
| `fat-liveview` | 4. Fat LiveView (logic / data access in the view module) |
| `business-logic-in-changeset` | 5. Business logic / I/O in Ecto schema or changeset |
| `god-module` | 6. God module (dumping-ground module) |
| `process-misuse` | 7. Process misuse (unsupervised / scattered / code-org-by-process) |
| `law-of-demeter` | 8. Law of Demeter violations |

### 1. Fat controller (logic that belongs in a context) — `fat-controller`
- **Signal:** A controller over `phoenix.controller.max_loc`, any action over
  `phoenix.controller.max_action_loc`, or more than `phoenix.controller.max_actions` actions.
  Grep `lib/*_web/controllers/**` for actions (`def index(conn, params)`) and measure the
  body. Flag actions that build Ecto queries, call `Repo`, apply business rules, or
  orchestrate multi-step work instead of calling **one context function** and rendering.
- **Why it matters:** The web layer is meant to be a thin interface. Logic in a controller
  is unreachable from a LiveView, a mix task, a job, or IEx, and gets duplicated. Contexts
  exist precisely so this logic is named and reusable.
- **Confirm (not just count):** An action that reads params, calls one context function, and
  renders (handling the `{:ok, _} | {:error, changeset}` tuple) is thin even across a few
  lines. Count the *work*, not the `conn` plumbing.
- **Fix direction:** Move the work into a context function (`MyApp.Accounts.create_user/1`);
  the action becomes pattern-match-on-result -> render. See `resources/patterns/phoenix.yaml`.
- **Default severity:** P2 when business logic/`Repo` lives in the action; P3 for action
  sprawl with otherwise-thin actions.

### 2. Context bypass (web layer → Repo/schema directly) — `context-bypass`
- **Signal:** The web layer reaching past the context straight into persistence: `Repo.*`
  (`Repo.all`, `Repo.get`, `Repo.insert`, `Repo.preload`), `from`/`Ecto.Query`, or a schema's
  `changeset/2` called **inside** `lib/*_web/**` (controllers, LiveViews, components, views).
  Grep `lib/*_web/**` for `Repo.`, `from(`, `|> Ecto.Query`, `Schema.changeset(`.
- **Why it matters:** Contexts are the application's public API and the seam where data
  access lives. When the web layer queries directly, the boundary dissolves — data-access
  rules scatter across controllers and LiveViews, the domain can't be reused or tested off
  the web, and a schema change ripples through the UI.
- **Confirm (not just count):** Calling `Repo` from a context is correct — that is the
  context's job. The smell is `Repo`/`Ecto.Query`/schema-changeset usage *in `*_web/`*. A
  documented deliberate "no contexts" architecture (some teams use operations/use-cases
  instead) is the convention there — judge against the repo's stated design.
- **Fix direction:** Add or extend a context function that owns the query/validation; the web
  layer calls the context and never `Repo`.
- **Default severity:** P2 — bypassing the context is the central Phoenix layering violation.

### 3. God context (context grouping unrelated functionality) — `god-context`
- **Signal:** A context module over `phoenix.context.max_loc` or exposing more than
  `phoenix.context.max_public_functions` public functions, especially one spanning several
  unrelated schemas/concerns. Count public `def`s and the distinct schemas it touches.
- **Why it matters:** Contexts should group **related** functionality and draw real domain
  boundaries. A god context (the classic `MyApp.Services`/`MyApp.Helpers` or a single
  `Accounts` that also does billing, notifications, and reporting) is a coupling hub — the
  opposite of what contexts are for.
- **Confirm (not just count):** A large context that is genuinely one cohesive bounded
  area (Accounts: users + tokens + sessions) is fine — size alone is weak. Flag when the
  functions cluster into 2+ unrelated domains, or unrelated schemas are colocated for no
  relational reason.
- **Fix direction:** Split into separate contexts along domain boundaries; nest related
  schemas, separate unrelated ones. Cross-context calls go through each context's public API,
  not its schemas.
- **Default severity:** P2 when distinct domains are mixed; P3 when only counts trip and the
  context is cohesive.

### 4. Fat LiveView (logic / data access in the view module) — `fat-liveview`
- **Signal:** A LiveView/LiveComponent over `phoenix.live_view.max_loc`, or an event handler
  (`handle_event`/`handle_info`) over `phoenix.live_view.max_handler_loc`, that contains
  business logic or `Repo`/Ecto access instead of delegating to a context. Grep
  `lib/*_web/live/**` for `Repo.`, `from(`, and long `handle_event` bodies.
- **Why it matters:** A LiveView is the web layer — it owns UI state and events, not the
  domain. Business logic there is untestable without the LiveView harness and unreachable
  from controllers or jobs; it also bloats the process state.
- **Confirm (not just count):** `mount`/`handle_event` that read params, call one context
  function, and assign the result to socket state are thin even with several assigns. Flag
  domain logic and direct data access.
- **Fix direction:** Move domain work to a context; the LiveView calls the context and
  manages only `assigns`/socket state. Extract presentation into function components.
- **Default severity:** P2 when business logic/`Repo` lives in the LiveView; P3 for an
  oversized but UI-only module.

### 5. Business logic / I/O in Ecto schema or changeset — `business-logic-in-changeset`
- **Signal:** A schema module over `phoenix.schema.max_loc`, or a `changeset/2` over
  `phoenix.schema.max_changeset_loc`, or a changeset/schema that performs I/O (calls `Repo`,
  HTTP, sends mail), cross-record lookups, or business rules beyond `cast` + `validate_*`.
  Grep schema files for `Repo.`, external calls, and long changeset pipelines.
- **Why it matters:** Schemas model data; changesets cast and validate it. Business logic or
  I/O there runs at surprising times (every cast, in tests and seeds), couples the data layer
  to side effects, and is hard to disable — the Phoenix analogue of callback hell.
- **Confirm (not just count):** `cast`, `validate_required`, `validate_format`,
  `unique_constraint`, and pure cross-field validations are exactly what changesets are for —
  low-risk even in numbers. Flag I/O, side effects, and business decisions.
- **Fix direction:** Keep changesets to cast + validate; move orchestration, I/O, and
  business rules into the context function that calls the changeset.
- **Default severity:** P2 when a changeset/schema performs I/O or side effects; P3 for an
  oversized but pure schema/changeset.

### 6. God module (dumping-ground module) — `god-module`
- **Signal:** Any module over `phoenix.module.max_loc` or exposing more than
  `phoenix.module.max_public_functions` public functions, holding unrelated responsibilities.
  The classic offenders are a `MyApp.Utils`/`MyApp.Helpers` grab-bag. Count public `def`s.
- **Why it matters:** A module is Elixir's unit of organization. One that holds many
  unrelated responsibilities becomes a hub every other module imports/aliases, so a change
  for one concern risks unrelated ones.
- **Confirm (not just count):** A cohesive module with many small functions serving one
  concept is fine. Flag when public functions cluster into 2+ unrelated groups, or the module
  mixes layers (web + domain + persistence).
- **Fix direction:** Split by responsibility into intention-named modules; a grab-bag `Utils`
  becomes focused modules.
- **Default severity:** P2 when distinct responsibilities mix; P3 when only counts trip and
  the module is cohesive.

### 7. Process misuse (unsupervised / scattered / code-org-by-process) — `process-misuse`
- **Signal:** Three official Elixir process anti-patterns, all detectable: (a)
  **unsupervised process** — a long-running process started outside a supervision tree:
  `spawn`/`spawn_link`, `Agent.start_link`, `GenServer.start_link`, `Task.start` called from
  app code rather than listed as a child in a `Supervisor`/`Application`. (b)
  **code-organization-by-process** — a `GenServer`/`Agent` wrapping logic that is pure (no
  concurrency, state, or shared-resource need) — a process used to *organize code*, creating
  a bottleneck. (c) **scattered process interface** — `GenServer.call`/`cast` or `Agent.get`/
  `update` for the *same* process spread across many modules instead of one wrapper module.
  Grep for `spawn(`, `start_link` outside `application.ex`/supervisors, and `GenServer.call`/
  `Agent.update` call sites across modules.
- **Why it matters:** Unsupervised processes can't be observed, ordered, or cleanly shut
  down; a process used for code organization serializes work that should be plain functions;
  scattered interfaces duplicate interaction logic and let arbitrary data formats leak in.
- **Confirm (not just count):** A `GenServer` that genuinely models runtime state/concurrency
  and is started under a supervisor, with all interaction behind its own module API, is the
  correct pattern — not a smell. Flag the *misuse*, not the use.
- **Fix direction:** Start processes inside a supervision tree (list them as children); turn
  a pure-logic GenServer into plain functions; centralize all interaction with a process in
  one wrapper module.
- **Default severity:** P2 for an unsupervised long-running process or a pure-logic GenServer;
  P3 for a scattered interface.

### 8. Law of Demeter violations (`a.b.c.d` chains) — `law-of-demeter`
- **Signal:** "Train wreck" struct/map navigation across boundaries —
  `socket.assigns.current_user.account.plan.name`, `conn.assigns.user.org.owner.email` —
  reaching through several intermediate structs. Grep for dotted struct-access chains (not
  pipe `|>` chains, which are idiomatic).
- **Why it matters:** Each extra dot couples the caller to the internal shape of every
  intermediate struct; a change to any link breaks distant code, and a missing key raises
  far from its cause.
- **Confirm (not just count):** Pipelines (`x |> f() |> g()`) and `Ecto.Query`/`Enum`
  chains are idiomatic Elixir, **not** Demeter violations. Flag struct/map *navigation*
  through other structs' internals (`a.b.c.d`).
- **Fix direction:** Add a purpose-named accessor function, pattern-match the needed value
  out at the boundary, or pass it in directly.
- **Default severity:** P3 — usually localised; escalate to P2 when duplicated widely.

## General metrics

`phoenix.general.max_function_loc` (long function -> extract / compose with pipes),
`phoenix.general.max_function_params` (long parameter list -> a struct / keyword options),
and `phoenix.general.max_nesting_depth` (deeply nested `case`/`cond`/`with` -> `with` chains,
multi-clause functions, early pattern matches) apply to any function.

## Tool enrichment (optional)

These sharpen the heuristics; the lens must degrade gracefully when they are absent. Detect
presence first (`mix help credo` / check `mix.exs` deps / `command -v mix`). Never install
anything; never block on them.
- **credo** — static code analysis for Elixir. `--strict` surfaces complexity, long
  functions, deep nesting, and many design smells that corroborate god-module/fat-controller.
- **boundary** — enforces module/context boundaries at compile time; a Boundary violation
  directly corroborates `context-bypass` and cross-context leaks.

When a tool is present, treat its output as *corroborating evidence* that raises confidence
— not as the source of truth. When absent, fall back to Read/Grep/Glob/Bash heuristics and
say so in the finding.

## Relationship

[[../principles/occams-razor]], [[../principles/convention-over-configuration]],
[[phoenix]] (conventions), patterns catalog (resources/patterns/phoenix.yaml).

## Sources
- Phoenix Guides — Contexts (the web layer is an interface; contexts centralize data access + validation, not scattered across controllers/LiveViews) — https://hexdocs.pm/phoenix/contexts.html
- Phoenix Guides — Controllers — https://hexdocs.pm/phoenix/controllers.html
- Elixir — Process-related anti-patterns (code organization by process, scattered process interfaces, sending unnecessary data, unsupervised processes) — https://hexdocs.pm/elixir/process-anti-patterns.html
- Elixir — Design-related anti-patterns — https://hexdocs.pm/elixir/design-anti-patterns.html
- Ecto — Schema and Changeset (cast/validate scope) — https://hexdocs.pm/ecto/Ecto.Changeset.html
- Law of Demeter / "train wreck" chains — https://en.wikipedia.org/wiki/Law_of_Demeter
