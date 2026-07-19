# Changelog

All notable changes to **intent-engineering**. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning is
[SemVer](https://semver.org/). For the current project state see **[STATUS.md](STATUS.md)**;
for the design see **PLAN.md**.

## [0.5.0] — 2026-06-19

Hardening release: all six architecture packs (Rails, Python, Laravel, Express, Phoenix,
React) **dogfooded read-only on real production apps** and tuned from the findings, plus a new
**external-tool-deferral config** so a team already running reek/eslint/phpstan/… isn't given
duplicate findings. No new stacks — this release makes the existing six trustworthy on real
codebases.

### Added
- **External-tool preference / anti-duplication config** (`tools.architecture` in
  `ways-of-working.yaml`): `enrich` (default — heuristics + tool as corroboration), `prefer`
  (run the tool, map its findings to the schema, suppress overlapping heuristics — no
  duplication), `report` (tool findings only), `off` (ignore tools). For a team that already
  runs reek/rubocop/ruff/phpstan/eslint/credo, the architecture lens defers to it instead of
  re-deriving the same smells. Honored by `ie-architecture-reviewer`; documented in
  `config-resolution.md`; wired through `ie-review`/`ie-audit`.
- **`/ie-init` opt-in for lenses + tool preference** — when scaffolding `ways-of-working.yaml`
  interactively, `ie-init` now asks which lenses run (turn any agent off) and how the
  architecture lens should treat an installed static-analysis tool, writing the answers into
  `.intense/`. (Lens on/off/auto toggles already existed in the config; this surfaces them at
  init and adds the tool preference.)

### Changed
- **Rails pack tuned from a real-world dogfood** (read-only run on a mature OSS Rails 8 app,
  ~1244 app files, concern-heavy, 99 service objects) — the original stack, validated on a
  real app for the first time. The prose judgment matched reality (fat-controller,
  misused-service multi-method, job, serializer, policy all reported **clean**) and found real
  fat-models + queries-in-views, but the *measurement instructions* were calibrated for small
  un-decomposed apps. Folded back:
  - **Concern-tree resolution for `fat-model`** (highest value) — follow `include Model::Topic`
    to `app/models/concerns/model/topic.rb` and sum LOC/associations/callbacks/methods across
    the tree; a grep of the model *file* returned `associations=0` on a 1685-LOC god model.
  - **`rails.service_object.max_loc` 120 → 250, LOC demoted to P3** — method count is the real
    axis; a long single-`call` service decomposed into inner strategy/builder classes is
    healthy, not a God service.
  - **Public-action vs raw-`def` counting** for `fat-controller` (count public actions above
    the first `private`/`protected`, minus callbacks — a raw `def` count flagged thin
    controllers), `app/models/form/**` added to the `form_object` pattern path, and a concrete
    heuristic god-object fan-out grep recipe for the reek-less default path.
- **Phoenix pack tuned from a real-world dogfood** (read-only run on a mature OSS Phoenix app,
  ~476 lib files). The prose discipline held — `business-logic-in-changeset`, `law-of-demeter`,
  and `process-misuse` all reported **clean with zero false positives**, and it found real
  `context-bypass` in controllers/LiveViews — but three signal-level detectors would have
  spammed false P2s on idiomatic Phoenix unattended. Folded back:
  - **Precise `context-bypass` matching** — grep the Ecto macro as `from(<binding> in <Schema>)`,
    NOT a bare `from(`, because a context query-builder is often a *function literally named
    `from`* (`Stats.Query.from(site, params)`); the bare grep produced ~37 false hits.
  - **Tiered `Repo.` bypass** — query-building/writes in the web layer = P2; a lone
    `Repo.preload`/`Repo.reload` on a context-provided struct = P3.
  - **`phoenix.controller.max_actions` 12 → 15** + an API/RPC-controller caveat (dashboard
    controllers have many thin RPC actions); **`phoenix.live_view.max_loc` 200 → 400** (colocated
    `~H`/`attr` function-component markup inflates LOC; judge handler/domain LOC, not markup).
  - Notes: Oban worker / mix-task data-access is a milder P3 placement nudge (not the web-layer
    P2 bypass); count `with` legs as flat, not nested.
- **Express pack tuned from a real-world dogfood** (read-only run on a mature OSS Express
  forum — CommonJS, ~611 src files, hand-rolled DB, `api/`-as-service layer). The smell
  *definitions* and severities held, but the **recognition mechanics were tuned for ESM + ORM
  + `services/` + named-lib conventions** and misfired on a real CommonJS app — producing both
  false negatives (god-modules invisible to the export counter) and false positives (every
  async handler + thin write controller flagged). Folded back:
  - **CommonJS-aware export counting** — the public surface is every `module.exports.x =` /
    `Obj.x =` assignment, including the mixin form `module.exports = function (Obj) { Obj.a = … }`;
    a naive `grep export` returns 0 for a 600-line/30-fn module.
  - **`api/`-named service recognition** — the service layer is often named for the transport it
    fronts (`api/`) with a `(caller, data)` signature, not `services/` + `*Service`; without
    this, thin REST controllers calling `api/` got false-flagged as layer-leaks.
  - **Project-local async-wrapper carve-out** — look for a repo's own handler-wrapping helper
    (try/catch→`next(err)`) before declaring an `async-error-gap`; many apps roll their own
    instead of `express-async-errors`.
  - **Tightened `layer-leak` grep** — key on `res.json`/`res.status`/`require('express')`, not a
    bare `req`/`res`; a passed-in `data.req`/`caller` for `.uid`/`.ip` is data, not coupling.
  - **`express.middleware.max_loc` 40 → 100** (real cross-cutting auth/render middleware runs
    long; lean on the behavioral signal) + a render-controller vs REST-controller severity note
    + hook-bus (`hooks.fire`) recognition in `event_subscriber`.
- **Laravel pack tuned from a real-world dogfood** (read-only run on a mature open-source
  Laravel 12 app with a non-default *domain-organized* layout). The pack's prose held
  (confirm-don't-count prevented every false positive; the app came back structurally clean),
  but the structured signals were calibrated for vanilla Laravel. Folded back:
  - **Layout-agnostic recognition** — added `app/**/{Controllers,Services,Requests,Resources,Jobs,Events,Listeners,Policies,Middleware,Repositories,Repos}/**`
    fallback path globs to every pattern (only `eloquent_model` had one), so domain-organized
    apps classify on path as well as base-class/suffix.
  - **Two new catalog patterns** (`query_object`, `notification`) and a broadened `action`
    pattern that also recognises hand-rolled domain-operation objects (`Tools/`/`Operations/`,
    `run()`/`handle()`) — these were `(unmatched)` on the dogfood. `laravel.yaml` 13 → 15.
  - **Threshold + caveats** — `laravel.controller.max_actions` 10 → 15 (GET form-render twins
    legitimately double the count); doc caveats that a bare `::all()`/`::where(` Blade grep
    over-triggers on enums/static helpers, and that the Law-of-Demeter grep is low-signal
    (manual spot-check, not a count).
- **React pack tuned from a real-world dogfood** (read-only run on a large production React 18
  + Next + MobX app, ~429 components). The React-core heuristics held (real god-components and
  a derived-state-in-effect found); two gaps were folded back:
  - **MobX awareness** — `state_store` and `higher_order_component` now recognise MobX
    (`makeAutoObservable`/`@observable`/`@action`/`mobx-react`, `observer()`); a `react.store.*`
    threshold block (`max_loc` 800, `max_observables` 15, `max_actions` 25) gives stores a
    looser, responsibility-based budget, and `god-module` now names the **god store**. The
    dogfood's worst finding — a 4117-LOC MobX god-store — previously only matched a weak path
    signal.
  - **Framework-idiom carve-outs** — `observer()`/`connect()` wrapping is flagged as idiomatic
    (not "wrapper hell"); Next.js `page`/`layout`/`getServerSideProps` and route-manifest tables
    are named as expected-long, not god components/modules.

## [0.4.0] — 2026-06-15

Third feature release: four new architecture stacks — **Laravel, Express/Node, Phoenix/Elixir,
and React** — each authored research-first and added purely through the v0.3.0 stack registry
(data + a catalog row, no lens/skill code changes). The architecture lens now covers **six
stacks**. (Python is FastAPI-first.)

### Added
- **React architecture stack** — fourth registry-only stack addition:
  - `resources/frameworks/react-architecture.md` — 8 structural smells (`god-component`,
    `logic-in-component`, `fat-hook`, `prop-drilling`, `effect-overuse`, `god-context`,
    `god-module`, `law-of-demeter`) + general metrics; optional eslint/madge enrichment.
  - `resources/patterns/react.yaml` — 11-pattern catalog (function_component, custom_hook,
    context_provider, reducer, data_fetching_hook, state_store, higher_order_component,
    render_prop, error_boundary, memoized_component, compound_component).
  - `config/defaults/thresholds.yaml` — a `react.*` threshold namespace; registered in
    `stack-catalog.md` (Arch pack ✅, flipped from convention-only) + `principle-index.md`.
    Detected from `package.json` (`react`) + `.jsx`/`.tsx`. Research-backed (React docs "You
    Might Not Need an Effect" / custom hooks / context, patterns.dev, Martin Fowler). The arch
    pack complements the existing react convention doc + the experience lens. Dogfood pending.
- **Phoenix / Elixir architecture stack** — third registry-only stack addition:
  - `resources/frameworks/phoenix-architecture.md` — 8 structural smells (`fat-controller`,
    `context-bypass`, `god-context`, `fat-liveview`, `business-logic-in-changeset`,
    `god-module`, `process-misuse`, `law-of-demeter`) + general metrics; optional credo/boundary
    enrichment.
  - `resources/patterns/phoenix.yaml` — 11-pattern catalog (context, phoenix_controller,
    ecto_schema, ecto_changeset, live_view, function_component, genserver, supervisor, plug,
    router, oban_worker).
  - `resources/frameworks/phoenix.md` — Elixir/Phoenix convention doc (contexts as the seam,
    Ecto cast/validate scope, OTP-models-runtime-not-code-organization, `{:ok,_}|{:error,_}`,
    least-astonishment traps).
  - `config/defaults/thresholds.yaml` — a `phoenix.*` threshold namespace; registered in
    `stack-catalog.md` (Arch pack ✅) + `principle-index.md`. Detected from `mix.exs`
    (`:phoenix`) + `lib/<app>_web/`. Research-backed (Phoenix Contexts guide, Elixir
    process/design anti-patterns, Ecto docs). Covers structural/layering + OTP *placement*;
    deep supervision-tree correctness is out of scope by design. Dogfood on a real repo pending.
- **Express / Node architecture stack** — second registry-only stack addition:
  - `resources/frameworks/express-architecture.md` — 8 structural smells (`fat-route-handler`,
    `god-module`, `god-object`, `misused-service`, `layer-leak`, `fat-middleware`,
    `async-error-gap`, `law-of-demeter`) + general metrics; optional eslint/madge enrichment.
  - `resources/patterns/express.yaml` — 12-pattern catalog (router, controller, middleware,
    service, repository, model, error_handler, validator, config, app_factory,
    background_worker, event_subscriber).
  - `resources/frameworks/express.md` — Node/Express convention doc (3-layer architecture,
    async error handling, config-from-env, app/server separation, least-astonishment traps).
  - `config/defaults/thresholds.yaml` — an `express.*` threshold namespace; registered in
    `stack-catalog.md` (Arch pack ✅) + `principle-index.md`. Detected from `package.json`
    (`express`) + `app.js`/`routes/`. Research-backed (bulletproof-nodejs 3-layer,
    goldbergyoni nodebestpractices, Express docs, 12-factor). Dogfood on a real repo pending.
- **Laravel (PHP) architecture stack** — the first stack added *through the registry* (data
  only, no skill edits), proving the extension point:
  - `resources/frameworks/laravel-architecture.md` — 8 structural smells (`fat-controller`,
    `fat-model`, `god-class`, `misused-service`, `query-in-view` (N+1), `logic-in-routes`,
    `fat-job`, `law-of-demeter`) + general metrics; optional phpstan/larastan/phpmd/phpinsights
    enrichment.
  - `resources/patterns/laravel.yaml` — 14-pattern catalog (eloquent_model, controller,
    form_request, action, service, api_resource, job, event_listener, policy, middleware,
    repository, service_provider, data_object).
  - `resources/frameworks/laravel.md` — Laravel/PHP convention doc (naming table, Eloquent/
    FormRequest/eager-loading idioms, `env()`-vs-`config()` and model-event traps).
  - `config/defaults/thresholds.yaml` — a `laravel.*` threshold namespace.
  - Registered in `stack-catalog.md` (Arch pack ✅) + `principle-index.md`; detected from
    `composer.json`/`artisan`/`app/`+`routes/`. Research-backed (alexeymezenin best-practices,
    Laravel docs, lorisleiva/laravel-actions, PSR-12). 75 → 83 contract checks, green.
  - **Dogfood pending** — no Laravel repo available locally; to be run on a real app.

## [0.3.0] — 2026-06-15

Second feature release: the architecture lens gains a **Python (FastAPI-first)** stack and
a **stack registry** that makes every future language/framework a data-only addition.

### Added
- **Python architecture stack** for the 5th (architecture) lens — it now supports Rails
  **and** Python (FastAPI-first, but the smells apply to any layered Python service):
  - `resources/frameworks/python-architecture.md` — 8 structural smells (`fat-router`,
    `god-module`, `god-object`, `misused-service`, `business-logic-in-schema`,
    `fat-dependency`, `layer-leak`, `law-of-demeter`) + general metrics, with optional
    `ruff`/`radon`/`vulture`/`import-linter` enrichment.
  - `resources/patterns/python.yaml` — 13-pattern catalog (router, dependency,
    pydantic_schema, settings, service, repository, background_task, app_factory,
    exception_handler, middleware, adapter_client, document_renderer, dataclass_value).
  - `config/defaults/thresholds.yaml` — a `python.*` threshold namespace.
- Stack detection for Python (`pyproject.toml`/`setup.py`/`setup.cfg` + `.py` sources)
  wired into `/ie-review`, `/ie-audit`, `/ie-init`, the architecture agent, and the lens
  catalog.
- **Stack registry** (`references/stack-catalog.md`) — one source of truth for every known
  stack: detection signals, the packs it loads (convention doc, architecture doc, pattern
  catalog, threshold namespace), and whether the architecture lens supports it. The lens,
  the skills, and `ie-init` read the registry instead of hardcoding detection, so adding a
  stack is data + one catalog row rather than edits across five files. This is the
  extension point for the queued stacks (PHP/Laravel, Elixir/Phoenix, Express/Node, React).
- **Stack-aware `/ie-init`** — scaffolds only the *detected* stack's `thresholds.yaml`
  namespace (not the whole multi-stack file) and seeds `patterns.yaml` policy from that
  stack's catalog, driven by the registry. Convention-only / unknown stacks get the
  stack-agnostic `ways-of-working.yaml` with a note.

### Changed
- `ie-architecture-reviewer` frontmatter description + intro made **stack-neutral** (point at
  the registry instead of enumerating stacks), so the agent prompt no longer needs a per-stack
  edit and can't drift stale as stacks are added.
- `scripts/check-contracts.rb` section 8 (cross-references) generalized from Rails-only to
  **every stack** with a `<stack>.*` threshold namespace: each must have a
  `<stack>-architecture.md`, all metrics it cites must be defined, and pattern-policy ids
  resolve against the union of all catalogs. New section 10 enforces stack-registry
  consistency (✅ rows ↔ files ↔ threshold namespaces). 67 → 75 checks, green.

### Notes
- Dogfooded the Python pack read-only against a real-world FastAPI service. Verdict
  healthy with near-zero false positives; the run caught two pack bugs (a bare-`Request`/
  `Response` grep that collided with Pydantic model names; a missing renderer pattern for
  openpyxl/pandas-heavy modules) and a placement smell — all fixed in the docs/catalog
  before release.

## [0.2.0] — 2026-06-14

First public release. The feature-complete build landed 2026-06-03; it was published on
2026-06-14 with the hardening, documentation, and CI below. (Git history was reset to a
single commit at publish time.)

### Added
- **Five review lenses** — predictability, convention, simplicity, experience (the four
  universal lenses) and architecture (5th, framework-specific, Rails-only, code/audit).
- **Five skills** — `/ie-init`, `/ie-plan-assist`, `/ie-validate-plan`, `/ie-review`,
  `/ie-audit`.
- **Shared contract layer** (`references/`) — findings schema, subagent template, lens
  catalog, scoring rubric, report template, principle index, config resolution.
- **Researched knowledge base** (`resources/`) — 9 principle docs, 7 framework docs
  (incl. `rails-architecture`), 6 agnostic docs, each with violation-smell checklists and
  cited sources.
- **`.intense` project config** — lens toggles, pattern policy, architecture thresholds;
  project overrides plugin defaults.
- **Rails architecture audit** + a **14-pattern catalog** (heuristic-first; optional
  reek/flog/brakeman enrichment); the `/ie-init` scaffolder.
- **Packaging** — `plugin.json`, `marketplace.json`; `resources/` bundled inside the plugin
  for install self-containment.
- **Docs** — `AGENTS.md` (contributor guide), `CLAUDE.md`, expanded `README.md`
  (source-principles table + full overview), `STATUS.md` (current state), this
  `CHANGELOG.md`, and `LICENSE` (MIT).
- **`scripts/check-contracts.rb`** — automated contract-integrity check (67 checks across 9
  sections: JSON/YAML parse, lens-identity 4-way agreement, agent frontmatter,
  `${CLAUDE_PLUGIN_ROOT}` path resolution, pattern-catalog schema, emitted `principle:` ids,
  git-tracked agents, threshold ↔ doc and policy ↔ catalog cross-references, and resource-doc
  structure & citations).
- **CI** — `.github/workflows/contracts.yml` runs the check on every PR and on pushes to `main`.

### Changed (hardening, after the feature-complete build)
- **Per-lens model directive** in `subagent-template.md` + `ie-audit` + `ie-validate-plan`:
  predictability/simplicity inherit the session model; convention/experience/architecture
  use `sonnet` (fixes a default that silently downgraded the always-on lenses).
- `report-template.md` specifies an **all-clear empty state**; `report.json` named
  consistently for `mode:agent` across the template and all three orchestrators.
- Plugin README **"five contexts" → four**; `plan:` token added to the `ie-review`
  argument-hint; `ie-review`/`ie-audit` frontmatter reworded to the five-lens framing.
- `patterns.*` lists documented as replace-only; `scores` key authority noted in the schema;
  `rails.general.max_method_loc` wired into `rails-architecture.md`.
- `.idea/` added to the repo `.gitignore`; the repo `agents/` negation reframed as defensive
  portability after the global `agents/` ignore was removed; legacy `.wip/`, empty `docs/`,
  and `.DS_Store` cruft removed.

### Fixed
- **The `agents/` gitignore trap.** A global gitignore ignored `agents/`, so all five lens
  agents were never committed — an installed plugin would have had **zero agents**. The repo
  `.gitignore` re-includes `plugins/intent-engineering/agents/`. **Keep that negation on any
  clone/fork.** Found by the dogfood loop, not by luck.
- Self-audit findings: lens-count drift in `ie-review`/`ie-audit` frontmatter (said "four",
  run up to five); a bare `subagent-template.md` citation in the predictability lens; unbound
  `OUT_ARG`/`REPORT_DIR` in the orchestrators' dispatch bash; a stale "TBD — default
  report-only" fix-policy note in `PLAN.md`.

### Decisions
- **Four consolidated universal lenses** (predictability / convention / simplicity /
  experience); principle docs stay 1:1. Architecture is a distinct **5th lens**,
  framework-specific and code/audit-only.
- Framework seeds: Rails/Ruby, React/TypeScript, Python, Swift/iOS.
- `ie-review` applies safe verified fixes (mirrors `ce-code-review`; never pushes).
- Research via parallel sub-agents, one per doc, write-as-you-go.
- Renamed **intuitive-engineering → intent-engineering**; `ie-` prefix kept; project config
  dir `.intense/`.
- Architecture metrics heuristic-first (optionally enriched by reek/flog/brakeman); pattern
  recognition by naming/dir/base-class/gem heuristics (AST later); config merge =
  project-over-global, lists replace unless `extends: true`.

[0.2.0]: https://github.com/davidteren/intent-engineering/releases/tag/v0.2.0
