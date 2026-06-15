# Laravel — Architecture Smells

> one-line essence: structural anti-patterns that make a Laravel app hard to change.

## How the lens uses this doc

Heuristic-first (count + responsibility judgment via Read/Grep/Glob/Bash); optionally
enrich with `phpstan`/`larastan`, `phpmd`, or `phpinsights` if installed (never required).
Thresholds come from resolved config (`config/defaults/thresholds.yaml` ->
`.intense/thresholds.yaml` override). A threshold is a SIGNAL to look closer, not an
automatic verdict — judge responsibilities.

Laravel folklore says **"fat models, skinny controllers"** — push logic out of controllers
into Eloquent models. Taken literally that just relocates the God object: the model becomes
the dumping ground (persistence + business rules + formatting + external calls). The modern
community reading is the same "thin everything" Rails arrived at — controllers orchestrate,
models persist (with cohesive, entity-local behaviour, scopes, casts, relationships), and
behaviour that is neither persistence nor HTTP orchestration moves into a dedicated object:
a **Service** (a cohesive set of operations for one concept) or an **Action** (one
single-purpose invokable command). Both are valid; the smells below detect where that has
broken down. When a repo states its own structure in `CLAUDE.md`/`AGENTS.md` (e.g. "we use
Actions, not Services"), that local choice wins.

## Smells (detectable)

**Canonical smell ids** (the stable vocabulary used by the finding `smell` field, the
`severity_overrides` keys in `.intense/ways-of-working.yaml`, and the architecture lens).
Smell ids are **kebab-case**; design-pattern ids (in `patterns/laravel.yaml`) are
**snake_case** — two adjacent id systems, deliberately distinct casing.

| Smell id | Section |
|----------|---------|
| `fat-controller` | 1. Fat controller (logic / inline validation in actions) |
| `fat-model` | 2. Fat Eloquent model / God model |
| `god-class` | 3. God class (high fan-out service/manager/action) |
| `misused-service` | 4. Misused service / action |
| `query-in-view` | 5. Queries in Blade / N+1 / fat view composer |
| `logic-in-routes` | 6. Business logic in route files |
| `fat-job` | 7. Business logic in Job / Listener / Command |
| `law-of-demeter` | 8. Law of Demeter violations |

### 1. Fat controller (logic / inline validation in actions) — `fat-controller`
- **Signal:** Controller LOC over `laravel.controller.max_loc`; any single action over
  `laravel.controller.max_action_loc`; action count over `laravel.controller.max_actions`
  (well beyond the resourceful index/show/create/store/edit/update/destroy seven). Grep
  `app/Http/Controllers/**` for: inline `$request->validate(` / `Validator::make(` (should
  be a **FormRequest**), business branching, file handling (`$request->file(...)->move`),
  external API calls, and `.where`/query building in actions.
- **Why it matters:** Controllers are the hardest layer to test (HTTP harness, middleware,
  sessions). Logic trapped there is unreachable from a job, an Artisan command, or another
  action, and gets duplicated across endpoints. Inline validation scatters the request
  contract across the action body.
- **Confirm (not just count):** A controller with many *thin* resourceful actions that each
  type-hint a FormRequest and delegate one line to a service/action is not fat — count
  action *bodies*, not action *names*. Response shaping (returning a view / `JsonResource` /
  redirect) is legitimate controller work.
- **Fix direction:** Validation -> a `FormRequest` (`app/Http/Requests`). Business logic ->
  a Service or single-purpose Action. Non-resourceful actions usually mean a missing
  resource — extract a new controller (convention over configuration). See
  `resources/patterns/laravel.yaml`.
- **Default severity:** P2 when business logic lives in the action; P3 for non-resourceful
  sprawl or inline validation with otherwise-thin actions.

### 2. Fat Eloquent model / God model — `fat-model`
- **Signal:** A model whose size or breadth exceeds `laravel.model.*`:
  `laravel.model.max_loc` (LOC), `laravel.model.max_public_methods`,
  `laravel.model.max_relationships` (hasOne/hasMany/belongsTo/belongsToMany/morph*), and
  `laravel.model.max_scopes` (`scopeX` methods). Beyond counts, look for *multiple reasons
  to change* in one file: persistence + business rules + formatting + external API calls +
  notification dispatch.
- **Why it matters:** Every collaborator couples to the whole model. Tests get slow and
  wide, and a change for one concern risks unrelated ones — the classic Single
  Responsibility violation. "Fat models" is good advice for *persistence and cohesive
  entity behaviour*; it is bad advice as a license to dump every concern in the model.
- **Confirm (not just count):** A large model can be legitimate if cohesive — relationships,
  casts, accessors/mutators, and scopes that all describe the same entity belong here.
  Before flagging, ask: do the public methods cluster into 2+ *unrelated* groups (e.g. PDF
  rendering + payment-gateway calls + the entity's own data)? High LOC from one giant method
  is a *long method* smell (`laravel.general.max_method_loc`), not a God model.
- **Fix direction:** Extract behaviour, don't just hide it. Domain operation -> Service /
  Action; reusable query -> a query scope or query object; external calls -> an adapter/
  client; presentation -> an API Resource / view. Keep persistence + cohesive entity
  behaviour in the model.
- **Default severity:** P3 when only counts trip and the model is cohesive; P2 when multiple
  distinct responsibilities are mixed (true God model).

### 3. God class (high fan-out service/manager/action) — `god-class`
- **Signal:** Any class that references or instantiates more distinct classes than
  `laravel.god_class.max_collaborators`, or exceeds `laravel.god_class.max_loc`. Count
  distinct imported/`new`'d/`app()`-resolved/constructor-injected types (fan-out). The
  classic offender is a `*Manager`/`*Service` that does everything an endpoint needs.
- **Why it matters:** A high-fan-out class knows about the whole system, so the whole system
  depends on it. It can't be understood, tested, or reused in isolation and attracts more
  responsibility over time.
- **Confirm (not just count):** A composition root or a `ServiceProvider` legitimately wires
  many classes — that is its job. Distinguish *wiring* (acceptable fan-out at the edge) from
  *logic* (a class doing many unrelated things). Count only collaborators it actively drives,
  not value/data objects it passes through.
- **Fix direction:** Split by responsibility; introduce intermediary objects so the hub talks
  to a few abstractions instead of many concretes. Apply [[../principles/occams-razor]].
- **Default severity:** P2 — high fan-out is a strong structural signal and rarely benign.

### 4. Misused service / action — `misused-service`
- **Signal:** A Service exposing more than `laravel.service.max_public_methods` public
  methods, or exceeding `laravel.service.max_loc`; or an **Action** (a single-purpose
  command) that exposes more than one public entry. Three failure modes: (a) **grab-bag** —
  many unrelated public methods in one `*Service`, really a namespace/utility class; (b)
  **God service** — one method that does everything the fat model used to; (c) **anemic
  pass-through** — a method that only forwards to one Eloquent call, adding a layer with no
  behaviour. An Action should answer one `handle()`/`execute()`/`__invoke()`.
- **Why it matters:** Services and Actions exist to give a business operation a name and a
  testable seam. A grab-bag dissolves the seam; a God service relocates the bloat; a
  pass-through adds indirection without value — the opposite of least astonishment.
- **Confirm (not just count):** Private helpers are fine and expected — count only public
  entry points. A `*Service` exposing a small set of cohesive operations on one concept is
  healthy. For pass-through suspicion, check whether it adds validation, orchestration,
  transaction boundaries (`DB::transaction`), or error handling; if it does, it earns its
  place.
- **Fix direction:** Grab-bag -> split into one Service per concern, or one Action per
  operation named after the action. God service -> decompose into composed Actions.
  Pass-through -> inline it and delete the layer. See `resources/patterns/laravel.yaml`.
- **Default severity:** P2 for a God service; P3 for grab-bag or pass-through.

### 5. Queries in Blade / N+1 / fat view composer — `query-in-view`
- **Signal:** View composers over `laravel.view.max_loc`. In `resources/views/**` (`.blade.php`),
  Grep for model access that triggers queries inside loops — `@foreach (Model::...` , a
  relation access like `$user->profile->...` inside `@foreach` without eager loading, `->get()`/
  `->all()`/`->where(` in templates, and business branching. Any DB access or business rule
  in a template is the smell; relation access in a loop over a non-eager-loaded collection is
  the **N+1** signal.
- **Why it matters:** Queries in views cause N+1 problems, can't be cached or tested, and
  scatter data-access rules across the presentation layer. A fat view composer becomes a
  second God object of unrelated data loading.
- **Confirm (not just count):** Accessing an **eager-loaded** relation in a view
  (`User::with('profile')` upstream) is fine — the smell is the *missing* `with()` plus
  per-row access, or a raw query in the template. Pure presentation (formatting a cast date,
  building a CSS class) is exactly what Blade is for.
- **Fix direction:** Load data in the controller/action (eager-load with `with()`), pass
  prepared data (or an API Resource / view model) to the view; move display logic into a
  Blade component or presenter. See the N+1 guidance in the Laravel Eloquent docs.
- **Default severity:** P2 for queries/N+1 in views (correctness + performance); P3 for an
  oversized but presentation-only composer.

### 6. Business logic in route files — `logic-in-routes`
- **Signal:** Closures with real bodies in `routes/web.php` / `routes/api.php` —
  `Route::get('/x', function () { ...many lines... })` containing queries, branching, or
  domain work, rather than `[Controller::class, 'method']` references. Grep route files for
  `function (` closures over a few lines.
- **Why it matters:** Route closures can't be route-cached (`php artisan route:cache` fails
  with closures), aren't testable in isolation, and hide behaviour where no one looks for it.
  "Never put any logic in routes files" is long-standing Laravel guidance.
- **Confirm (not just count):** A one-line closure (`fn () => view('welcome')`) is fine.
  Flag closures that do domain work or grow past a trivial redirect/view.
- **Fix direction:** Point the route at a controller action (or a single-action invokable
  controller / Action) and move the body there.
- **Default severity:** P3 — usually localised; escalate to P2 when route-caching is broken
  or the closure holds real business logic.

### 7. Business logic in Job / Listener / Command — `fat-job`
- **Signal:** A queued `Job`, event `Listener`, or Artisan `Command` whose `handle()` body
  (over `laravel.general.max_method_loc`) contains the business logic inline rather than
  delegating to a Service/Action. Grep `app/Jobs/**`, `app/Listeners/**`, `app/Console/**`.
  Also flag jobs that accept whole Eloquent models as constructor args, or non-idempotent
  work that double-applies on retry.
- **Why it matters:** Jobs/listeners should *orchestrate* deferred work, not *own* it.
  Business logic inlined there is unreachable from the request path or another job and is
  hard to test. Whole-model args bloat the queue payload and can deserialize stale data.
- **Confirm (not just count):** A thin `handle()` that resolves a Service and calls one
  method is healthy even with a few setup lines. Flag inlined domain logic and fat bodies.
- **Fix direction:** Move the logic into a Service/Action the `handle()` calls; pass
  ids/`SerializesModels` references, not whole graphs; make the work idempotent.
- **Default severity:** P2 when domain logic is inlined or work is non-idempotent; P3 for a
  moderately long but delegating handler.

### 8. Law of Demeter violations (`a->b->c->d` chains) — `law-of-demeter`
- **Signal:** "Train wreck" chains navigating across object boundaries —
  `$order->customer->address->city`, `$user->account->plan->name` — more than one arrow of
  *navigation* (not fluent query builders). Grep code and Blade for `->` chains reaching
  through intermediate objects.
- **Why it matters:** Each extra arrow couples the caller to the internal shape of every
  intermediate object; a change to any link breaks distant code, and a `null` mid-chain
  throws far from its cause (mitigated but not fixed by `?->`).
- **Confirm (not just count):** Chains on the Eloquent query builder
  (`Model::where()->latest()->get()`), on a Collection pipeline, or on a value object you own
  are not Demeter violations — they operate on one returned object of the same kind. Flag
  chains that *navigate relationships/attributes* across distinct objects' internals.
- **Fix direction:** Add a purpose-named accessor on the nearest object that hides the
  traversal (`$order->shippingCity()`), or pass the needed value in directly.
- **Default severity:** P3 — usually a localised readability/coupling smell; escalate to P2
  when the same chain is duplicated widely (systemic coupling).

## General metrics

`laravel.general.max_method_loc` (long method -> extract) and
`laravel.general.max_method_params` (long parameter list -> introduce a DTO / data object /
FormRequest) apply to any method as cross-cutting signals. High complexity on one method =
refactor that method; complexity spread across a class = decompose the class.

## Tool enrichment (optional)

These sharpen the heuristics; the lens must degrade gracefully when they are absent. Detect
presence first (e.g. `command -v phpstan` / check `composer.json` `require-dev` /
`vendor/bin/phpstan`). Never install anything; never block on them.
- **larastan / phpstan** — static analysis; high-level rules and complexity hints corroborate
  god-class and fat-method findings.
- **phpmd** (PHP Mess Detector) — `ExcessiveClassLength`, `TooManyMethods`,
  `ExcessiveMethodLength`, `CouplingBetweenObjects` map directly onto fat-model/god-class/
  long-method.
- **phpinsights** — architecture + complexity scores per class; fold into the responsibility
  judgment.

When a tool is present, treat its output as *corroborating evidence* that raises confidence
— not as the source of truth. When absent, fall back to Read/Grep/Glob/Bash heuristics and
say so in the finding.

## Relationship

[[../principles/occams-razor]], [[../principles/convention-over-configuration]],
[[laravel]] (conventions), patterns catalog (resources/patterns/laravel.yaml).

## Sources
- Laravel best practices (community canon: SRP, fat models/skinny controllers, validation in Request classes, service classes, N+1) — https://github.com/alexeymezenin/laravel-best-practices
- Laravel docs — Controllers (resourceful controllers, single-action controllers) — https://laravel.com/docs/controllers
- Laravel docs — Eloquent Relationships: Eager Loading (the N+1 problem) — https://laravel.com/docs/eloquent-relationships#eager-loading
- Laravel docs — Form Request Validation — https://laravel.com/docs/validation#form-request-validation
- Laravel Actions (single-purpose invokable command objects) — https://github.com/lorisleiva/laravel-actions
- Service Class, Action Class, and Use Case Class: when to use each in Laravel — https://qadrlabs.com/post/service-class-action-class-and-use-case-class-what-they-are-and-when-to-use-each-in-laravel
- Law of Demeter / "train wreck" chains — https://en.wikipedia.org/wiki/Law_of_Demeter
