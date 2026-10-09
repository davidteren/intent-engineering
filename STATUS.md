# STATUS — expectation-fit

Living status **snapshot** — the current state of the project, not a log. For the dated
history of changes and decisions, see **[CHANGELOG.md](CHANGELOG.md)**. For the design and
phase detail, **PLAN.md**. For how to work in this repo, **AGENTS.md**.

**State:** ✅ feature-complete · 🚧 **v0.9.0** on `release/0.9.0`, pending release (latest published: v0.8.0) · **Updated:** 2026-10-09

### Last session handoff

1. **What this is:** The Expectation Fit plugin, on the 0.9.0 release branch.
2. **What we finished:** The rename and 21 fixes are merged on `release/0.9.0`.
3. **What you do next:** Merge the release PR, then tag v0.9.0, update installs, and check the live site at https://davidteren.github.io/intent-engineering/.

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
- **Automated check:** `scripts/check-contracts.rb` — **161** checks across 12 sections.
- **Two-layer artifacts:** `.expectation-fit/runs/` scratch and `.expectation-fit/reports/` reports; both ignore themselves.
- **Optional Grok runtime** — `.grok/workflows/fit-review.rhai`. Report-only. Not shipped
  inside the Claude plugin dir. See `.grok/workflows/README.md`.

## Published

- **Repo (public, MIT):** https://github.com/davidteren/intent-engineering
- **Landing site:** https://davidteren.github.io/intent-engineering/ (GitHub Pages, `docs/`)
- **Release:** **`v0.9.0` pending release** (rename to expectation-fit plus 21 fixes, on
  `release/0.9.0`). Latest published: `v0.8.0`.
- **CI:** `contracts` workflow on every PR + `main`.

Install:

```
/plugin marketplace add https://github.com/davidteren/intent-engineering
/plugin install expectation-fit
```

## Health

- Contract suite green (161 checks).
- 5 agents + 6 skills under `plugins/expectation-fit/`.
- Dogfood report: [`docs/intent-engineering/2026-07-30-v0.8.0-dogfood.md`](docs/intent-engineering/2026-07-30-v0.8.0-dogfood.md).

## Rename

Done in 0.9.0: intent-engineering is now Expectation Fit (#41).
