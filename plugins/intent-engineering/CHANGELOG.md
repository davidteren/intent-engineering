# Changelog — intent-engineering

All notable changes to the **intent-engineering** plugin. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning is
[SemVer](https://semver.org/).

This file ships inside the installable plugin and tracks the latest release.
The **full dated history** lives in the development repo:
<https://github.com/davidteren/intent-engineering/blob/main/CHANGELOG.md>.

## [0.6.0] — 2026-07-19

Portable report layout: drop `wip/` as the plugin default.

### Changed
- **Two-layer artifacts:** run scratch → `.intense/runs/<run-id>/` (cleaned up after
  publish); published report → `docs/intent-engineering/<stamp>-<skill>[-scope].md`.
- Config: `artifacts.run_dir` / `artifacts.report_dir` / `artifacts.cleanup_runs`
  replace the default `report_dir: wip/intent-engineering`.
- Legacy top-level `report_dir` without `artifacts:` still works (single-bucket, no
  cleanup).
- `/ie-init` offers to gitignore `.intense/runs/`.

See the [full changelog](https://github.com/davidteren/intent-engineering/blob/main/CHANGELOG.md)
for the complete history (0.1.0 → 0.6.0).
