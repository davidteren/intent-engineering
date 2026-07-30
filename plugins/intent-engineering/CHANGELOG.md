# Changelog — intent-engineering

All notable changes to the **intent-engineering** plugin. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning is
[SemVer](https://semver.org/).

This file ships inside the installable plugin and tracks the latest release.
The **full dated history** lives in the development repo:
<https://github.com/davidteren/intent-engineering/blob/main/CHANGELOG.md>.

## [Unreleased]

### Added
- **`/ie-init` setup/upgrade wizard** — fresh | upgrade | calibrate; monolith vs
  multi-repo placement + `auto.roots`; capability questions (`conventions.auto`,
  `severity_align`, preferred patterns); upgrade merges missing keys only.

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

See the [full changelog](https://github.com/davidteren/intent-engineering/blob/main/CHANGELOG.md)
for complete history (0.1.0 → 0.7.0).
