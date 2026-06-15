# AGENTS.md — working in the intent-engineering repo

Guidance for any AI agent (or human) contributing to this repository. Read this
before editing. `CLAUDE.md` points here; this is the single source of truth for how
the repo is laid out and the rules that keep the plugin installable and internally
consistent.

> This repo *develops* the **intent-engineering** Claude Code plugin. The plugin's
> own end-user docs live in [`plugins/intent-engineering/README.md`](plugins/intent-engineering/README.md);
> the design lives in `PLAN.md`, current state in `STATUS.md`, and change history in `CHANGELOG.md`.

---

## What this repo is

A Claude Code **plugin** that enforces *intent engineering*: software that behaves the
way a reasonable developer or user already expects. It applies established design
principles as review **lenses** (parallel sub-agents) across four contexts — planning,
plan validation, code review, codebase audit — producing scored, deduplicated,
confidence-gated findings with concrete fixes.

The plugin is **data + prompts, not executable code.** Skills and agents are markdown
that the model follows; the knowledge base and contract files are markdown/JSON/YAML.
There is no build step and no runtime. "Correctness" here means the prose contracts,
schemas, and cross-references stay mutually consistent.

---

## Load-bearing rules (break these and the plugin breaks)

1. **`agents/` gitignore trap.** Some environments globally ignore `agents/` *everywhere*
   (several AI coding tools add it to a global gitignore). The repo `.gitignore` MUST
   keep the `!plugins/intent-engineering/agents/` + `!plugins/intent-engineering/agents/**`
   negation, or on such a machine all five lens agents silently leave git and a cloned
   plugin has **zero agents**. It's defensive — keep it so the plugin is portable
   regardless of a contributor's global config. After touching anything under `agents/`,
   verify with `git ls-files plugins/intent-engineering/agents/` (expect 5 files). The
   same lesson is why `.idea/` is listed in the repo `.gitignore` too.
2. **Self-contained plugin.** Everything the installed plugin needs lives **under**
   `plugins/intent-engineering/` — `agents/`, `skills/`, `references/`, `config/`,
   `resources/`. A Claude Code plugin only ships what's inside its plugin dir. Never
   move `resources/` or `references/` to the repo root. Edit them in place; they are the
   single source of truth.
3. **Runtime paths use `${CLAUDE_PLUGIN_ROOT}`.** Every cross-file reference inside a
   skill or agent must address shipped files as `${CLAUDE_PLUGIN_ROOT}/<dir>/<file>` —
   never a bare filename or repo-relative path. A lens runs in isolation and can only
   resolve `${CLAUDE_PLUGIN_ROOT}` paths.
4. **Read-only by default; never push.** Lenses are read-only except for the one
   artifact-JSON write. Only `/ie-review` (interactive) mutates project files — applies
   safe fixes, commits on a clean tree — and `/ie-init` writes under `.intense/`. Nothing
   ever pushes, opens PRs, or files tickets.
5. **`wip/` (not `.wip/`).** Reports and scratch go to `wip/intent-engineering/<run-id>/`.
   `wip/` is gitignored. (`.wip/` was a legacy report dir — removed; don't reintroduce it.)
6. **`ie-` prefix** for every skill and agent. Project config dir is **`.intense/`**.

---

## Repo map

```
intent-engineering/                       dev repo + marketplace
  AGENTS.md  CLAUDE.md  README.md  LICENSE
  PLAN.md                                 design + phase detail
  STATUS.md                               current-state snapshot
  CHANGELOG.md                            dated change history + decisions
  .claude-plugin/marketplace.json         marketplace entry (install from repo root)
  scripts/check-contracts.rb              contract-integrity check (the one automated check)
  wip/                                    gitignored scratch: task brief, future-ideas,
                                          fixtures/, and run reports
  plugins/intent-engineering/             THE INSTALLABLE PLUGIN (self-contained)
    .claude-plugin/plugin.json            name, version, keywords, license
    README.md                             end-user usage + lens details
    agents/      ie-{predictability,convention,simplicity,experience,architecture}-reviewer.md
    skills/      ie-{init,plan-assist,validate-plan,review,audit}/SKILL.md
    references/  findings-schema.json, subagent-template.md, lens-catalog.md,
                 stack-catalog.md, report-template.md, scoring-rubric.md,
                 principle-index.md, config-resolution.md   (the shared contract layer)
    config/defaults/  ways-of-working.yaml, patterns.yaml, thresholds.yaml
    resources/   principles/  frameworks/  agnostic/  patterns/   (knowledge base)
```

---

## How a run works (skills → lenses → report)

`ie-validate-plan`, `ie-review`, and `ie-audit` are orchestrators with the same shape:

1. **Load resolved config** (`references/config-resolution.md`): deep-merge project
   `.intense/*.yaml` over `${CLAUDE_PLUGIN_ROOT}/config/defaults/`. Always before lens
   selection.
2. **Select lenses** (`references/lens-catalog.md`): predictability + simplicity are
   always-on; convention is on for essentially all code; experience only on user-facing
   surfaces; architecture only on a supported framework (Rails + Python today), code/audit only.
   Resolved `lenses:` toggles (`on`/`off`/`auto`) override the defaults.
3. **Dispatch** each lens in parallel using `references/subagent-template.md`, binding
   `run_artifact_dir = $OUT`. Each lens reads its `resources/` heuristic docs, returns
   compact JSON per the schema, and writes full detail to `$OUT/{lens}.json`.
4. **Merge / dedup / gate** (`references/report-template.md`): dedup by file+line+title,
   promote findings agreed by 2+ lenses, suppress below the confidence gate (default
   anchor 75; P0 survives 50+), apply config severity overrides and pattern policy.
5. **Report** to `$OUT/report.md` (or a single JSON object in `mode:agent`) plus
   `$OUT/metadata.json`.

`ie-plan-assist` is the lightweight exception: inline advisory checklist, no sub-agents,
no artifacts, prose (not findings JSON). `ie-init` scaffolds `.intense/` and writes
nothing else.

**Shared tokens** (review/audit/validate-plan): `mode:agent` (JSON, and for review skips
the apply stage), `out:<path>` (override report dir). `OUT` precedence:
`out:` arg > resolved `ways-of-working.report_dir` > built-in `wip/intent-engineering`.
Run-id format is identical across the three: `$(date +%Y%m%d-%H%M%S)-<4-byte hex>` — keep
them in sync if you change one.

---

## The five lenses (`agents/`)

| Agent | Principles | Model | When it runs |
|-------|-----------|-------|--------------|
| `ie-predictability-reviewer` | least-astonishment, DWIM, WYSIWYG | inherit | always-on |
| `ie-simplicity-reviewer` | Occam, KISS, YAGNI | inherit | always-on |
| `ie-convention-reviewer` | convention-over-config, framework idiom | sonnet | code (almost always) |
| `ie-experience-reviewer` | HIG, look-and-feel, UX | sonnet | user-facing surfaces |
| `ie-architecture-reviewer` | structural quality, design patterns | sonnet | supported framework, code/audit only |

**Agent contract (every lens):**
- Frontmatter: `name` (= filename stem **and** the `lens` enum in `findings-schema.json`
  **and** the `lens-catalog.md` row), `description`, `model`, `tools`, `color`.
- `tools` is uniformly `Read, Grep, Glob, Bash, Write`. `Write` exists **only** to emit
  `{run_artifact_dir}/{lens}.json`. `Bash` is for measurement (architecture metrics;
  optional read-only `reek`/`flog`/`brakeman` probes). Adding `Edit`/`MultiEdit` breaks
  the read-only contract.
- `model: inherit` for the two always-on lenses (session model for high-stakes
  reasoning); `model: sonnet` for the three conditional lenses. Don't "standardize" all
  five to one model without updating `subagent-template.md` — it changes cost/quality for
  the always-on lenses.
- Findings conform to `references/findings-schema.json`. `principle` is one of the schema
  enum (17 values incl. `architecture`); `severity` ∈ P0–P3; `confidence` ∈ {0,25,50,75,100}.
- **Confidence anchors are fixed and shared**: 100 = provable from code/doc alone;
  75 = traceable end-to-end and a normal user/dev hits it; 50 = depends on unseen context
  (advisory); ≤25 = speculative, suppress. Reuse this exact language.
- Every finding names the **broken expectation** — a surprise you can't tie to a specific
  expectation is not a finding. When two principles conflict, set the `tension` field and
  present the trade-off; don't dogmatize.
- `smell` and `pattern` fields are **architecture-lens-only**. `scores` are returned only
  in audit/plan contexts, keyed by the canonical snake_case ids in `scoring-rubric.md`.
- Local conventions win: convention + architecture lenses read repo `CLAUDE.md`/`AGENTS.md`
  and `.intense/` first. Authority order is fixed in `config-resolution.md`:
  `.intense/*.yaml` > repo `CLAUDE.md`/`AGENTS.md` > sibling code > plugin defaults/framework docs.

---

## The contract layer (`references/`)

Single source of truth, read at runtime by skills and lenses. Do not duplicate these
rules into skills/agents — reference them.

- `findings-schema.json` — the machine-checkable finding contract. The `lens` enum must
  equal exactly the five `agents/ie-*-reviewer.md` basenames.
- `subagent-template.md` — the dispatch prompt skeleton + the shared confidence rubric.
- `lens-catalog.md` — the five lenses, their resource docs, and selection rules.
- `stack-catalog.md` — the **stack registry**: every known stack, its detection signals,
  the packs it loads (convention doc, architecture doc, pattern catalog, threshold
  namespace), and whether the architecture lens supports it. Skills + the architecture lens
  + `ie-init` read this instead of hardcoding detection, so adding a stack is data + a
  catalog row, not skill edits.
- `scoring-rubric.md` — audit/plan posture dimensions per lens (canonical snake_case keys).
- `report-template.md` — synthesized output shape (markdown tables + `mode:agent` JSON).
- `principle-index.md` — maps each principle/topic to its resource doc and owning lens.
- `config-resolution.md` — how `.intense/` config merges over defaults; authority order.

Note: findings cite **principles** (the schema enum) while posture rates **dimensions**
(the scoring-rubric keys). These are two intentionally distinct taxonomies — don't assume
one should mirror the other.

---

## Config system (`config/defaults/` + `.intense/`)

The plugin works out of the box with defaults; a repo tunes it via committable
`.intense/*.yaml` at its root.

- `ways-of-working.yaml` — lens toggles, severity overrides, local conventions, confidence
  gate, report dir.
- `patterns.yaml` — design-pattern policy: `allowed` / `blocked` (no new use) / `approved`
  (grandfathered paths). Keys reference **snake_case pattern ids** from
  `resources/patterns/<stack>.yaml`.
- `thresholds.yaml` — architecture metric limits, namespaced `rails.<unit>.<metric>`.

**Merge rule:** project overrides global. Scalars/maps replace key-by-key. **Lists
replace** the whole global list — *unless* the owning block sets `extends: true` (then
append). The `conventions` block carries an `extends` flag; the `patterns.*` lists are
**replace-only** (no `extends` knob today). A threshold is a *signal*, not a verdict — the
lens judges responsibilities, not just the number.

**Two id namespaces, deliberately distinct casing:** structural-smell ids are
**kebab-case** (`fat-model`, `god-object`, `callback-hell`, …); design-pattern ids are
**snake_case** (`interactor`, `service_object`, …). Pattern ids are an API — keep them
stable; anything in `.intense/patterns.yaml` must exist in the matching catalog.

---

## Knowledge base (`resources/`)

Researched, citation-backed docs the lenses read at runtime. Three families plus the
pattern catalog:

- `principles/` — one doc per design principle (definition, origin, core tenets,
  **violation smells**, good/bad examples, how-to-apply, **Sources**).
- `frameworks/` — per-stack convention docs (rails, ruby, react, typescript, python,
  laravel, swift-ios) plus `rails-architecture.md`, `python-architecture.md`, and
  `laravel-architecture.md` for the architecture lens. Variant headings: "Convention
  violation smells", "Least-astonishment traps".
- `agnostic/` — cross-cutting topics (naming, error-handling, api-design,
  defaults-and-configuration, accessibility, information-architecture). Heading:
  "Detectable smells".
- `patterns/` — YAML design-pattern catalogs (`rails.yaml` 14, `python.yaml` 13,
  `laravel.yaml` 14 patterns) + format README.

**The "Violation smells" / "Detectable smells" section is load-bearing** — it *is* the
lens's detection checklist. Every doc a lens reads must have one. Every doc ends with a
**Sources** section of real links — never ship a doc without citations.

---

## How to extend (wiring requirements)

Adding anything means updating its references in lockstep, or it's orphaned:

- **New lens** → `agents/ie-<x>-reviewer.md` (with the full agent contract above) **and**
  add it to the `findings-schema.json` `lens` enum, a `lens-catalog.md` row,
  `scoring-rubric.md` dimensions, and `README.md`. Wire its selection into the skills.
- **New framework doc** → `resources/frameworks/<stack>.md` (with a smells section +
  Sources) **and** wire it into `principle-index.md`, the `lens-catalog.md` resource
  column, and a `stack-catalog.md` row (Arch pack ⬜). Seed a stack only when there is a
  real consumer (dogfood targets first).
- **New architecture stack** → ships only when **all** of
  `resources/frameworks/<stack>-architecture.md`, `resources/patterns/<stack>.yaml`, and a
  `<stack>.*` namespace in `config/defaults/thresholds.yaml` exist; then flip the stack's
  `stack-catalog.md` row to **Arch pack ✅** and add a `principle-index.md` row. The
  architecture lens + `ie-init` read the registry, so **no skill edits are needed** — the
  registry is the only detection wiring. The contract check (section 10) enforces that a ✅
  row, its files, and its threshold namespace all agree.
- **New design pattern** → add to `resources/patterns/<stack>.yaml` with all required
  fields (`id`, `name`, `intent`, `recognition`, `good_use`, `misuse`). Ids are snake_case,
  stable, and may be referenced by `.intense/patterns.yaml`.
- **New principle doc** → write the doc (full structure + Sources) **and** wire it into
  `principle-index.md` and the owning lens's "Read first" list. Cross-link related
  principle docs with `[[wikilink]]` to the bare filename.

---

## Conventions & quality bar

- Plain-language **What / Why / How** opens every PR and the top of PLAN.md.
- **Least astonishment applies to this repo too** (it's the product). Names match
  behavior; one concept = one meaning; no surprising side effects. The plugin is
  dogfooded on itself — keep it self-consistent.
- **Validate before committing: `ruby scripts/check-contracts.rb`** — the contract-integrity
  check. It asserts JSON/YAML parse, lens-identity 4-way agreement (schema enum == agents ==
  lens-catalog == scoring-rubric), agent frontmatter (name == filename, in the enum, tools +
  model present), that every `${CLAUDE_PLUGIN_ROOT}/...` path resolves, the pattern-catalog
  schema, that emitted `principle:` ids are in the enum, cross-references (per stack with a
  `<stack>.*` threshold namespace, its `<stack>-architecture.md` exists and every metric it
  cites is defined in `thresholds.yaml`; every pattern id in policy/README exists in some
  catalog; unreferenced metrics warned), resource-doc
  structure (each principle/framework/agnostic doc has a detection "smells" section + a
  Sources section with ≥2 links; no orphan docs missing from `principle-index.md`/
  `lens-catalog.md`), that the five agents are git-tracked (the gitignore trap), and
  **stack-registry consistency** (every `stack-catalog.md` Arch-pack-✅ row has its
  architecture doc, pattern catalog, and threshold namespace; no threshold namespace or
  pattern catalog exists without a registered ✅ row). Exits non-zero on any breakage. Add new invariants there as the plugin grows — it is the
  plugin's one automated check. It also runs in **CI on every PR**
  (`.github/workflows/contracts.yml`), so a contract break fails before merge.
- **Dogfood as you go.** Run the lenses' logic against your change (or `/ie-audit` once
  installed), fix surfaced P1/P2, then commit. The audit→fix→re-audit loop is expected.
- Clean git history is preferred; the owner may ask to squash to a single commit.

## Install (local dogfooding)

```
/plugin marketplace add /Users/david.teren/Projects/Personal/intent-engineering
/plugin install intent-engineering
```

Then `/ie-init`, `/ie-review`, `/ie-audit`, `/ie-validate-plan`, `/ie-plan-assist`.
