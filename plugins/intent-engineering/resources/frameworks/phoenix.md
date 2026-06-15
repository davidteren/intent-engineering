# Phoenix / Elixir — Conventions
> Write code an Elixir developer would recognise: functional, context-driven, and surprising no one.

Elixir is a functional language and Phoenix is a thin web layer over a plain Elixir
application. The conventions below are what an experienced Phoenix developer assumes; fighting
them produces the "logic scattered across controllers and LiveViews" shape the framework's
own guides warn against. Code style follows the Elixir Style Guide and `mix format`. A repo's
`CLAUDE.md`/`AGENTS.md` wins over these community defaults.

## Structure & layering (the big one)

- **Phoenix is not your application.** The web layer (`lib/<app>_web/`) — router,
  controllers, LiveViews, components — is an *interface*. The application is the plain Elixir
  code in `lib/<app>/`.
- **Contexts are the seam.** Group related domain functionality and data access into
  **context** modules (`MyApp.Accounts`, `MyApp.Catalog`) that centralize Ecto/`Repo` access
  and validation. The web layer calls context functions; it does **not** call `Repo` or build
  Ecto queries directly.
- **Schemas model data; changesets cast + validate.** Business rules and I/O do **not** live
  in a changeset.
- **OTP models runtime, not code organization.** Reach for a `GenServer`/`Agent`/`Task` for
  concurrency, state, or resource isolation — not to organize otherwise-pure logic. Start
  every long-running process under a **supervision tree**.
- **`with` for happy-path pipelines** of `{:ok, _} | {:error, _}`; multi-clause functions and
  pattern matching over nested `case`/`if`.

## Naming & layout conventions

- **Modules:** `PascalCase`, nested under the app namespace — `MyApp.Accounts`,
  `MyAppWeb.UserController`. Web modules live under `MyAppWeb`.
- **Functions / variables / atoms:** `snake_case`. Predicates end in `?` (`active?`),
  dangerous/raising variants end in `!` (`create_user!`).
- **Context API verbs:** `list_*`, `get_*`/`get_*!`, `create_*`, `update_*`, `delete_*`,
  `change_*` (returns a changeset) — the shape `mix phx.gen` produces.
- **Files:** `snake_case.ex`; a module's file path mirrors its name
  (`MyApp.Accounts.User` -> `lib/my_app/accounts/user.ex`).
- **Tests:** `_test.exs`, mirroring `lib/` under `test/`.

## Idiomatic Elixir / Phoenix (what a practitioner expects)

- **Return `{:ok, value}` / `{:error, reason}` tuples** for operations that can fail; reserve
  raising (`!`) variants for "should never fail" call sites. Don't use exceptions for normal
  control flow.
- **Pattern-match in function heads** and use multi-clause functions instead of branching on
  arguments inside one body.
- **Pipe (`|>`) data through transformations**; the first argument is the data being
  transformed.
- **Immutability** — rebind, don't mutate; build new data structures rather than "changing"
  them.
- **Pattern-match the context result in the web layer** (`case Accounts.create_user(params)`)
  rather than letting a raw changeset bubble into the view.
- **Use `with`** to compose several `{:ok, _}` steps and handle the first `{:error, _}` once.
- **Run processes under supervision**; interact with a process through its own module's API,
  not by scattering `GenServer.call` across the codebase.

## Convention violation smells (detectable — feed the convention lens)

- `Repo.*`, `Ecto.Query`/`from(`, or a schema's `changeset/2` called **inside
  `lib/*_web/`** (controller, LiveView, component) — the web layer bypassing its context.
- Business logic or multi-step orchestration **in a controller action or LiveView
  `handle_event`** instead of a context.
- **I/O or business rules inside an Ecto changeset/schema** (`Repo` calls, HTTP, mail).
- **`spawn`/`Task.start`/`Agent.start_link`/`GenServer.start_link` outside a supervision
  tree** (not listed as a child in `application.ex`/a supervisor).
- A **`GenServer`/`Agent` wrapping pure logic** with no runtime concern (process used for
  code organization).
- **`GenServer.call`/`cast` for the same process scattered across multiple modules** instead
  of one wrapper.
- **Exceptions used for control flow** where `{:ok, _} | {:error, _}` tuples fit.
- Deeply nested `case`/`if`/`cond` where `with`, multi-clause functions, or pattern matching
  reads cleaner.
- `camelCase` names; module/file path that doesn't mirror the module name.
- A god `MyApp.Utils`/`MyApp.Helpers` grab-bag module.

## Least-astonishment traps specific to Elixir / Phoenix

- **Changesets run on every cast** — in forms, tests, and seeds. Side effects there fire at
  surprising times; keep changesets pure.
- **`Repo.get` vs `Repo.get!`** — the `!` variant raises on missing; the non-bang returns
  `nil`. Mixing them changes whether a missing record is a 404 or a crash.
- **Unsupervised processes vanish silently** — a `spawn`'d process that dies takes its work
  with it and won't restart; supervision is how Elixir gets reliability.
- **Message passing copies data** — sending a whole `conn`/struct to a `spawn`/`GenServer`
  copies all of it (Erlang "share nothing"); pass only the fields you need.
- **Atoms are not garbage-collected** — dynamically creating atoms from user input
  (`String.to_atom/1`) can exhaust the atom table; use `String.to_existing_atom/1`.
- **`with` else clauses** can swallow which step failed — keep the `else` specific so an
  error isn't silently remapped.

## Sources
- Phoenix Guides — Contexts ("Phoenix is not your application"; contexts centralize data access + validation) — https://hexdocs.pm/phoenix/contexts.html
- Elixir — Anti-patterns (code, design, and process anti-patterns) — https://hexdocs.pm/elixir/code-anti-patterns.html
- Elixir — Process-related anti-patterns (unsupervised processes, scattered interfaces) — https://hexdocs.pm/elixir/process-anti-patterns.html
- The Elixir Style Guide — https://github.com/christopheradams/elixir_style_guide
- Ecto.Changeset — cast/validate scope — https://hexdocs.pm/ecto/Ecto.Changeset.html
