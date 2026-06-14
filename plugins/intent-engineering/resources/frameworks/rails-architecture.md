# Rails — Architecture Smells
> one-line essence: structural anti-patterns that make a Rails app hard to change

## How the lens uses this doc
Heuristic-first (count + responsibility judgment via Read/Grep/Glob/Bash); optionally
enrich with reek / flog / brakeman if installed (never required). Thresholds come from
resolved config (config/defaults/thresholds.yaml -> .intense/thresholds.yaml override).
A threshold is a SIGNAL to look closer, not an automatic verdict — judge responsibilities.

The original "skinny controllers, fat models" advice (DHH / Rails folklore) solved
controller bloat by pushing logic down into ActiveRecord models. Taken literally it
just relocates the God object: the model becomes the dumping ground. The modern
reading is "thin everything" — controllers orchestrate, models persist, and behaviour
that is neither persistence nor orchestration moves into dedicated objects (service /
interactor / form / query / value / concern). The smells below detect where that has
broken down.

## Smells (detectable)

**Canonical smell ids** (the stable vocabulary used by the finding `smell` field, the
`severity_overrides` keys in `.intense/ways-of-working.yaml`, and the architecture
lens). Smell ids are **kebab-case**; design-pattern ids (in `patterns/rails.yaml`) are
**snake_case** — two adjacent id systems, deliberately distinct casing so a value's kind
is obvious at a glance.

| Smell id | Section |
|----------|---------|
| `fat-model` | 1. Fat model / God model |
| `god-object` | 2. God object (general) |
| `fat-controller` | 3. Fat controller |
| `misused-service` | 4. Misused service object |
| `callback-hell` | 5. Callback hell |
| `query-in-view` | 6. Query logic in views / fat helper |
| `law-of-demeter` | 7. Law of Demeter violations |

### 1. Fat model / God model — `fat-model`
- **Signal:** A model whose size or breadth exceeds `rails.model.*`. Check
  `rails.model.max_loc` (LOC), `rails.model.max_public_methods` (public method count),
  `rails.model.max_associations` (has_many/belongs_to/has_one/has_and_belongs_to_many),
  and `rails.model.max_callbacks` (before/after/around_* declarations). Grep for
  association and callback macros; count public methods between `class` and any
  `private`/`protected`. Beyond counts, look for *multiple reasons to change* in one
  file: persistence + business rules + formatting + external API calls + state machine.
- **Why it matters:** Every collaborator of the model is coupled to all of it. Tests
  get slow and wide, merge conflicts cluster, and a change for one concern risks
  breaking unrelated ones. This is the classic Single Responsibility violation.
- **Confirm (not just count):** A large model can be legitimate if it is cohesive — all
  methods operate on the same instance state and express one concept. Before flagging,
  ask: do the public methods cluster into 2+ unrelated groups? Are there private helper
  clusters that only serve one public method? High LOC with low method count (e.g. one
  giant report method) is a *long method* smell, not a God model — classify accordingly
  (a single method over `rails.general.max_method_loc` is the long-method signal).
- **Fix direction:** Extract behaviour, don't just hide it. Domain operation ->
  service/interactor object; user-input shaping/validation -> form object; complex
  scopes -> query object; primitive obsession -> value object; genuinely cohesive
  sub-aspect of the same entity -> concern (a concern that is just a code-hiding mixin
  is not a fix). See the patterns catalog (resources/patterns/rails.yaml).
- **Default severity:** P3 when only counts trip and the model is cohesive; P2 when
  multiple distinct responsibilities are mixed (true God model).

### 2. God object (general — high collaborators / fan-out)
- **Signal:** Any class (not only a model) that references or instantiates more distinct
  classes than `rails.god_object.max_collaborators`, or exceeds `rails.god_object.max_loc`.
  Count distinct constant references / `.new` targets / injected dependencies (fan-out).
  Reek's *Large Class* (Too Many Methods, Too Many Instance Variables) and *Feature Envy*
  map directly to this.
- **Why it matters:** A high-fan-out class is a coordination hub — it knows about the
  whole system, so the whole system depends on it. It cannot be understood, tested, or
  reused in isolation, and it attracts more responsibility over time.
- **Confirm (not just count):** A composition root, a container, or a deliberate facade
  legitimately touches many classes — that is its job. Distinguish *wiring* (acceptable
  fan-out at the edge) from *logic* (a class doing many unrelated things). Count only
  collaborators it actively drives, not value types or plain data it passes through.
- **Fix direction:** Split by responsibility; introduce intermediary objects so the hub
  talks to a few abstractions instead of many concretes. Apply
  [[../principles/occams-razor]] — collapse only when one concept is genuinely shared.
- **Default severity:** P2 — high fan-out is a strong structural signal and rarely benign
  outside composition roots.

### 3. Fat controller (logic in actions, too many actions, non-RESTful)
- **Signal:** Controller LOC over `rails.controller.max_loc`; any single action over
  `rails.controller.max_action_loc` (business logic leaking into the action); action
  count over `rails.controller.max_actions` (well beyond the RESTful index/show/new/
  create/edit/update/destroy seven). Grep for non-standard public action names, deeply
  nested conditionals in actions, direct external API/business calls, and `.where`/query
  building inside actions.
- **Why it matters:** Controllers are the hardest layer to test (HTTP harness, params,
  sessions). Logic trapped there is duplicated across actions and unreachable from jobs,
  rake tasks, or console. Non-RESTful sprawl signals missing resources.
- **Confirm (not just count):** A controller with many *thin* actions that each delegate
  one line to a service is not fat — count action *bodies*, not action *names*. Strong
  params, response negotiation, and redirects are legitimate controller work. A long
  action that is purely a sequence of `render`/`respond_to` branches is presentation, not
  business logic.
- **Fix direction:** Extra non-RESTful actions usually mean a missing resource — extract
  a new controller (convention over configuration: [[../principles/convention-over-configuration]]).
  In-action business logic -> service/interactor; param shaping -> form object; query
  building -> query object. See resources/patterns/rails.yaml.
- **Default severity:** P2 when business logic lives in actions; P3 for non-RESTful
  sprawl with otherwise-thin actions.

### 4. Misused service object
- **Signal:** A service exposing more than `rails.service_object.max_public_methods`
  (default 1 — a service should answer one `call`/`perform`), or exceeding
  `rails.service_object.max_loc` (a service this big is a God object in disguise).
  Three distinct failure modes: (a) **multiple public methods** — it's really a namespace
  or a mini-model; (b) **God service** — one `call` that does everything the fat model
  used to; (c) **anemic pass-through** — a `call` that only forwards to one model method,
  adding a layer with no behaviour.
- **Why it matters:** Service objects exist to give a single business operation a name and
  a testable seam. Multiple public methods dissolve that seam; a God service just moves
  the bloat; a pass-through adds indirection without value, the opposite of least
  astonishment.
- **Confirm (not just count):** Private helper methods are fine and expected — only count
  *public* entry points. A service with one public `call` and several privates is healthy.
  For pass-through suspicion, check whether the service adds validation, orchestration,
  transaction boundaries, or error handling; if it does, it earns its place.
- **Fix direction:** Multiple public methods -> split into one service per operation, or
  promote to a properly-modelled object. God service -> decompose into composed
  interactors/steps. Pass-through -> inline it and delete the layer. See
  resources/patterns/rails.yaml.
- **Default severity:** P2 for a God service; P3 for multi-method or pass-through services.

### 5. Callback hell
- **Signal:** Callback declarations over `rails.model.max_callbacks`. Grep for
  `before_*`/`after_*`/`around_*` (save/create/update/destroy/validation/commit). Beyond
  count, flag callbacks that: depend on execution order, fire side effects (emails, jobs,
  external calls, writes to other records), or are conditional (`if:`/`unless:`) on
  transient state.
- **Why it matters:** Callbacks run implicitly on every persistence event, including
  fixtures, seeds, bulk imports, and unrelated updates. They make object lifecycle
  non-obvious (violating least astonishment), couple persistence to side effects, and are
  notoriously painful to test and to disable when you don't want them.
- **Confirm (not just count):** Pure, idempotent, in-record callbacks (e.g. normalising a
  field, setting a default, maintaining a counter on the same row) are low-risk even in
  numbers. The danger is *side-effecting* and *order-dependent* callbacks. Weight those
  far more heavily than count alone.
- **Fix direction:** Move side effects into an explicit service/interactor invoked from
  the controller or job, so the operation is named and callable on demand. Keep only
  pure, persistence-local callbacks. Form objects absorb input-driven logic. See
  resources/patterns/rails.yaml.
- **Default severity:** P2 when callbacks trigger side effects or cross-record writes;
  P3 for high count of pure in-record callbacks.

### 6. Query logic in views / fat helper
- **Signal:** Helpers over `rails.helper.max_loc`. In views/helpers, Grep `.erb`/`.haml`/
  `.slim` and `app/helpers` for `.where`, `.order`, `.includes`, `.joins`, model class
  references, `.find`, or N+1-prone iteration with per-item queries. Any DB access or
  business branching in a template is the smell.
- **Why it matters:** Queries in views cause N+1 problems, can't be cached or tested, and
  scatter data-access rules across the presentation layer. Fat helpers become a second
  God object full of unrelated formatting + logic + queries.
- **Confirm (not just count):** Pure presentation helpers (formatting dates, building
  CSS classes, rendering markup) are exactly what helpers are for — size alone is weak
  evidence if the helper is cohesive presentation. Flag when a helper queries the DB,
  embeds business rules, or mixes many unrelated concerns.
- **Fix direction:** Move data loading into the controller (or a query object) and pass
  prepared data to the view; move display logic into a presenter/decorator or view
  component; keep helpers small and presentation-only. See resources/patterns/rails.yaml.
- **Default severity:** P2 for queries in views (correctness + N+1 risk); P3 for an
  oversized but presentation-only helper.

### 7. Law of Demeter violations (`a.b.c.d` chains)
- **Signal:** "Train wreck" chains — `object.assoc.assoc.attr` reaching across more than
  one dot of *navigation* (not fluent builders). Grep templates and code for chains like
  `order.customer.address.city` or `user.account.plan.name`. Reek surfaces these via
  *Feature Envy* and chained-call smells.
- **Why it matters:** Each extra dot couples the caller to the internal shape of every
  intermediate object. A change to any link in the chain breaks distant code, and a `nil`
  anywhere mid-chain throws far from its cause. It also leaks knowledge the caller
  shouldn't have ("talk only to your immediate friends").
- **Confirm (not just count):** Chains on a fluent/builder API (`scope.where().order()`),
  on Rails query interface, or on a value object you own are not Demeter violations — they
  operate on one returned object of the same kind, not on others' internals. Flag chains
  that *navigate associations/attributes* across object boundaries.
- **Fix direction:** Add a delegating method on the nearest object (`delegate :city,
  to: :address` / `to: :customer`), or expose a purpose-named method that hides the
  traversal (`order.shipping_city`). Push the knowledge to where the data lives.
- **Default severity:** P3 — usually a localised readability/coupling smell; escalate to
  P2 only when the same chain is duplicated widely (systemic coupling).

## Tool enrichment (optional)
These sharpen the heuristics; the lens must degrade gracefully when they are absent.
Detect presence before relying on output (e.g. `bundle show <gem>` / `which <bin>` /
grep the `Gemfile` / look for `.reek.yml`). Never install anything; never block on them.
- **reek** — Ruby code-smell detector. Maps onto these smells: *Large Class* (Too Many
  Methods / Too Many Instance Variables) -> God model/object; *Feature Envy* -> Law of
  Demeter + misplaced behaviour; *Long Parameter List*, *Data Clump* -> extract value/
  form object; *Control Couple* / *Boolean Parameter* -> hidden branching. Run `reek
  app/` and fold per-file findings into the responsibility judgment.
- **flog** — ABC-complexity score per method/class. Use to confirm "long/complex method"
  vs "God class": cross-reference with `rails.general.max_method_abc` (only meaningful if
  flog is available). High flog on one method = refactor that method; high flog spread
  across a class = decompose the class.
- **brakeman** — security scanner, **not** an architecture tool. It does not detect
  structural smells. Mention only to set expectations: if a project already runs
  brakeman, route its findings to the security lens, not here. Do not treat its silence
  as architectural health.

When a tool is present, treat its output as *corroborating evidence* that raises
confidence — not as the source of truth. When absent, fall back to Read/Grep/Glob/Bash
heuristics and say so in the finding (so reviewers know it wasn't machine-confirmed).

## Relationship
[[../principles/occams-razor]], [[../principles/convention-over-configuration]],
[[rails]] (conventions), patterns catalog (resources/patterns/rails.yaml).

## Sources
- Code Smells (reek detector list) — https://github.com/troessner/reek/blob/master/docs/Code-Smells.md
- "Fat model, skinny controller is a load of rubbish" (God object critique) — https://blog.joncairns.com/2013/04/fat-model-skinny-controller-is-a-load-of-rubbish/
- Service Objects: Beyond Fat Models and Skinny Controllers (FastRuby) — https://www.fastruby.io/blog/rails/service-objects.html
- Improve Code in Your Ruby Application with RubyCritic (reek/flog/flay) — https://blog.appsignal.com/2022/10/19/improve-code-in-your-ruby-application-with-rubycritic.html
- Is code like this a "train wreck"? (Law of Demeter) — https://softwareengineering.stackexchange.com/questions/109818/is-code-like-this-a-train-wreck-in-violation-of-law-of-demeter
- Brakeman (security scanner scope) — https://brakemanscanner.org/
