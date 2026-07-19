# intent-engineering

[![contracts](https://github.com/davidteren/intent-engineering/actions/workflows/contracts.yml/badge.svg)](https://github.com/davidteren/intent-engineering/actions/workflows/contracts.yml)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**Site:** [davidteren.github.io/intent-engineering](https://davidteren.github.io/intent-engineering/)

A Claude Code plugin that enforces **intent engineering**: software — and the experience
around it — that behaves the way a reasonable developer or user already expects. It guards
against *surprise* on both sides: hidden side effects and reinvented conventions in the
**code**, and broken flows, weak interaction states, or dark patterns in the **UX**. It
applies a set of well-established design principles — plus framework architecture analysis
across six stacks (Rails, Python/FastAPI, Laravel, Express, Phoenix, React) — as review
**lenses** that fan out as parallel agents and return scored, deduplicated findings with
concrete fixes.

> **What / Why / How (plain language)**
>
> **What:** A toolkit you run against a plan, a pull request, your local changes, or a
> whole codebase. It checks whether the work follows time-tested principles of "least
> surprise" — does the code/UI behave the way people expect, follow conventions, stay
> simple, and feel coherent?
>
> **Why:** Surprising software is expensive. Hidden side effects, reinvented conventions,
> needless complexity, and inconsistent UX cost reviewers, users, and future maintainers
> time. Most of it is caught late (in review) or never. This plugin makes the principles
> checkable and repeatable.
>
> **How:** A small set of lenses (each grounded in a researched principle) run as parallel
> agents. They return scored, deduplicated findings with concrete fixes, written to a
> report in `wip/`. The same lenses work in four contexts: planning, plan validation, code
> review, and codebase audit.

> This is the **development repo** for the plugin (and its marketplace). The installable
> plugin is self-contained under [`plugins/intent-engineering/`](plugins/intent-engineering/README.md).
> Contributing? Read **[AGENTS.md](AGENTS.md)** first.

---

## The skills (four contexts + setup)

| Skill | Use it on | What you get |
|-------|-----------|--------------|
| `/ie-init` | a repo, once | Scaffolds `.intense/` config (lens toggles, pattern policy, thresholds) so the team can tune the lenses and commit the settings. |
| `/ie-plan-assist` | a planning draft / an approach you're weighing | An advisory checklist of the principle decisions to get right *now*, tailored to the work. Non-blocking. |
| `/ie-validate-plan` | a finished plan / spec / requirements doc | Dimensional 0–10 ratings + the design gaps to resolve before coding. |
| `/ie-review` | a PR, branch, or local changes | Findings grouped by severity; in interactive mode applies safe, verified fixes (never pushes). |
| `/ie-audit` | a whole codebase, subsystem, or feature | A posture report — per-dimension scores and the top gaps to fix first. |

---

## The five lenses

| Lens (agent) | Principles | Hunts for |
|--------------|-----------|-----------|
| **Predictability** (`ie-predictability-reviewer`) | least-astonishment, DWIM, WYSIWYG | Name/behavior mismatch, hidden side effects, surprising returns, inconsistent branch returns, silent failures, controls that don't do what their label implies, preview/state divergence |
| **Convention** (`ie-convention-reviewer`) | convention-over-configuration, framework idiom | Reinvented conventions, config where convention exists, one-off patterns that fight the repo/framework, non-idiomatic structure/naming. *Reads your repo's `CLAUDE.md`/`AGENTS.md` first — local conventions win.* |
| **Simplicity** (`ie-simplicity-reviewer`) | Occam, KISS, YAGNI | Needless abstraction, premature generality, knobs nobody sets, layers that don't earn their keep. Also guards against over-simplifying away real requirements. |
| **Experience** (`ie-experience-reviewer`) | HIG, look-and-feel, UX | Missing interaction states, inconsistent look/feel, broken keyboard/focus/back-button, accessibility gaps, weak information architecture, AI-slop design. User-facing surfaces only. |
| **Architecture** (`ie-architecture-reviewer`) | structural quality, design patterns | Fat models/routers, God objects/modules, fat controllers, misused service objects, callback hell, business logic in schemas, layer leaks, Law of Demeter. Classifies design-pattern instances against a per-stack catalog, raises unidentified patterns, enforces your `.intense/` allow/block/approved policy. Framework-specific (Rails, Python (FastAPI), Laravel, Express, Phoenix, React today), code/audit only; heuristic-first, optionally enriched by `reek`/`flog`/`brakeman` (Ruby), `ruff`/`radon` (Python), `phpstan`/`phpmd` (Laravel), `eslint`/`madge` (Express, React), or `credo`/`boundary` (Phoenix). |

Every finding names the **broken expectation** (not just "this is surprising"), carries a
confidence anchor, and proposes a concrete fix. When two principles conflict (e.g. DWIM's
forgiving input vs least-astonishment's no-surprises), the lens flags the **tension** and
presents the trade-off rather than dictating.

---

## Source principles (the knowledge base)

The lenses are grounded in researched docs under `plugins/intent-engineering/resources/`,
each with a definition, origin, core tenets, **violation smells** (the lens's detection
checklist), good vs bad examples, how-to-apply, and cited sources.

**Principles** (`resources/principles/`):

| Doc | Principle | Feeds lens |
|-----|-----------|-----------|
| `least-astonishment.md` | Principle of Least Astonishment (POLA) | Predictability |
| `dwim.md` | Do What I Mean | Predictability |
| `wysiwyg.md` | WYSIWYG | Predictability |
| `convention-over-configuration.md` | Convention over Configuration | Convention |
| `occams-razor.md` | Occam's Razor (+ KISS, YAGNI) | Simplicity |
| `human-interface-guidelines.md` | Human Interface Guidelines | Experience |
| `look-and-feel.md` | Look and Feel | Experience |
| `ux-design.md` | User Experience Design | Experience |
| `software-philosophies.md` | Index of the broader philosophy list (DRY, SOLID, POLP, …) | (all) |

**Framework conventions** (`resources/frameworks/`): per-stack docs of the idioms a
practitioner expects — `rails`, `ruby`, `react`, `typescript`, `python`, `laravel`,
`express`, `phoenix`, `swift-ios`, plus `rails-architecture`, `python-architecture`,
`laravel-architecture`, `express-architecture`, `phoenix-architecture`, and
`react-architecture` (the architecture lens's smell heuristics + thresholds). Seed set is
driven by dogfood stacks.

**Agnostic cross-cutting** (`resources/agnostic/`): topics that span stacks — `naming`,
`defaults-and-configuration`, `error-handling`, `api-design`, `accessibility`,
`information-architecture`.

**Pattern catalog** (`resources/patterns/`): `rails.yaml` (14 Rails patterns),
`python.yaml` (13 Python/FastAPI patterns), `laravel.yaml` (15 Laravel patterns),
`express.yaml` (12 Express/Node patterns), `phoenix.yaml` (11 Phoenix/Elixir patterns), and
`react.yaml` (11 React patterns) — each entry an intent, recognition signature, good-use
rubric, and common misuse the architecture lens uses to recognize, classify, and judge
pattern instances.

---

## Configuration (`.intense/`)

Run `/ie-init` to scaffold a project config into `.intense/` at your repo root, then commit
it. Project config **supersedes** the plugin defaults (`config/defaults/`):

- `ways-of-working.yaml` — lens toggles (`on`/`off`/`auto`), severity overrides, local
  conventions the convention lens must honor, confidence gate, report dir.
- `patterns.yaml` — design-pattern policy: `allowed`, `blocked` (no new use), `approved`
  (grandfathered paths). The architecture lens enforces it.
- `thresholds.yaml` — architecture metric limits (fat model/controller, God object,
  service object, …).

Merge rule: project overrides global key-by-key; lists replace (the `conventions` block can
opt into append via `extends: true`; pattern lists are replace-only). See
`references/config-resolution.md`.

---

## Reports

By default every skill writes to `wip/intent-engineering/<run-id>/` in the target repo
(`report.md`, per-lens JSON, `metadata.json`). Override with `out:<path>`. Pass `mode:agent`
to any review/audit/validate skill for a single JSON object instead of markdown.

---

## Install (local dogfooding)

```
/plugin marketplace add /Users/david.teren/Projects/Personal/intent-engineering   # repo root (has .claude-plugin/marketplace.json)
/plugin install intent-engineering
```

Then the `/ie-*` skills and `ie-*-reviewer` agents are available in any repo.

---

## Repo layout

```
.claude-plugin/marketplace.json     marketplace entry (install from repo root)
plugins/intent-engineering/         the installable plugin (self-contained)
  .claude-plugin/plugin.json
  agents/      ie-*-reviewer.md      the five lenses (incl. architecture)
  skills/      ie-*/SKILL.md         contexts: init, plan-assist, validate-plan, review, audit
  references/  *.md, *.json          shared contract (schema, templates, catalogs, config-resolution)
  config/defaults/  *.yaml           shipped config defaults
  resources/   principles/ frameworks/ agnostic/ patterns/   researched knowledge base + catalog
AGENTS.md  CLAUDE.md  PLAN.md  STATUS.md  CHANGELOG.md  LICENSE
```

> **Note on `agents/`:** a common global gitignore excludes `agents/`. The repo
> `.gitignore` re-includes `plugins/intent-engineering/agents/` so the lens agents are
> actually committed — without that negation an installed plugin would have no agents. Keep
> the negation on any clone/fork.
>
> **Note on `resources/`:** the knowledge base lives *inside the plugin* (not the repo
> root) because a Claude Code plugin only ships what's under its plugin directory — keeping
> resources there makes the installed plugin self-contained. Edit them there; they are the
> single source of truth.

## Docs

- **[AGENTS.md](AGENTS.md)** — contributor/agent guide (load-bearing rules, architecture, how to extend).
- **[plugins/intent-engineering/README.md](plugins/intent-engineering/README.md)** — end-user usage detail.
- **PLAN.md** — design and build plan. **STATUS.md** — current-state snapshot. **CHANGELOG.md** — change history.

## License

[MIT](LICENSE) © David Teren
