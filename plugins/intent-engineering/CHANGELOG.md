# Changelog — intent-engineering

All notable changes to the **intent-engineering** plugin. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning is
[SemVer](https://semver.org/).

This file ships inside the installable plugin and tracks the latest release.
The **full dated history** lives in the development repo:
<https://github.com/davidteren/intent-engineering/blob/main/CHANGELOG.md>.

## [0.5.0] — 2026-06-19

Hardening release: all six architecture packs (Rails, Python, Laravel, Express,
Phoenix, React) dogfooded read-only on real production apps and tuned from the
findings, plus a new external-tool-deferral config so a team already running
reek/eslint/phpstan/… isn't given duplicate findings. No new stacks — this
release makes the existing six trustworthy on real codebases.

### Added
- **External-tool preference / anti-duplication config** (`tools.architecture` in
  `ways-of-working.yaml`): `enrich`, `prefer`, `report`, `off`. The architecture
  lens defers to an installed static-analysis tool instead of re-deriving the
  same smells.
- **`/ie-init` opt-in for lenses + tool preference** — scaffolding now asks which
  lenses run and how the architecture lens should treat an installed tool.

### Changed
- All six architecture packs tuned from real-world read-only dogfoods.

See the [full changelog](https://github.com/davidteren/intent-engineering/blob/main/CHANGELOG.md)
for the complete history (0.1.0 → 0.5.0).
