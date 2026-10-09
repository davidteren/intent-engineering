# STATUS — expectation-fit

Living status **snapshot** — the current state of the project, not a log. For the dated
history of changes and decisions, see **[CHANGELOG.md](CHANGELOG.md)**. For the design and
phase detail, **PLAN.md**. For how to work in this repo, **AGENTS.md**.

**State:** ✅ feature-complete · 🚀 published & released (**v0.8.0**) · **Updated:** 2026-09-08

### Last session handoff

1. **What this is:** Expectation Fit plugin **v0.8.0**, plus a refreshed GitHub Pages site.
2. **What we finished:** Light and dark site themes, finding-as-hero, social preview, HTML reports.
3. **What you do next:** Open the live site and check both themes.

---

## What exists today

A Claude Code plugin enforcing *expectation fit*. 5 lenses, **6 skills**, `.expectation-fit`
config, architecture audit for **6 stacks** (Rails, Python (FastAPI), Laravel, Express,
Phoenix, React) + per-stack pattern catalogs.

- **Lenses:** predictability, simplicity (always-on); convention, experience, architecture
  (conditional).
- **Skills:** `/fit-setup` (fresh/upgrade/calibrate wizard), `/fit-plan-assist`,
  `/fit-validate-plan`, `/fit-review`, `/fit-audit`, `/fit-from-pr-learnings`.
  **Fresh** = first `.expectation-fit/`. **Upgrade** = add new capabilities without wiping notes.
  **Multi-repo** = one shared config + `roots`.
- **Contract layer:** findings schema, subagent template, lens catalog, stack catalog,
  scoring rubric, report template, principle index, config resolution (walk-up,
  `conventions.auto`, smell-first `severity_align`, `patterns.preferred`).
- **Knowledge base:** 9 principle docs, **15** framework docs (9 convention + 6
  architecture packs), 6 agnostic docs (+ UX smell cards), 6 pattern catalogs.
- **Automated check:** `scripts/check-contracts.rb` — **141** checks across 12 sections.
- **Two-layer artifacts** — `.expectation-fit/runs/` scratch; `docs/expectation-fit/` published.
- **Optional Grok runtime** — `.grok/workflows/fit-review.rhai`. Report-only. Not shipped
  inside the Claude plugin dir. See `.grok/workflows/README.md`.

## Published

- **Repo (public, MIT):** https://github.com/davidteren/intent-engineering
- **Landing site:** https://davidteren.github.io/intent-engineering/ (GitHub Pages, `docs/`)
- **Release:** **`v0.8.0` (Latest)** — init wizard, multi-repo placement, auto sources,
  severity_align, preferred patterns, fit-from-pr-learnings. Prior: `v0.7.0`.
- **CI:** `contracts` workflow on every PR + `main`.

Install:

```
/plugin marketplace add https://github.com/davidteren/intent-engineering
/plugin install expectation-fit
```

## Health

- Contract suite green (141 checks).
- 5 agents + 6 skills under `plugins/expectation-fit/`.
- Dogfood report: [`docs/expectation-fit/2026-07-30-v0.8.0-dogfood.md`](docs/expectation-fit/2026-07-30-v0.8.0-dogfood.md).

## Open question — potential name/positioning change (PARKED)

Considering renaming **"Expectation Fit"** — parked until the owner re-opens it.
See earlier STATUS / CHANGELOG discussion; do not act without explicit go-ahead.
