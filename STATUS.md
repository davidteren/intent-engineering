# STATUS — intent-engineering

Living status **snapshot** — the current state of the project, not a log. For the dated
history of changes and decisions, see **[CHANGELOG.md](CHANGELOG.md)**. For the design and
phase detail, **PLAN.md**. For how to work in this repo, **AGENTS.md**.

**State:** ✅ feature-complete · 📦 **v0.8.0** on branch `feat/ie-init-wizard-0.8` (tag after merge) · **Updated:** 2026-07-30

### Last session handoff

1. **What this is:** Intent Engineering plugin v0.8.0 (setup wizard + CI-aware config).
2. **What we finished:** Wizard, pr-learnings, dogfood fixes, version/docs/site on the branch.
3. **What you do next:** Pre-pr gate, open PR, merge, tag `v0.8.0`, confirm GitHub Pages.

---

## What exists today

A Claude Code plugin enforcing *intent engineering*. 5 lenses, **6 skills**, `.intense`
config, architecture audit for **6 stacks** (Rails, Python (FastAPI), Laravel, Express,
Phoenix, React) + per-stack pattern catalogs.

- **Lenses:** predictability, simplicity (always-on); convention, experience, architecture
  (conditional).
- **Skills:** `/ie-init` (fresh/upgrade/calibrate wizard), `/ie-plan-assist`,
  `/ie-validate-plan`, `/ie-review`, `/ie-audit`, `/ie-from-pr-learnings`.
  **Fresh** = first `.intense/`. **Upgrade** = add new capabilities without wiping notes.
  **Multi-repo** = one shared config + `roots`.
- **Contract layer:** findings schema, subagent template, lens catalog, stack catalog,
  scoring rubric, report template, principle index, config resolution (walk-up,
  `conventions.auto`, smell-first `severity_align`, `patterns.preferred`).
- **Knowledge base:** 9 principle docs, **15** framework docs (9 convention + 6
  architecture packs), 6 agnostic docs (+ UX smell cards), 6 pattern catalogs.
- **Automated check:** `scripts/check-contracts.rb` — **141** checks across 12 sections.
- **Two-layer artifacts** — `.intense/runs/` scratch; `docs/intent-engineering/` published.

## Published

- **Repo (public, MIT):** https://github.com/davidteren/intent-engineering
- **Landing site:** https://davidteren.github.io/intent-engineering/ (GitHub Pages, `docs/`)
- **Release:** **`v0.8.0` (Latest)** — init wizard, multi-repo placement, auto sources,
  severity_align, preferred patterns, ie-from-pr-learnings. Prior: `v0.7.0`.
- **CI:** `contracts` workflow on every PR + `main`.

Install:

```
/plugin marketplace add https://github.com/davidteren/intent-engineering
/plugin install intent-engineering
```

## Health

- Contract suite green (141 checks).
- 5 agents + 6 skills under `plugins/intent-engineering/`.
- Dogfood report: [`docs/intent-engineering/2026-07-30-v0.8.0-dogfood.md`](docs/intent-engineering/2026-07-30-v0.8.0-dogfood.md).

## Open question — potential name/positioning change (PARKED)

Considering renaming **"Intent Engineering"** — parked until the owner re-opens it.
See earlier STATUS / CHANGELOG discussion; do not act without explicit go-ahead.
