# STATUS — intent-engineering

Living status **snapshot** — the current state of the project, not a log. For the dated
history of changes and decisions, see **[CHANGELOG.md](CHANGELOG.md)**. For the design and
phase detail, **PLAN.md**. For how to work in this repo, **AGENTS.md**.

**State:** ✅ feature-complete · 🚀 published & released (v0.2.0) · **Updated:** 2026-06-15

---

## What exists today

A Claude Code plugin enforcing *intent engineering*. 5 lenses, 5 skills, `.intense` config,
Rails + Python architecture audit + per-stack pattern catalogs.

- **Lenses:** predictability, simplicity (always-on); convention, experience, architecture
  (conditional — architecture supports Rails + Python, code/audit).
- **Skills:** `/ie-init`, `/ie-plan-assist`, `/ie-validate-plan`, `/ie-review`, `/ie-audit`.
- **Contract layer:** findings schema, subagent template, lens catalog, stack catalog
  (the stack registry), scoring rubric, report template, principle index, config resolution.
- **Knowledge base:** 9 principle docs, 8 framework docs (incl. `rails-architecture`,
  `python-architecture`), 6 agnostic docs, 2 pattern catalogs (`rails.yaml` 14,
  `python.yaml` 13).
- **Automated check:** `scripts/check-contracts.rb` — 75 checks across 10 sections, green
  (section 8 cross-references generalized to every stack with a threshold namespace;
  section 10 enforces stack-registry consistency).
- **Stack registry** (`references/stack-catalog.md`) — one source of truth for stack
  detection + which packs each loads; the architecture lens, the skills, and a stack-aware
  `/ie-init` read it, so adding a stack is data + a catalog row, not skill edits.

## Published

- **Repo (public, MIT):** https://github.com/davidteren/intent-engineering
- **Landing site:** https://davidteren.github.io/intent-engineering/ (GitHub Pages, `docs/`)
- **Release:** `v0.2.0` (Latest), tag on HEAD.
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

## Pending

- [ ] **Install & use it** — now installable from the published repo (above); run the
      `/ie-*` skills as installed skills (so far orchestrated by hand / via the audit run).
- [ ] **Run on a real Rails repo**; fold learnings back into `resources/`.
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
