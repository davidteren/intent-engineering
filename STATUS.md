# STATUS — intent-engineering

Living status **snapshot** — the current state of the project, not a log. For the dated
history of changes and decisions, see **[CHANGELOG.md](CHANGELOG.md)**. For the design and
phase detail, **PLAN.md**. For how to work in this repo, **AGENTS.md**.

**State:** ✅ feature-complete · 🚀 published & released (v0.4.0) · **Updated:** 2026-06-15

---

## What exists today

A Claude Code plugin enforcing *intent engineering*. 5 lenses, 5 skills, `.intense` config,
architecture audit for **6 stacks** (Rails, Python (FastAPI), Laravel, Express, Phoenix, React)
+ per-stack pattern catalogs.

- **Lenses:** predictability, simplicity (always-on); convention, experience, architecture
  (conditional — architecture supports Rails, Python (FastAPI), Laravel, Express, Phoenix,
  React; code/audit).
- **Skills:** `/ie-init`, `/ie-plan-assist`, `/ie-validate-plan`, `/ie-review`, `/ie-audit`.
- **Contract layer:** findings schema, subagent template, lens catalog, stack catalog
  (the stack registry), scoring rubric, report template, principle index, config resolution.
- **Knowledge base:** 9 principle docs, 12 framework docs (incl. `rails-architecture`,
  `python-architecture`, `laravel-architecture`, `express-architecture`, `phoenix-architecture`,
  `react-architecture`), 6 agnostic docs, 6 pattern catalogs (`rails.yaml` 14, `python.yaml` 13,
  `laravel.yaml` 15, `express.yaml` 12, `phoenix.yaml` 11, `react.yaml` 11).
- **Automated check:** `scripts/check-contracts.rb` — 105 checks across 10 sections, green
  (section 8 cross-references generalized to every stack with a threshold namespace;
  section 10 enforces stack-registry consistency).
- **Stack registry** (`references/stack-catalog.md`) — one source of truth for stack
  detection + which packs each loads; the architecture lens, the skills, and a stack-aware
  `/ie-init` read it, so adding a stack is data + a catalog row, not skill edits.

## Published

- **Repo (public, MIT):** https://github.com/davidteren/intent-engineering
- **Landing site:** https://davidteren.github.io/intent-engineering/ (GitHub Pages, `docs/`)
- **Release:** `v0.4.0` (Latest) — Laravel + Express + Phoenix + React architecture stacks;
  `v0.3.0` (Python + stack registry) and `v0.2.0` prior.
- **CI:** `contracts` workflow runs `check-contracts.rb` on every PR + pushes to `main`;
  `contract-integrity check` is a required status check (branch protection on `main`).
- Announced on X (2026-06-14).

Install in any repo:

```
/plugin marketplace add https://github.com/davidteren/intent-engineering
/plugin install intent-engineering
```

## Health

- All JSON/YAML valid; 5 agents + 5 skills git-tracked; working tree clean.
- Dogfooded on self (×3) + a synthetic Rails fixture + a manual `ie-audit` run
  (verdict: healthy, all surfaced findings fixed).
- Python architecture pack dogfooded on a real-world FastAPI service (read-only): verdict
  healthy, near-zero false positives; the run surfaced two pack bugs (a `Request`/`Response`
  grep false-positive, a missing `document_renderer` pattern) and a placement smell — all
  folded back into the docs/catalog before commit.

## Stack coverage roadmap

The extension point is in place: a stack is **data** (a `stack-catalog.md` row + packs),
not skill edits. Each new architecture stack is authored **research-first with cited
Sources** (same bar as the rest of the KB), then dogfooded on a real repo.

**Per stack, "done" = all four:** `frameworks/<stack>-architecture.md` (smells + Sources),
`patterns/<stack>.yaml` (catalog), a `<stack>.*` namespace in `thresholds.yaml`, and the
`stack-catalog.md` row flipped to **Arch pack ✅** (the contract check enforces agreement).

| Stack | Convention doc | Arch pack | Status / next step |
|-------|:--------------:|:---------:|--------------------|
| `rails` | ✅ | ✅ | Done. Dogfood on a real Rails repo still pending. |
| `python` | ✅ | ✅ | Done (FastAPI-first). Dogfooded on a real FastAPI service. |
| `laravel` | ✅ | ✅ | **Done + dogfooded.** 8 smells (fat-controller, fat-model, god-class, misused-service, query-in-view/N+1, logic-in-routes, fat-job, law-of-demeter) + 15-pattern catalog, research-backed (alexeymezenin, Laravel docs, laravel-actions, PSR-12). Dogfooded read-only on a mature OSS Laravel 12 app (domain-organized layout, ~471 app files): prose held (app came back clean, no false positives); surfaced that structured signals were vanilla-Laravel-shaped — folded back layout-agnostic path globs, `query_object`/`notification` patterns + broadened `action`, `max_actions` 10→15, and grep caveats (static-method N+1, low-signal Demeter). |
| `express` | ✅ | ✅ | **Done.** 8 smells (fat-route-handler, god-module, god-object, misused-service, layer-leak, fat-middleware, async-error-gap, law-of-demeter) + 12-pattern catalog, research-backed (bulletproof-nodejs 3-layer, goldbergyoni nodebestpractices, Express docs, 12-factor). **Dogfood on a real Express repo pending.** |
| `phoenix` | ✅ | ✅ | **Done.** 8 smells (fat-controller, context-bypass, god-context, fat-liveview, business-logic-in-changeset, god-module, process-misuse, law-of-demeter) + 11-pattern catalog, research-backed (Phoenix Contexts guide, Elixir process anti-patterns, Ecto docs). Resolved via a **data pack** (structural/layering + OTP placement); deep supervision-tree/OTP correctness left to a future reliability review or dedicated agent. **Dogfood on a real Phoenix repo pending.** |
| `react` | ✅ | ✅ | **Done + dogfooded.** 8 smells (god-component, logic-in-component, fat-hook, prop-drilling, effect-overuse, god-context, god-module, law-of-demeter) + 11-pattern catalog, research-backed (React docs "You Might Not Need an Effect" / custom hooks / context, patterns.dev, Martin Fowler). Dogfooded read-only on a large production React app (React 18 + Next + **MobX**, ~429 components): React-core heuristics calibrated well (found real god-components + a derived-state-in-effect); surfaced two pack gaps — no **MobX** awareness (the worst smell was a 4117-LOC god-store) and no Next/route-manifest exemption — both folded back (MobX recognition in `state_store`/`observer()`, a `react.store.*` threshold block, store/route-manifest exemptions). |
| `ruby`, `typescript`, `swift-ios` | ✅ | ⬜ | Convention-only by design; no arch pack planned unless a real consumer appears. |

Research uses Exa + Firecrawl; author the two data files + threshold namespace, flip the
registry row, run `check-contracts.rb`, then dogfood on a real repo and fold findings back.

## Pending

- [ ] **Install & use it** — now installable from the published repo (above); run the
      `/ie-*` skills as installed skills (so far orchestrated by hand / via the audit run).
- [ ] **Run on a real Rails repo**; fold learnings back into `resources/`.
- [ ] **Dogfood the Express + Phoenix packs** on real repos; fold findings back into the docs/catalogs. (React + Laravel done.)
- [ ] **More architecture stacks** as real dogfood targets appear (e.g. Go, Spring, Django,
      Vue). Research-first, drop into the registry — `ruby`/`typescript`/`swift-ios` stay
      convention-only unless a consumer needs them.
- [ ] **Deferred niceties** → `wip/improvements.md` — the hardening backlog is closed
      (contract check covers it); remaining are optional: a committed test fixture + lens
      regression test, a single-sourced orchestration reference, and a git pre-commit hook.

## Phases — all complete

Detail in **CHANGELOG.md** (what shipped) and **PLAN.md** (design).

| Phase | | Status |
|-------|--|--------|
| 0 | Scaffold & plan | ✅ |
| 1 | Principle research | ✅ |
| 2 | Conventions research | ✅ |
| 3 | Author plugin | ✅ |
| 4 | Package & install | ✅ (published; installable from GitHub) |
| 5 | Dogfood | ✅ (self; real-repo run pending) |
| 6 | Architecture, patterns & config | ✅ |

## Pointers

- **CHANGELOG.md** — dated change history + decisions.
- **PLAN.md** — design + per-phase detail.
- **AGENTS.md** — contributor/agent guide · **plugins/intent-engineering/README.md** — end-user usage.
- **wip/** (gitignored) — scratch, run reports, `improvements.md` backlog, `future-ideas.md`.
