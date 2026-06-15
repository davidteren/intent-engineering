# Changelog

All notable changes to **intent-engineering**. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning is
[SemVer](https://semver.org/). For the current project state see **[STATUS.md](STATUS.md)**;
for the design see **PLAN.md**.

## [Unreleased]

### Added
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
