# Changelog: expectation-fit

All notable changes to the **expectation-fit** plugin (named intent-engineering before
0.9.0). Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning is
[SemVer](https://semver.org/).

This file ships inside the installable plugin and tracks the latest release.
The **full dated history** lives in the development repo:
<https://github.com/davidteren/intent-engineering/blob/main/CHANGELOG.md>.

## [0.9.0] - 2026-10-09

Renamed to expectation-fit, plus a round of report and merge fixes.

### Breaking
- **Rename.** The plugin is `expectation-fit` (marketplace
  `expectation-fit-marketplace`). Skills and agents use the `fit-` prefix, and `/ie-init`
  is now `/fit-setup`. Config lives in `.expectation-fit/` and the env var is
  `EXPECTATION_FIT_CONFIG_DIR`. The legacy `.intense/` folder and `INTENSE_CONFIG_DIR`
  are still read. See "Upgrading from intent-engineering" in the README.
- **Reports leave git by default.** Reports go to `.expectation-fit/reports/` and run
  scratch to `.expectation-fit/runs/`. Both folders ignore themselves. Set
  `artifacts.report_dir` to commit reports.

### Highlights
- Shared "Merge and gate" steps in `references/report-template.md`: off-schema findings
  are repaired, every dropped finding is listed under Rejected, and every re-grade is
  logged.
- Clear lens status words (`ok`, `clean`, `skipped`, `not_selected`, `failed`) and a
  verdict rule that never reports Ready while a lens failed or a read was partial.
- `mode:agent` has a full JSON example, a field list and provenance fields.
- `fit-review` applies only fixes that pass the Stage 5 step 7 gate, and checks for
  copies before it replaces text.
- `fit-validate-plan` accepts several documents as one set, with one report and one
  artifact file per document and lens.
- `lenses:<list>` token on `fit-review`, `fit-validate-plan` and `fit-audit`.
- `/fit-setup upgrade` offers to move the legacy folder and the old default report
  paths.

## [0.8.0] — 2026-07-30

Workspace-aware setup and CI-aligned conventions.

### Highlights
- **`/ie-init` wizard** — fresh | upgrade (calibrate from 0.7 stays on same entry);
  monolith vs multi-repo placement + `auto.roots` / `roots:` tokens; capability
  questions; upgrade merges missing keys only.
- **`/ie-from-pr-learnings`** — PR triage / `pr:` URLs → notes, sources,
  severity_overrides (no silent clobber, never push).
- **`conventions.auto` + smell-first `severity_align`** — discover Copilot /
  instructions / PR gates; promote only when theme smells match (or principles when
  smells empty).
- **`patterns.preferred`** — directional A-instead-of-B for new work.
- **First run:** install → optional `/ie-init` → `/ie-audit` or `/ie-review`.

### Contract suite
141 checks across 12 sections.

See the [full changelog](https://github.com/davidteren/intent-engineering/blob/main/CHANGELOG.md)
for complete history (0.1.0 → 0.8.0).

## [0.7.0] — 2026-07-29

Hardening + discoverability release.

### Highlights
- **Config walk-up** — nearest `.intense/` from cwd (not only `./.intense`);
  `config:<path>` / `INTENSE_CONFIG_DIR`; Coverage always states Config source.
- **Skill evals** — per-skill `evals.json` pins refusal cases (read-only, never-push,
  no-clobber); contract section 12.
- **Experience greppable smells** — `ux-interaction-smells.md` for the experience lens.
- **`ie-init calibrate`** — measure distributions; propose thresholds with evidence.
- **`conventions.sources`** — declare review-bot / standards paths; audit CI delta.
- **Apply safety** — shared `fix_class` / `gated_auto`; catalog-only stack selection;
  lens failed/skipped/clean honesty.

### Contract suite
138 checks across 12 sections (was 105/10 before the 0.6→0.7 hardening line).
