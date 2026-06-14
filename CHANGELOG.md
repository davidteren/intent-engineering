# Changelog

All notable changes to **intent-engineering**. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning is
[SemVer](https://semver.org/). For the current project state see **[STATUS.md](STATUS.md)**;
for the design see **PLAN.md**.

## [Unreleased]

Hardening and documentation since 0.2.0 (single-commit history was squashed into the
initial release commit; entries below are grouped, not per-commit).

### Added
- `AGENTS.md` — contributor/agent guide (load-bearing rules, run architecture, lens +
  contract details, how to extend) and `CLAUDE.md` pointer to it.
- `scripts/check-contracts.rb` — the plugin's first automated check. 67 checks across 9
  sections: JSON/YAML parse, lens-identity 4-way agreement (schema enum == agents ==
  lens-catalog == scoring-rubric), agent frontmatter, `${CLAUDE_PLUGIN_ROOT}` path
  resolution, pattern-catalog schema, emitted `principle:` ids, git-tracked agents,
  cross-references (thresholds ↔ docs, pattern policy ↔ catalog), and resource-doc structure
  & citations. Wired into AGENTS.md as the pre-commit step.
- `LICENSE` (MIT) and an expanded root `README.md` (source-principles table + full overview).
- `CHANGELOG.md` (this file); `STATUS.md` reframed as a current-state snapshot (was a log).

### Changed
- **Per-lens model directive** in `subagent-template.md` + `ie-audit` + `ie-validate-plan`:
  predictability/simplicity inherit the session model; convention/experience/architecture
  use `sonnet`. (Fixes a default that silently downgraded the always-on lenses.)
- `report-template.md` now specifies an **all-clear empty state**; `report.json` is named
  consistently for `mode:agent` across the template and all three orchestrators.
- Plugin README **"five contexts" → four**; `plan:` token added to the `ie-review`
  argument-hint; `ie-review`/`ie-audit` frontmatter reworded to the five-lens framing.
- `patterns.*` lists documented as replace-only; `scores` key authority noted in the schema;
  `rails.general.max_method_loc` wired into `rails-architecture.md`.
- `.idea/` added to the repo `.gitignore`. Removed the global `agents/` gitignore entry and
  reframed the repo `agents/` negation as **defensive portability**. Removed legacy `.wip/`,
  empty `docs/`, and `.DS_Store` cruft.

### Fixed (self-audit)
- Lens-count drift in `ie-review`/`ie-audit` frontmatter (said "four", run up to five).
- Bare `subagent-template.md` citation in the predictability lens → full
  `${CLAUDE_PLUGIN_ROOT}` path.
- Unbound `OUT_ARG`/`REPORT_DIR` in the three orchestrators' dispatch bash.
- Stale "TBD — default report-only" fix-policy note in `PLAN.md`.

## [0.2.0] — 2026-06-03

First feature-complete release: 5 lenses, 5 skills, `.intense` config, Rails architecture
audit + 14-pattern catalog.

### Added
- **Phases 0–3** — the four universal lenses (predictability, convention, simplicity,
  experience); five skills (`ie-init`, `ie-plan-assist`, `ie-validate-plan`, `ie-review`,
  `ie-audit`); the shared reference/contract layer; and the researched knowledge base
  (9 principle docs, 6 framework docs, 6 agnostic docs), each with violation-smell
  checklists and cited sources.
- **Phase 4** — packaging: `plugin.json`, `marketplace.json`, READMEs; `resources/` moved
  inside the plugin for install self-containment.
- **Phase 5** — dogfood: ran `ie-audit` on the plugin itself; fixed P1/P2 at the
  orchestrator ↔ lens seam (scores 6/6 → 9/8).
- **Phase 6** — architecture, patterns & config: the `ie-architecture-reviewer` lens (5th,
  framework-specific, code/audit-only); the `.intense` config system
  (`config/defaults/*.yaml` + `config-resolution.md`); the Rails pattern catalog
  (`resources/patterns/rails.yaml`, 14 patterns) and architecture-smell heuristics
  (`rails-architecture.md`); the `/ie-init` scaffolder; wiring into `ie-audit`/`ie-review`.

### Fixed
- **The `agents/` gitignore trap.** A global gitignore ignored `agents/`, so all five lens
  agents were never committed — an installed plugin would have had **zero agents**. The repo
  `.gitignore` re-includes `plugins/intent-engineering/agents/`. **Keep that negation on any
  clone/fork.** Found by the dogfood loop, not by luck.

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
