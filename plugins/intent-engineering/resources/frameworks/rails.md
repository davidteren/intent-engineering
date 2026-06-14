# Ruby on Rails — Conventions
> Convention over configuration: Rails infers structure from names, so deviating from the expected name or location is itself the smell.

## Idiomatic structure
Rails apps follow a fixed `app/` layout. Code lives where the framework expects it, and the framework wires it together by name and location — no manual registration.

```
app/
  controllers/   # *_controller.rb, one per resource (plural), thin
  models/        # one ActiveRecord class per file (singular)
  views/         # views/<resource>/<action>.html.erb
  helpers/       # view-only helpers
  jobs/          # *_job.rb, ActiveJob background work
  mailers/       # *_mailer.rb
  channels/      # ActionCable
  components/    # ViewComponent (if used)
config/
  routes.rb      # resourceful routes
  initializers/  # boot-time config, one concern per file
db/
  migrate/       # timestamped migrations: YYYYMMDDHHMMSS_*.rb
  schema.rb      # generated — never hand-edit
lib/             # code not tied to a request/model; tasks in lib/tasks/
test/ or spec/   # mirrors app/ structure
```

Rules: one class/module per file; file path mirrors the constant path (`Admin::ReportsController` → `app/controllers/admin/reports_controller.rb`). Autoloading (Zeitwerk) **requires** this mapping — a mismatched filename breaks loading. Domain code that isn't a model/controller/job belongs in a PORO under `app/models/`, `app/services/`, or a namespaced concern — not stuffed into a controller.

## Core conventions (what a Rails dev expects)

### Naming (classes, tables, files, routes)
- **Models**: singular `CamelCase` class → plural `snake_case` table. `BigfootSighting` → table `bigfoot_sightings`. File `app/models/bigfoot_sighting.rb`.
- **Columns**: `snake_case`, singular. Primary key is `id`. Foreign key is `<singular_model>_id` (e.g. `profile_id`). STI uses a `type` column. Timestamps `created_at` / `updated_at`.
- **Join tables** (HABTM): both table names, pluralized, alphabetical: `categories_products`.
- **Controllers**: plural resource + `Controller`: `BigfootSightingsController` in `app/controllers/bigfoot_sightings_controller.rb`.
- **Routes**: plural `snake_case` via `resources :bigfoot_sightings`.
- **Methods/vars/symbols**: `snake_case`. **Constants**: `SCREAMING_SNAKE_CASE`. **Predicates** end in `?` (no `is_`/`has_` prefix). **Mutating/bang** methods end in `!` when a safe variant exists.

### REST & controllers (resourceful routes, thin controllers, fat models)
- Prefer `resources :things`, which generates exactly seven actions: `index`, `show`, `new`, `create`, `edit`, `update`, `destroy`. Treat these seven as the vocabulary.
- When you reach for a custom action (e.g. `POST /orders/:id/approve`), first ask whether it's actually a **new resource**: `resources :orders do resources :approvals, only: :create end`. Nested/sub-resources beat custom verbs.
- Controllers stay **thin**: parse params, invoke a model/object, set instance vars for the view, redirect/render. Business logic, queries, and orchestration belong in models or POROs — not the controller.
- Use strong parameters (`params.require(:x).permit(...)`). Use `before_action` for shared setup (auth, record lookup), not for hiding business rules.

### ActiveRecord (associations, callbacks, scopes, migrations)
- Declare associations with the conventional names so Rails infers keys: `belongs_to :profile` (uses `profile_id`), `has_many :bigfoot_sightings`. Override with `class_name:`/`foreign_key:` only when names genuinely differ.
- Scopes for reusable, chainable query fragments: `scope :active, -> { where(active: true) }`. Keep them side-effect-free.
- Migrations are **append-only** and timestamped; let `db/schema.rb` be generated. Use `change` with reversible methods; reach for `up`/`down` only when a migration isn't auto-reversible.
- Validations live on the model. Callbacks are for persistence-adjacent concerns (normalizing a column), **not** for cross-object side effects like sending email or calling an API.

### Convention-over-configuration wins to preserve
- Don't configure what Rails can infer (table names, FK names, view paths, route helpers). Manual config that restates a default is noise and drifts.
- Use generators (`rails g model/controller/migration`) to land files in the right place with the right names.
- Lean on the integrated stack ("omakase"): ActiveJob, ActionMailer, ActiveStorage, etc., before bolting on a parallel mechanism.

## Convention violation smells (detectable — feed the convention lens)
- **Custom controller action where a sub-resource fits**: `def approve` / `def publish` on a resource controller, plus a `member`/`collection` route, instead of a nested resource.
- **Fat controller**: query building (`where`/`joins`), multi-step orchestration, or business rules inside a controller action; controller longer than ~the seven actions.
- **Bypassing AR conventions without cause**: explicit `self.table_name =`, `foreign_key:`, or `primary_key:` that merely restates the default; raw SQL where a scope/association would do.
- **Non-conventional file location / name**: class name not matching file path (Zeitwerk mismatch); a model file named plural; a controller named singular; logic dumped in `lib/` that depends on Rails request context.
- **Manual config where a convention exists**: per-model route blocks instead of `resources`; hand-built URL strings instead of route helpers (`bigfoot_sighting_path`).
- **Non-RESTful routing**: `match`/`get 'things/do_x'` ad-hoc routes proliferating instead of resourceful routes.
- **Mutation in a query-named method**: a `get_*`/`find_*`/`fetch_*` method that also writes or enqueues.
- **`save` return value ignored**: calling `save` (returns boolean) where `save!` (raises) is expected, or vice versa, silently swallowing failures.

## Least-astonishment traps specific to Rails
- **Callbacks with side effects**: `after_save :send_email` / `after_create :call_api` make every `save` fire hidden external effects — surprising in tests, bulk imports, and consoles. Prefer explicit calls or background jobs invoked from the action.
- **`default_scope`**: silently filters *every* query for that model (including associations and `count`), surprising anyone who writes `Model.all`. Avoid; use named scopes the caller opts into.
- **`save` vs `save!` / `update` vs `update!`**: the non-bang form returns `false` on failure and keeps going; the bang form raises. Mixing them produces silent data loss or unexpected exceptions.
- **Methods that hide queries (N+1)**: a method like `order.total` that lazily loads associations per-record inside a loop; an attribute-looking method that fires a DB hit. Name and load explicitly (`includes(:line_items)`).
- **`delete` vs `destroy`**: `delete`/`delete_all` skip callbacks and validations; `destroy` runs them. Choosing the wrong one silently skips or unexpectedly triggers side effects.
- **Implicit `to_s` / route-helper magic** changing URLs when a model's `to_param` is overridden.

## Idiomatic vs non-idiomatic examples

**1 — Custom action vs sub-resource**
```ruby
# non-idiomatic: custom verb on the resource
# routes: post 'orders/:id/approve' => 'orders#approve'
class OrdersController; def approve; ...; end; end

# idiomatic: approval is its own resource
# routes: resources :orders do; resource :approval, only: :create; end
class Orders::ApprovalsController; def create; ...; end; end
```

**2 — Fat controller vs fat model**
```ruby
# non-idiomatic: logic + query in the controller
def index
  @posts = Post.where(published: true).where('views > ?', 100).order(created_at: :desc)
end

# idiomatic: chainable scopes on the model, thin controller
# model: scope :published, -> { where(published: true) }
#        scope :popular,   -> { where('views > ?', 100) }
def index = @posts = Post.published.popular.recent
```

**3 — Hidden callback side effect vs explicit**
```ruby
# non-idiomatic: every save sends mail, surprising in tests/imports
class User < ApplicationRecord
  after_create { WelcomeMailer.welcome(self).deliver_later }
end

# idiomatic: the action that creates the user triggers the effect
def create
  @user = User.new(user_params)
  if @user.save
    WelcomeMailer.welcome(@user).deliver_later
    redirect_to @user
  else
    render :new, status: :unprocessable_entity
  end
end
```

## Note on local conventions
Repo-local `CLAUDE.md` / `AGENTS.md` conventions **override** these community/framework defaults. Many teams deliberately layer their own patterns — e.g. interactors or command objects instead of fat models/service objects, mandatory query objects, or a banned-callback policy. The convention lens should read the repo's own standards **first** and treat this document as the baseline only where the repo is silent. Do not flag a documented house style as a violation.

## Sources
- The Rails Doctrine (Nine Pillars) — https://rubyonrails.org/doctrine
- Rails Routing from the Outside In (resourceful routes, seven actions) — https://guides.rubyonrails.org/routing.html
- Active Record Basics (naming, schema conventions) — https://guides.rubyonrails.org/active_record_basics.html
- Rails naming conventions (model/table/FK/controller mapping) — https://gist.github.com/iangreenleaf/b206d09c587e8fc6399e
- Ruby Style Guide (snake_case, predicates `?`, bang `!`, constants) — https://rubystyle.guide
