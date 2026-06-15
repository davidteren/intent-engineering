# Laravel (PHP) — Conventions
> Write code a Laravel developer would recognise: idiomatic, convention-driven, and surprising no one.

Laravel is a **convention-over-configuration** framework: follow the naming and structure it
expects and most wiring disappears. The conventions below are what a Laravel practitioner
assumes by default — fight them and the next reader (and the framework's magic) is surprised.
PHP-level style follows **PSR-12**. When a repo's `CLAUDE.md`/`AGENTS.md` states a local
choice, that wins over these community defaults.

## Naming conventions (the big one)

Laravel infers tables, keys, and routes from names. Use the community-standard casing so the
framework's defaults Just Work:

| What | How | Good | Bad |
|------|-----|------|-----|
| Controller | singular + `Controller` | `ArticleController` | `ArticlesController` |
| Model | singular | `User` | `Users` |
| Table | plural snake_case | `article_comments` | `articleComments` |
| Pivot table | singular models, alphabetical | `article_user` | `user_article` |
| Foreign key | singular model + `_id` | `article_id` | `articleId`, `id_article` |
| Primary key | `id` | `id` | `custom_id` |
| Model property | snake_case | `$model->created_at` | `$model->createdAt` |
| `hasOne`/`belongsTo` relation | singular | `articleComment` | `articleComments` |
| Other relations | plural | `articleComments` | `articleComment` |
| Method | camelCase | `getAll` | `get_all` |
| Variable | camelCase | `$articlesWithAuthor` | `$articles_with_author` |
| FormRequest | singular + `Request` | `UpdateUserRequest` | `UserFormRequest`, `UserRequest` |
| Route (URL) | plural | `articles/1` | `article/1` |
| Route name | snake_case + dot | `users.show_active` | `show-active-users` |
| View | kebab-case | `show-filtered.blade.php` | `showFiltered.blade.php` |
| Config / lang key | snake_case | `articles_enabled` | `ArticlesEnabled` |
| Trait | adjective | `Notifiable` | `NotificationTrait` |
| Enum | singular | `UserType` | `UserTypes`, `UserTypeEnum` |

## Idiomatic Laravel (what a practitioner expects)

- **Validation lives in a FormRequest**, not inline in the controller — type-hint
  `StoreUserRequest $request` and let it run before the action body.
- **Business logic lives in a Service or Action**, not in the controller or (beyond cohesive
  entity behaviour) the model. Controllers stay thin: validate → call one Action/Service →
  respond.
- **Prefer Eloquent over the Query Builder and raw SQL**; prefer **Collections over arrays**.
  Eloquent brings scopes, casts, soft deletes, events.
- **Eager-load to avoid N+1** — `User::with('profile')`, never a relation access inside a
  loop over a non-eager-loaded collection. Do not run queries in Blade.
- **Mass assignment via `$fillable` + `create($request->validated())`**, not field-by-field
  hydration from raw request input.
- **Reusable query logic → query scopes** (`scopeActive`), not duplicated `where` chains.
- **Resolve dependencies via the container** (constructor injection / `app()`), not
  `new Class` — tight coupling complicates testing.
- **Read config via `config()`, never `env()` outside config files** — `env()` returns null
  once config is cached (`php artisan config:cache`).
- **No logic in route files** — point routes at controller actions, keep
  `routes/web.php`/`api.php` declarative (and route-cacheable).
- **Prefer descriptive names over comments / DocBlocks**; use return type hints and modern
  PHP syntax (`$object->relation?->id`, `now()`, `session('cart')`, `compact()`).
- **No HTML in PHP classes; minimal vanilla PHP in Blade.** Presentation stays in Blade /
  components; data prep stays in the controller/action.
- **Prefer standard Laravel tools** the community accepts (Policies for authz, Sanctum/
  Passport for API auth, Eloquent for DB, Blade for templates) over alien 3rd-party stacks.

## Convention violation smells (detectable — feed the convention lens)

- `$request->validate([...])` / `Validator::make(...)` **inside a controller action** instead
  of a FormRequest.
- Business logic, file handling, or external calls in a **controller action** (belongs in a
  Service/Action).
- **Raw SQL / `DB::select`** or heavy Query Builder where Eloquent would read clearly.
- **Relation access inside a Blade `@foreach`** without an upstream `with()` (N+1), or any
  `Model::...`/`->get()` query in a `.blade.php`.
- **`env('...')` called outside `config/`** files.
- **Closures with logic in `routes/web.php`/`api.php`** instead of `[Controller::class, 'method']`.
- **Field-by-field assignment** from `$request->x` instead of `create($request->validated())`.
- **Plural model / singular table / camelCase column / `ArticlesController`** — naming that
  fights Laravel's inference.
- **`new SomeService()`** in a controller/action instead of container injection.
- **DocBlocks restating a typed signature**; `get_all` (snake_case) methods; HTML built in PHP.
- Duplicate `where(...)` chains that should be a **query scope**.

## Least-astonishment traps specific to Laravel

- **`env()` after config caching returns `null`.** Once `config:cache` runs, `env()` outside
  config files no longer reads `.env`. Always go through `config()`.
- **Mass-assignment protection.** `$fillable`/`$guarded` exist to stop unexpected columns
  being set from request input; bypassing them with raw assignment reintroduces the risk.
- **Model events / observers fire implicitly** on every save — including seeders, factories,
  and bulk operations. Heavy side effects in `booted()`/observers surprise callers (route
  these to an explicit Action). `Model::withoutEvents()` and `saveQuietly()` exist because of
  this.
- **`$model->relation` lazy-loads a query** on access; in a loop that is N+1. `with()` /
  `load()` make the cost explicit.
- **Soft deletes** mean `delete()` doesn't really delete and default queries hide
  trashed rows — `withTrashed()`/`forceDelete()` change behaviour surprisingly if forgotten.
- **Route model binding** resolves `{user}` to a `User` by id automatically; a mismatched
  parameter name silently breaks it.

## Sources
- Laravel best practices (naming conventions, idioms, FormRequests, Eloquent, N+1) — https://github.com/alexeymezenin/laravel-best-practices
- PSR-12 — Extended Coding Style — https://www.php-fig.org/psr/psr-12/
- Laravel docs — Eloquent: Getting Started (conventions, mass assignment) — https://laravel.com/docs/eloquent
- Laravel docs — Configuration: environment & config caching (`env()` vs `config()`) — https://laravel.com/docs/configuration#accessing-configuration-values
- Laravel docs — Controllers (resource controllers, naming) — https://laravel.com/docs/controllers
