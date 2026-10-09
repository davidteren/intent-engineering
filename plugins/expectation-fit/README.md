# expectation-fit

A Claude Code plugin that enforces **expectation fit**: software that behaves the
way a reasonable developer or user already expects.

It applies a set of well-established design principles — the Principle of Least
Astonishment, DWIM, WYSIWYG, Convention over Configuration, Occam's Razor (KISS/YAGNI),
Human Interface Guidelines, Look and Feel, and UX design — plus framework architecture
analysis, as review **lenses** that fan out as parallel agents and return scored,
deduplicated findings with concrete fixes.

## What it does

Defaults work with no project config. Run `/fit-setup` when you want project policy
(multi-repo placement, CI/Copilot auto sources, severity align, preferred patterns, or
thresholds). Then use the lenses across planning, plan validation, code review, and
codebase audit. After a reviewed PR merges, fold learnings back with `/fit-from-pr-learnings`:

| Skill | Use it on | What you get |
|-------|-----------|--------------|
| `/fit-setup` | a repo or multi-repo workspace | Setup/upgrade wizard for `.expectation-fit/` (placement, auto sources, severity align, pattern preference, lens toggles, thresholds). Modes: fresh, upgrade, calibrate. |
| `/fit-plan-assist` | a planning draft / an approach you're weighing | An advisory checklist of the principle decisions to get right *now*, tailored to the work. Non-blocking. |
| `/fit-validate-plan` | a finished plan / spec / requirements doc | Dimensional 0–10 ratings + the design gaps to resolve before coding. |
| `/fit-review` | a PR, branch, or local changes | Findings grouped by severity; in interactive mode it applies safe, verified fixes (never pushes). |
| `/fit-audit` | a whole codebase, subsystem, or feature | A posture report — per-dimension scores and the top gaps to fix first. |
| `/fit-from-pr-learnings` | `pr:` numbers of merged, reviewed PRs, or a triage doc | Notes, sources, and severity overrides mined from review learnings (no silent clobber). |

### The five lenses

- **Predictability** (`fit-predictability-reviewer`) — least-astonishment, DWIM,
  WYSIWYG. Name/behavior mismatch, hidden side effects, surprising returns, silent
  failures, preview/state divergence.
- **Convention** (`fit-convention-reviewer`) — convention over configuration + framework
  idiom. Reinvented conventions, config where convention exists, non-idiomatic code.
  **Reads your repo's `CLAUDE.md`/`AGENTS.md` first — local conventions win.**
- **Simplicity** (`fit-simplicity-reviewer`) — Occam, KISS, YAGNI. Needless abstraction,
  speculative generality, knobs nobody sets. Also guards against over-simplifying away
  real requirements.
- **Experience** (`fit-experience-reviewer`) — HIG, look-and-feel, UX. Missing
  interaction states, non-semantic controls, form/destructive feedback gaps, broken
  keyboard/focus, accessibility gaps, weak information architecture, AI-slop design.
  Greppable smell cards in `ux-interaction-smells.md`. Runs only on user-facing surfaces.
- **Architecture** (`fit-architecture-reviewer`) — framework structure (Rails, Python
  (FastAPI), Laravel, Express, Phoenix, React today). Fat models/routers/controllers/
  handlers/components, God objects/modules/contexts, misused service objects, callback hell,
  business logic in schemas/changesets/components, queries in views / N+1, prop drilling,
  effect overuse, layer leaks, async/process misuse, Law of Demeter. Classifies design-pattern
  instances against a per-stack catalog, raises unidentified patterns, and enforces your
  `.expectation-fit/` allow/block/approved policy. Heuristic-first; optionally enriched by
  `reek`/`flog` (Ruby), `ruff`/`radon` (Python), `phpstan`/`phpmd` (Laravel),
  `eslint`/`madge` (Express, React), or `credo`/`boundary` (Phoenix) if installed. Code/audit
  only, when a supported framework is detected.

Every finding names the **broken expectation** (not just "this is surprising"), carries
a confidence anchor, and proposes a concrete fix. When two principles conflict (e.g.
DWIM's forgiving input vs least-astonishment's no-surprises), the lens flags the
**tension** and presents the trade-off rather than dictating.

## Knowledge base

The lenses are grounded in researched docs under `resources/` (bundled with the
plugin):

- `resources/principles/` — one doc per principle (definition, origin, violation
  smells, examples, how-to-apply, cited sources).
- `resources/frameworks/` — per-stack conventions (Rails, Ruby, React, TypeScript,
  Python (FastAPI), Laravel, Express, Phoenix, Swift/iOS).
- `resources/agnostic/` — cross-cutting topics (naming, defaults & configuration, error
  handling, API design, accessibility, information architecture).
- `resources/frameworks/{rails,python,laravel,express,phoenix,react}-architecture.md` + `resources/patterns/{rails,python,laravel,express,phoenix,react}.yaml`
  — the architecture lens's per-stack smell heuristics and design-pattern catalogs.

The "Violation smells" section of each doc is the lens's detection checklist.

## Configuration (`.expectation-fit/`)

Recommended once you review a repo more than once: run `/fit-setup` once to set up (or later `/fit-setup upgrade`) project config,
then commit `.expectation-fit/`. Project config **supersedes** the plugin defaults
(`config/defaults/`):

- `ways-of-working.yaml` — lens toggles (`on`/`off`/`auto`), severity overrides,
  `severity_align`, local conventions (`notes`, `sources`, **`auto`** discovery of
  Copilot / instructions / PR gates), the confidence gate, and **`artifacts.*`**
  (`run_dir`, `report_dir`, `cleanup_runs` — two-layer report layout).
- `patterns.yaml` — design-pattern policy: `preferred` (A instead of B), `allowed`,
  `blocked` (no new use), and `approved` (grandfathered paths). The architecture lens
  enforces it.
- `thresholds.yaml` — architecture metric limits (fat model/controller, God object,
  service object, …).

### First-run shapes

**Monolith** (single app repo):

```text
/fit-setup              # or /fit-setup all
/fit-setup calibrate p90   # optional, Arch pack stacks
```

**Multi-repo workspace** (e.g. backend + frontend siblings): prefer the **workspace root**.
The wizard places one shared `.expectation-fit/` there, sets `conventions.auto.roots` to the
sibling apps, and scaffolds threshold namespaces for every detected Arch pack stack.
If you start inside a child app, the wizard should still offer workspace-root placement —
confirm before accepting. Child apps inherit via walk-up when you run `/fit-review` from
inside them. Non-interactive: `multi-repo` and/or `roots:backend,frontend`.

**Already have `.expectation-fit/`?** `/fit-setup upgrade` diffs capabilities against current plugin
defaults and merges **missing** keys only (never wipes your notes). Optional later:
`/fit-from-pr-learnings` to mine PR triage into notes/severities.

Merge rule: project overrides global key-by-key; lists replace unless the block sets
`extends: true`. See `references/config-resolution.md`.

## Reports

Two layers (see `references/config-resolution.md`):

| Layer | Default | Purpose |
|-------|---------|---------|
| Run scratch | `.expectation-fit/runs/<run-id>/` | per-lens JSON while the run is open |
| Published report | `docs/expectation-fit/<stamp>-<skill>[-scope].md` | human-facing result |

After a successful publish, run scratch is deleted (`artifacts.cleanup_runs: true`).
Override the published path with `out:<path>`. Configure permanently via
`artifacts.*` in `.expectation-fit/ways-of-working.yaml`. Pass `mode:agent` for a single JSON
object (also written under the publish dir as `.json`) for programmatic callers.

## Install

```
/plugin marketplace add /path/to/expectation-fit   # the repo root (has .claude-plugin/marketplace.json)
/plugin install expectation-fit
```

Then the `/fit-*` skills and `fit-*-reviewer` agents are available.

## Grok (optional, source repo only)

This installable plugin is Claude Code. The development repo also has a Grok
workflow at `.grok/workflows/fit-review.rhai`. Marketplace install does **not**
ship that file. Clone the repo and run `/workflow fit-review` from a Grok
session. Report is run scratch. No product-code apply. See
[`.grok/workflows/README.md`](../../.grok/workflows/README.md).

## Conventions this plugin assumes

- `${CLAUDE_PLUGIN_ROOT}` resolves at runtime (standard in Claude Code) — lenses read
  their knowledge docs from there.
- Published reports go under `docs/expectation-fit/`; ephemeral scratch under
  `.expectation-fit/runs/` (cleaned up after publish; gitignore via `/fit-setup`).
- Read-only by default; only `/fit-review` in interactive mode mutates code (applies safe
  fixes, commits on a clean tree, never pushes). Orchestrators write the published
  report; `/fit-setup` writes under `.expectation-fit/` (and may append a `.gitignore` line).
- The five lens agents ship in `agents/`. If your global git ignore excludes `agents/`
  (a common pattern), the repo `.gitignore` here re-includes them — keep that negation
  so the plugin stays installable.
