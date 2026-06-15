# intent-engineering

A Claude Code plugin that enforces **intent engineering**: software that behaves the
way a reasonable developer or user already expects.

It applies a set of well-established design principles — the Principle of Least
Astonishment, DWIM, WYSIWYG, Convention over Configuration, Occam's Razor (KISS/YAGNI),
Human Interface Guidelines, Look and Feel, and UX design — plus framework architecture
analysis, as review **lenses** that fan out as parallel agents and return scored,
deduplicated findings with concrete fixes.

## What it does

Set up once with `/ie-init`, then run the lenses across four contexts — planning,
plan validation, code review, and codebase audit:

| Skill | Use it on | What you get |
|-------|-----------|--------------|
| `/ie-init` | a repo, once | Scaffolds `.intense/` config (lens toggles, pattern policy, thresholds) so the team can tune the lenses and commit the settings. |
| `/ie-plan-assist` | a planning draft / an approach you're weighing | An advisory checklist of the principle decisions to get right *now*, tailored to the work. Non-blocking. |
| `/ie-validate-plan` | a finished plan / spec / requirements doc | Dimensional 0–10 ratings + the design gaps to resolve before coding. |
| `/ie-review` | a PR, branch, or local changes | Findings grouped by severity; in interactive mode it applies safe, verified fixes (never pushes). |
| `/ie-audit` | a whole codebase, subsystem, or feature | A posture report — per-dimension scores and the top gaps to fix first. |

### The five lenses

- **Predictability** (`ie-predictability-reviewer`) — least-astonishment, DWIM,
  WYSIWYG. Name/behavior mismatch, hidden side effects, surprising returns, silent
  failures, preview/state divergence.
- **Convention** (`ie-convention-reviewer`) — convention over configuration + framework
  idiom. Reinvented conventions, config where convention exists, non-idiomatic code.
  **Reads your repo's `CLAUDE.md`/`AGENTS.md` first — local conventions win.**
- **Simplicity** (`ie-simplicity-reviewer`) — Occam, KISS, YAGNI. Needless abstraction,
  speculative generality, knobs nobody sets. Also guards against over-simplifying away
  real requirements.
- **Experience** (`ie-experience-reviewer`) — HIG, look-and-feel, UX. Missing
  interaction states, broken keyboard/focus, accessibility gaps, weak information
  architecture, AI-slop design. Runs only on user-facing surfaces.
- **Architecture** (`ie-architecture-reviewer`) — framework structure (Rails + Python +
  Laravel today). Fat models/routers/controllers, God objects/modules, misused service
  objects, callback hell, business logic in schemas, queries in views / N+1, layer leaks,
  Law of Demeter. Classifies design-pattern instances against a per-stack catalog, raises
  unidentified patterns, and enforces your `.intense/` allow/block/approved policy.
  Heuristic-first; optionally enriched by `reek`/`flog`/`brakeman` (Ruby), `ruff`/`radon`
  (Python), or `phpstan`/`phpmd` (Laravel) if installed. Code/audit only, when a supported
  framework is detected.

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
  Python, Laravel, Swift/iOS).
- `resources/agnostic/` — cross-cutting topics (naming, defaults & configuration, error
  handling, API design, accessibility, information architecture).
- `resources/frameworks/{rails,python,laravel}-architecture.md` + `resources/patterns/{rails,python,laravel}.yaml`
  — the architecture lens's per-stack smell heuristics and design-pattern catalogs.

The "Violation smells" section of each doc is the lens's detection checklist.

## Configuration (`.intense/`)

Run `/ie-init` to scaffold a project config into `.intense/` at your repo root, then
commit it. Project config **supersedes** the plugin defaults
(`config/defaults/`):

- `ways-of-working.yaml` — lens toggles (`on`/`off`/`auto`), severity overrides, local
  conventions the convention lens must honor, the confidence gate, report dir.
- `patterns.yaml` — design-pattern policy: `allowed`, `blocked` (no new use), and
  `approved` (grandfathered paths). The architecture lens enforces it.
- `thresholds.yaml` — architecture metric limits (fat model/controller, God object,
  service object, …).

Merge rule: project overrides global key-by-key; lists replace unless the block sets
`extends: true`. See `references/config-resolution.md`.

## Reports

By default every skill writes to `wip/intent-engineering/<run-id>/` in the target
repo (`report.md`, per-lens JSON, `metadata.json`). Override with `out:<path>`. Pass
`mode:agent` to any review/audit/validate skill to get a single JSON object instead of
markdown (for programmatic callers).

## Install

```
/plugin marketplace add /path/to/intent-engineering   # the repo root (has .claude-plugin/marketplace.json)
/plugin install intent-engineering
```

Then the `/ie-*` skills and `ie-*-reviewer` agents are available.

## Conventions this plugin assumes

- `${CLAUDE_PLUGIN_ROOT}` resolves at runtime (standard in Claude Code) — lenses read
  their knowledge docs from there.
- Reports go to `wip/` so they're easy to gitignore.
- Read-only by default; only `/ie-review` in interactive mode mutates (applies safe
  fixes, commits on a clean tree, never pushes) and `/ie-init` writes under `.intense/`.
- The five lens agents ship in `agents/`. If your global git ignore excludes `agents/`
  (a common pattern), the repo `.gitignore` here re-includes them — keep that negation
  so the plugin stays installable.
