# intent-engineering — Plan

A Claude Code plugin that enforces **intent engineering**: software that behaves
the way a reasonable developer or user already expects. It applies a set of
well-established design principles as review/audit/planning *lenses*, fanning out
parallel agents that produce structured findings and reports.

> **What / Why / How (plain language)**
>
> **What:** A toolkit you run against a plan, a pull request, your local changes, or
> a whole codebase. It checks whether the work follows time-tested principles of
> "least surprise" — does the code/UI behave the way people expect, follow
> conventions, stay simple, and feel coherent?
>
> **Why:** Surprising software is expensive. Hidden side effects, reinvented
> conventions, needless complexity, and inconsistent UX cost reviewers, users, and
> future maintainers time. Most of this is caught late (in review) or never. This
> plugin makes the principles checkable and repeatable.
>
> **How:** A small set of "lenses" (each grounded in a researched principle) run as
> parallel agents. They return scored, deduplicated findings with concrete fixes,
> written to a report under `docs/intent-engineering/`. The same lenses work in four contexts: planning,
> plan validation, code review, and codebase audit.

---

## Source principles (the knowledge base)

The plugin is grounded in researched docs under `resources/`. Each principle gets a
standalone markdown doc (definition, origin, core tenets, violation smells, good vs
bad examples, how-to-apply in code/UX/planning, references).

**Principles (`resources/principles/`):**

| Doc | Principle | Lens it feeds |
|-----|-----------|---------------|
| `least-astonishment.md` | Principle of Least Astonishment (POLA) | Predictability |
| `dwim.md` | Do What I Mean | Predictability |
| `wysiwyg.md` | WYSIWYG | Predictability |
| `convention-over-configuration.md` | Convention over Configuration | Convention |
| `occams-razor.md` | Occam's Razor (+ KISS, YAGNI) | Simplicity |
| `human-interface-guidelines.md` | Human Interface Guidelines | Experience |
| `look-and-feel.md` | Look and Feel | Experience |
| `ux-design.md` | User Experience Design | Experience |
| `software-philosophies.md` | Index of the broader philosophy list (DRY, SOLID, POLP, etc.) — cross-references | (all) |

**Framework/language conventions (`resources/frameworks/`):** per-stack docs of the
idioms a reasonable practitioner expects (so "convention" findings are concrete, not
vague). Seed set driven by the projects we dogfood in. Candidates: `rails.md`,
`ruby.md`, `react.md`, `typescript.md`, `python.md`, `swift-ios.md`, `rest-api.md`,
`cli.md`.

**Agnostic cross-cutting (`resources/agnostic/`):** topics that span stacks —
`naming.md`, `defaults-and-configuration.md`, `error-handling.md`, `api-design.md`,
`accessibility.md`, `information-architecture.md`, `tradeoffs-pros-cons.md`.

Research method: **document as you go.** Research one principle → write its doc →
next. Do not batch all research then dump docs. Use EXA / web tools beyond the
Wikipedia seeds; cite sources in each doc.

---

## Lenses (reviewer agents)

Four consolidated lenses, each grounded in the principle docs above. (Rationale:
8 one-principle agents overlap heavily on UI/UX; 4 lenses keep reports focused while
the principle docs stay 1:1 and granular.) Each lens adapts its behavior to the
**context** it runs in (plan vs code vs audit), mirroring how `ce-design-lens`
adapts to requirements-vs-plan.

| Agent | Principles | Hunts for |
|-------|-----------|-----------|
| `ie-predictability-reviewer` | POLA, DWIM, WYSIWYG | Name/behavior mismatch, hidden side effects, surprising return types/values, inconsistent branch returns, silent failures, controls that don't do what their label implies |
| `ie-convention-reviewer` | Convention over Configuration, framework idiom | Reinvented conventions, config where convention exists, one-off patterns that fight the repo/framework, non-idiomatic structure |
| `ie-simplicity-reviewer` | Occam, KISS, YAGNI | Needless abstraction, premature generality, speculative config, layers that don't earn their keep, simpler equivalent exists |
| `ie-experience-reviewer` | HIG, Look & Feel, UX | Missing interaction states, inconsistent look/feel, broken keyboard/focus/back-button, accessibility gaps, weak information architecture |

Shared agent contract: anchored confidence (0/25/50/75/100), severity P0–P3, a
`principle` field on every finding, concrete `suggested_fix`, structured JSON
matching the findings schema.

---

## Skills (the four contexts)

| Skill | Context | Mirrors | Behavior |
|-------|---------|---------|----------|
| `ie-review` | code review: PR / local / branch | `ce-code-review` | Scope detect → fan out lenses → merge/dedup/confidence-gate → report. `mode:agent` returns JSON. |
| `ie-audit` | whole codebase / feature / path | (new) | Sampling-aware broad sweep; per-principle posture scores + top findings. |
| `ie-validate-plan` | an existing plan / spec / requirements doc | `ce-doc-review` | Classify doc → lenses in plan mode + dimensional 0–10 rating → findings + gaps. |
| `ie-plan-assist` | during planning | (light) | Advisory: surface the principle considerations relevant to the work being planned; emit a checklist, no blocking. |

All skills:
- **Two-layer artifacts:** run scratch `.intense/runs/<run-id>/` (per-lens JSON;
  cleaned up after publish) and published report
  `docs/intent-engineering/<stamp>-<skill>[-scope].md`. Override publish path via
  `out:<path>`; permanent defaults via `artifacts.*` in ways-of-working. Outside-repo
  only when explicitly requested.
- Never push / open PRs / file tickets. Read-only lenses; `ie-review` (interactive only)
  applies safe verified fixes and commits on a clean tree — never pushes. `ie-audit` and
  `ie-validate-plan` are report-only.
- Bounded parallel dispatch; degrade to sequential where the harness can't fan out.

**Shared references** (per skill `references/`, sourced from `resources/`):
`findings-schema.json`, `subagent-template.md`, `lens-catalog.md`,
`report-template.md`, `scoring-rubric.md`, `principle-index.md`.

---

## Repo layout

```
intent-engineering/                      (repo / dev + marketplace)
  PLAN.md  STATUS.md  CHANGELOG.md  README.md
  .claude-plugin/marketplace.json
  plugins/intent-engineering/            (the installable plugin — self-contained)
    .claude-plugin/plugin.json
    agents/   ie-{predictability,convention,simplicity,experience,architecture}-reviewer.md
    skills/   ie-{init,plan-assist,validate-plan,review,audit}/SKILL.md
    references/  findings-schema.json, subagent-template, lens-catalog, report-template,
                 scoring-rubric, principle-index, config-resolution
    config/defaults/  ways-of-working.yaml, patterns.yaml, thresholds.yaml
    resources/   principles/  frameworks/  agnostic/  patterns/
  docs/intent-engineering/   published ie-* reports
  .intense/runs/             ephemeral lens scratch (gitignored; cleaned up after publish)
```

(Resources live inside the plugin for install self-containment — see the root README.)

---

## Phases

- **Phase 0 — Scaffold & plan** (this): dirs, move task doc, `PLAN.md`, `STATUS.md`.
- **Phase 1 — Principle research:** write `resources/principles/*.md` as-you-go.
- **Phase 2 — Conventions research:** seed `resources/frameworks/*.md` (dogfood
  stacks first) + `resources/agnostic/*.md`.
- **Phase 3 — Author plugin:** lens agents → shared references → skills.
- **Phase 4 — Package & install:** `plugin.json`, `marketplace.json`, `README.md`;
  install locally via the plugin marketplace.
- **Phase 5 — Dogfood:** run in this repo + real-world repos; iterate from real
  findings. Capture learnings back into the principle/convention docs.
- **Phase 6 — Architecture, patterns & config:** framework-aware architectural audit
  (Rails first), design-pattern catalog + recognition, `.intense/` ways-of-working
  config (project supersedes global), `/ie-init` scaffolder, new
  `ie-architecture-reviewer` lens. See the Phase 6 design below.

Each phase's task list and progress live in `STATUS.md`; the dated change log lives in `CHANGELOG.md`.

---

## Open decisions — RESOLVED (Phases 0–5)

1. **Lens grouping:** 4 consolidated lenses. ✅
2. **Framework seed set:** Rails/Ruby, React/TS, Python, Swift/iOS. ✅
3. **Fix application:** `ie-review` applies safe verified fixes (never pushes). ✅
4. **Research fan-out:** parallel research agents, one per doc. ✅

---

## Phase 6 — Architecture, patterns & config (design)

Adds a fifth lens and a project-level config system so teams can encode their own
"ways of working" and have the plugin enforce them.

### Decisions (resolved for this phase)

1. **New lens, not an extension.** `ie-architecture-reviewer` is a distinct 5th lens —
   architectural detection needs structural metrics + a pattern catalog, which is a
   different job from the prose-level convention lens.
2. **Heuristic-first, tool-enriched.** The lens computes its own heuristics (LOC,
   method/association/callback counts, fan-in/out, naming/dir signatures) with
   Read/Grep/Glob/Bash so it works on any machine. If `reek`/`flog`/`brakeman` are
   installed it *may* shell out to enrich findings — never required. Least-astonishing:
   works everywhere, better where tools exist.
3. **Pattern recognition = heuristics v1.** Identify patterns by naming suffix, directory,
   base class/module, and gem usage (e.g. the `interactor` gem). AST-based recognition
   is a future enhancement, noted not built.
4. **Config merge = project overrides global; lists replace.** Project `.intense/*.yaml`
   supersedes the plugin's `config/defaults/`. Scalar/map keys: project overrides global.
   Lists: project replaces global unless the file sets `extends: true` (then append).
5. **Config locations.** Global defaults ship in `${CLAUDE_PLUGIN_ROOT}/config/defaults/`.
   Project config lives in `.intense/` at the repo root (read from cwd at runtime).

### Components

- **`config/defaults/`** — shipped defaults: `ways-of-working.yaml` (lens toggles,
  severity overrides, local-convention notes), `patterns.yaml` (allow / block /
  approved), `thresholds.yaml` (architecture metric limits).
- **`references/config-resolution.md`** — how skills/lenses load and merge config.
- **`resources/patterns/rails.yaml`** + **`resources/patterns/README.md`** — the
  recognizable Rails patterns (intent, recognition signature, good-use rubric, common
  misuse) and the catalog format for extending to other stacks.
- **`resources/frameworks/rails-architecture.md`** — anti-pattern heuristics + default
  thresholds (fat model, God object, fat controller, misused service, callback hell,
  query-in-view, fat helper).
- **`resources/frameworks/python-architecture.md`** + **`resources/patterns/python.yaml`** —
  the second architecture stack (FastAPI-first, generalizes to any layered Python service):
  fat-router, god-module, god-object, misused-service, business-logic-in-schema,
  fat-dependency, layer-leak, law-of-demeter + a 13-pattern catalog. Proves the per-stack
  rule-pack design: a stack ships when both files + a `<stack>.*` threshold namespace exist.
- **`agents/ie-architecture-reviewer.md`** — the lens. Detects anti-patterns, classifies
  pattern instances, raises unknown patterns, honors allow/block/approved from config.
- **Schema/catalog updates** — `architecture` added to the principle enum + optional
  `pattern` field; lens-catalog gains the 5th lens + selection rule (on when a supported
  framework is detected); scoring-rubric gains architecture dimensions.
- **Skill wiring** — `ie-audit` runs an architecture pass on supported frameworks;
  `ie-review` selects it when the diff touches models/controllers/services.
- **`skills/ie-init/SKILL.md`** — scaffolds `.intense/` templates into a project
  (menu, stack-aware, idempotent).

### Dogfood

The plugin repo isn't Rails, so the architecture lens is dogfooded against a small
synthetic Rails fixture under optional personal `wip/fixtures/` (gitignored dev scratch —
not the plugin report home; reports use `docs/intent-engineering/`) with deliberate smells +
recognizable + unknown patterns. Real-repo runs are left for the user to trigger.
