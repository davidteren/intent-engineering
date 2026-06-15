# Express / Node — Architecture Smells

> one-line essence: structural anti-patterns that make an Express/Node service hard to change.

## How the lens uses this doc

Heuristic-first (count + responsibility judgment via Read/Grep/Glob/Bash); optionally
enrich with `eslint` (complexity / `no-floating-promises`), `madge` (circular deps), or
`depcruise` if installed (never required). Thresholds come from resolved config
(`config/defaults/thresholds.yaml` -> `.intense/thresholds.yaml` override). A threshold is a
SIGNAL to look closer, not an automatic verdict — judge responsibilities.

Express is deliberately **unopinionated** — it gives you routing and middleware and no
guidance on where logic goes. Left unstructured, a service becomes "thirty files that import
each other in weird ways", with business logic, validation, and SQL all stuffed into route
handlers. The battle-tested answer is a **layered (3-layer) architecture**: route handlers /
controllers (the web/transport edge) -> a **service layer** that owns business logic and is
HTTP-agnostic -> a **data-access layer** (repositories / ORM models). Middleware handles
cross-cutting concerns; a centralized error handler turns thrown errors into responses;
side effects fan out via events (pub/sub). The smells below detect where that layering has
broken down. When a repo states its own structure in `CLAUDE.md`/`AGENTS.md`, that wins.

## Smells (detectable)

**Canonical smell ids** (the stable vocabulary used by the finding `smell` field, the
`severity_overrides` keys in `.intense/ways-of-working.yaml`, and the architecture lens).
Smell ids are **kebab-case**; design-pattern ids (in `patterns/express.yaml`) are
**snake_case** — two adjacent id systems, deliberately distinct casing.

| Smell id | Section |
|----------|---------|
| `fat-route-handler` | 1. Fat route handler / controller (logic at the edge) |
| `god-module` | 2. God module (dumping-ground file) |
| `god-object` | 3. God object (high fan-out class) |
| `misused-service` | 4. Misused service layer |
| `layer-leak` | 5. Layer leak (transport ↔ domain ↔ data bleed) |
| `fat-middleware` | 6. Fat / side-effecting middleware |
| `async-error-gap` | 7. Unhandled async / error-handling gap |
| `law-of-demeter` | 8. Law of Demeter violations |

### 1. Fat route handler / controller (logic at the edge) — `fat-route-handler`
- **Signal:** A router file over `express.route.max_loc`, a controller over
  `express.controller.max_loc`, any single handler body over `express.route.max_handler_loc`
  / `express.controller.max_handler_loc`, or a router declaring more than
  `express.route.max_routes` routes. Grep `routes/**` and `controllers/**` for
  `router.(get|post|put|patch|delete)` / `app.(get|post|...)` and measure the handler body.
  Flag handlers that compute results, build queries (`Model.find`, raw SQL, `knex`), call
  external APIs, orchestrate multi-step writes, or branch on business rules instead of
  delegating to a service and sending the response.
- **Why it matters:** Route handlers are bound to `req`/`res` and the HTTP harness — the
  hardest layer to unit-test (you end up mocking `req`/`res`). Logic trapped there is
  unreachable from a worker, a CLI, or a cron job, and gets duplicated across routes.
  Inline business logic in a route is the single most common Express anti-pattern.
- **Confirm (not just count):** A handler that validates (via a validation middleware/schema),
  calls one service function, and sends the result is *thin* — even with a few lines of
  response shaping (status code, headers). Count the *work*, not the route registration.
- **Fix direction:** Move computation into a **service** that receives plain inputs and
  returns domain values, knowing nothing about `req`/`res`; keep the handler as
  parse-request -> call service -> send response -> `next(err)` on failure. Route inline
  closures in `routes/*.js` are the same smell — extract to a controller/service.
- **Default severity:** P2 when business logic lives in the handler; P3 for route sprawl
  with otherwise-thin handlers.

### 2. God module (dumping-ground file) — `god-module`
- **Signal:** A module over `express.module.max_loc`, or exporting more than
  `express.module.max_exports` public names. The classic offenders are a single giant
  `index.js`/`app.js`/`routes.js`, or a `utils.js`/`helpers.js` that accretes unrelated
  functions. Count `module.exports`/`export` names and top-level declarations. Module-level
  mutable state (a top-level `let`/object mutated at runtime, a cache hiding config) is a
  strong corroborating signal.
- **Why it matters:** A module is Node's primary unit of reuse. One that holds many
  unrelated responsibilities becomes a hub every other file imports, so a change for one
  concern risks unrelated ones, and circular `require`/`import` cycles cluster around it.
- **Confirm (not just count):** A cohesive module with many small functions serving one
  concept (one validation module, one date module) is fine. Flag when the exports cluster
  into 2+ unrelated groups, or the module mixes layers (HTTP + DB + domain rules in one
  file — the unstructured "everything in the route file" shape).
- **Fix direction:** Split by responsibility into layered modules (routes / controllers /
  services / data-access) and intention-named modules; replace a grab-bag `utils.js`.
- **Default severity:** P2 when distinct responsibilities or shared mutable state mix; P3
  when only counts trip and the module is cohesive.

### 3. God object (high fan-out class) — `god-object`
- **Signal:** Any class/module referencing or instantiating more distinct collaborators than
  `express.god_object.max_collaborators`, or exceeding `express.god_object.max_loc`. Count
  distinct `require`/`import`'d, `new`'d, or injected types (fan-out).
- **Why it matters:** A high-fan-out unit knows about the whole system, so the whole system
  depends on it. It can't be understood, tested, or reused in isolation.
- **Confirm (not just count):** A composition root / app factory / DI container legitimately
  wires many modules — that is its job (see `app_factory` in the catalog). Distinguish
  *wiring* (acceptable fan-out at the edge) from *logic*. Count only collaborators it
  actively drives, not plain data/DTOs.
- **Fix direction:** Split by responsibility; introduce intermediary abstractions. Apply
  [[../principles/occams-razor]].
- **Default severity:** P2 — high fan-out is a strong structural signal and rarely benign.

### 4. Misused service layer — `misused-service`
- **Signal:** A service module/class exposing more than `express.service.max_public_methods`
  public entrypoints, or exceeding `express.service.max_loc`. Three failure modes: (a)
  **grab-bag** — many unrelated public functions in one `*.service.js`, really a namespace;
  (b) **god service** — one function that does everything an endpoint needs end to end; (c)
  **anemic pass-through** — a service method that only forwards to one model/repository call,
  adding a layer with no behaviour.
- **Why it matters:** The service layer exists to give a business operation a name and a
  testable, HTTP-agnostic seam (callable from a route, a worker, or a cron job). A grab-bag
  dissolves the seam; a god service relocates the bloat; a pass-through adds indirection
  without value.
- **Confirm (not just count):** Private helpers are fine — count only public entrypoints. A
  service exposing a few cohesive operations on one concept is healthy. For pass-through
  suspicion, check whether it adds validation, orchestration, transaction boundaries, or
  error handling.
- **Fix direction:** Grab-bag -> split per concern; god service -> decompose into composed
  steps / emit events for side effects (pub/sub); pass-through -> inline and delete.
- **Default severity:** P2 for a god service; P3 for grab-bag or pass-through.

### 5. Layer leak (transport ↔ domain ↔ data bleed) — `layer-leak`
- **Signal:** Three directions. (a) **Service knows HTTP:** a service/domain module
  references `req`/`res`/`next`, returns a status code or headers, or imports `express`.
  Grep `services/**` for `req`, `res`, `res.status`, `res.json`, `require('express')`. (b)
  **Controller skips the service into data:** a route/controller calls the ORM/DB directly
  (`Model.find`, `sequelize`, `prisma.`, `knex`, raw SQL) when a service/repository seam
  exists. Grep `routes/**` and `controllers/**` for those. (c) **Data-access leaks
  outward:** a repository returns a live ORM query builder / Mongoose query instead of a
  resolved domain object.
- **Why it matters:** The layering exists so the domain is reusable off the request path and
  the transport/data layers are swappable. Each leak couples them: a service that touches
  `res` can't run in a worker; a controller that queries directly scatters data-access rules.
- **Confirm (not just count):** A service raising a *domain* error that a controller maps to
  HTTP is correct — the leak is the service importing `res`/`express` itself. A small app
  with a documented no-service design isn't leaking; judge against the repo's stated layering.
- **Fix direction:** Services take plain inputs and return domain values / throw domain
  errors; controllers translate to HTTP. Route DB work through a service or repository.
- **Default severity:** P2 when the service depends on transport (HTTP in domain); P3 for a
  controller doing data-access a thin service would own.

### 6. Fat / side-effecting middleware — `fat-middleware`
- **Signal:** A middleware function (`(req, res, next)`) over `express.middleware.max_loc`,
  or one that performs business work rather than a cross-cutting concern. Grep `middleware/**`
  and `app.use(`/`router.use(`. Flag middleware that runs domain queries, mutates business
  state, calls external services, or never calls `next()` on a path (hanging request).
- **Why it matters:** Middleware runs implicitly for every matched request, in registration
  order. Business logic there is invisible at the route, hard to test, and order-coupled. A
  middleware that forgets `next()` on a branch hangs the request.
- **Confirm (not just count):** Auth, body parsing, logging, rate-limiting, request-id, and
  validation are exactly what middleware is for, even with a few branches. Flag domain work
  and mutable shared state on the middleware closure.
- **Fix direction:** Keep middleware to one cross-cutting concern that always calls `next()`
  (or `next(err)`); push business operations into a service the handler calls.
- **Default severity:** P2 when middleware performs domain work or hangs requests; P3 for an
  oversized but cross-cutting-only middleware.

### 7. Unhandled async / error-handling gap — `async-error-gap`
- **Signal:** (a) `async` route handlers without error capture — an `await` that can reject
  with no surrounding `try/catch` and no async wrapper, so the rejection becomes an
  unhandled promise rejection (Express 4 does **not** catch async errors). (b) No
  **centralized error-handling middleware** (`(err, req, res, next)`) — errors handled ad
  hoc per route or not at all. (c) **Swallowed errors** — empty `catch {}`, `.catch(() => {})`,
  or logging-and-continuing where a failure must propagate. (d) **Callback hell / pyramid of
  doom** — nesting past `express.general.max_nesting_depth` of callbacks where
  promises/`async`-`await` belong. Grep for `async (req, res`, `.catch(`, `try {`, nested
  callbacks.
- **Why it matters:** An uncaught rejection can crash the process or leave a request hanging;
  swallowed errors hide failures from clients and monitoring; scattered error handling
  duplicates response shaping and drifts. Robust async error handling is the backbone of a
  reliable Node service.
- **Confirm (not just count):** A handler whose every `await` is inside `try/catch` (or
  wrapped by an `asyncHandler`/`express-async-errors`) and forwards via `next(err)` is fine.
  A genuinely intentional ignored error must be narrow and commented.
- **Fix direction:** Wrap async handlers (`asyncHandler`, `express-async-errors`) or
  `try/catch` + `next(err)`; add one centralized error-handling middleware that maps errors
  to responses and distinguishes operational from programmer errors; never swallow.
- **Default severity:** P2 for an uncaught async path or a swallowed error on a real failure
  mode; P3 for missing centralization where per-route handling is otherwise correct.

### 8. Law of Demeter violations (`a.b.c.d` chains) — `law-of-demeter`
- **Signal:** "Train wreck" chains navigating across object boundaries —
  `req.user.account.plan.name`, `order.customer.address.city` — more than one dot of
  *navigation* (not fluent builders / promise chains). Grep code for attribute chains
  reaching through intermediate objects.
- **Why it matters:** Each extra dot couples the caller to the internal shape of every
  intermediate object; a change to any link breaks distant code, and an `undefined` mid-chain
  throws far from its cause (mitigated but not fixed by `?.`).
- **Confirm (not just count):** Chains on a query builder (`knex('t').where().orderBy()`), a
  promise chain, or a value object you own are not Demeter violations. Flag chains that
  *navigate properties/relations* across distinct objects' internals.
- **Fix direction:** Add a purpose-named accessor on the nearest object, or pass the needed
  value in directly.
- **Default severity:** P3 — usually localised; escalate to P2 when the same chain is
  duplicated widely (systemic coupling).

## General metrics

`express.general.max_function_loc` (long function -> extract), `express.general.max_function_params`
(long parameter list -> options object / DTO), and `express.general.max_nesting_depth` (deep
nesting / callback hell -> async-await, early returns) apply to any function as cross-cutting
signals.

## Tool enrichment (optional)

These sharpen the heuristics; the lens must degrade gracefully when they are absent. Detect
presence first (`command -v eslint` / check `package.json` devDependencies / `npx madge`).
Never install anything; never block on them.
- **eslint** — `complexity`, `max-depth`, `max-lines`, `max-params`, and (with
  `@typescript-eslint`) `no-floating-promises`/`no-misused-promises` map onto god-object,
  callback hell, and the async-error-gap. If the project configures ESLint, fold it in.
- **madge / dependency-cruiser** — circular-dependency and module-graph detection;
  corroborate god-module and cross-layer coupling (a `services/` importing `routes/` is a
  layer-leak the graph reveals).

When a tool is present, treat its output as *corroborating evidence* that raises confidence
— not as the source of truth. When absent, fall back to Read/Grep/Glob/Bash heuristics and
say so in the finding.

## Relationship

[[../principles/occams-razor]], [[../principles/convention-over-configuration]],
[[express]] (conventions), [[typescript]] (when the service is TypeScript),
patterns catalog (resources/patterns/express.yaml).

## Sources
- Bulletproof node.js project architecture — 3-layer architecture, "don't put business logic in controllers", service layer, pub/sub, loaders — https://www.softwareontheroad.com/ideal-nodejs-project-structure/
- Node.js Best Practices (goldbergyoni) — Project Structure: structure by components, layer your components, separate Express 'app' and 'server' — https://github.com/goldbergyoni/nodebestpractices
- Express docs — Error Handling (centralized error-handling middleware; async errors) — https://expressjs.com/en/guide/error-handling.html
- Express docs — Production Best Practices: Performance and Reliability — https://expressjs.com/en/advanced/best-practice-performance.html
- The Twelve-Factor App — Config (store config in the environment) — https://12factor.net/config
- Law of Demeter / "train wreck" chains — https://en.wikipedia.org/wiki/Law_of_Demeter
