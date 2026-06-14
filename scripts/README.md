# scripts/

Repository tooling. **Not shipped inside the plugin** — the installable plugin lives under
`plugins/intent-engineering/`, and per the self-containment rule (see `AGENTS.md`) only what
a user installs belongs there. These scripts are for contributors and CI.

## `check-contracts.rb`

The plugin's one automated check. It asserts the cross-file invariants that a single edit
can silently break — the things that would otherwise only surface as a broken install.

```sh
ruby scripts/check-contracts.rb
```

Exit `0` = all good; exit `1` = at least one failure. Output is one line per check
(`ok` / `FAIL` / `warn`) under nine sections, then a summary
(`PASS — 67 checks, 0 failures`). Run it before committing; CI runs it on every PR.

### What it checks

| # | Section | Asserts |
|---|---------|---------|
| 1 | Parse | every shipped `*.json` and `*.yaml` parses |
| 2 | Lens identity (4-way) | the 5 lens ids agree across `findings-schema.json` enum, `agents/ie-*-reviewer.md` basenames, `lens-catalog.md` rows, and `scoring-rubric.md` rows |
| 3 | Agent frontmatter | each agent's `name` == filename stem, is in the lens enum, and has `tools` + `model` |
| 4 | Path resolution | every `${CLAUDE_PLUGIN_ROOT}/…` path (and backticked index/catalog paths) resolves on disk; placeholders skipped |
| 5 | Pattern catalog schema | each catalog entry has `id/name/intent/recognition/good_use/misuse`; ids unique + snake_case |
| 6 | Principle ids | every `principle:` value the lenses declare they emit is in the schema enum |
| 7 | Gitignore trap | exactly **5** lens agents are git-tracked (`git ls-files plugins/intent-engineering/agents/`) |
| 8 | Cross-references | every threshold metric cited in `rails-architecture.md` is defined in `thresholds.yaml`; every pattern id in policy/README exists in the catalog; unreferenced metrics → **warning** |
| 9 | Resource-doc structure | each principle/framework/agnostic doc has a detection ("smells") section + a `## Sources` section with ≥2 links; every resource doc is cited in `principle-index.md`/`lens-catalog.md` (no orphans) |

**Severity model:** a hard `FAIL` makes the script exit non-zero (and fails CI). A `warn`
(currently: a threshold defined but never referenced) is surfaced but does **not** fail the
run — an unused-but-defined value is spare capacity, not a broken contract.

It does **not** check code behavior or lens output quality — only that the plugin's own
contracts (schema, names, paths, catalog, docs) stay mutually consistent. It is the plugin
keeping its own promises.

### Why Ruby (and not Bash or Python)

The checks parse both **JSON and YAML**. Ruby does both from its **standard library** — no
gems, no bundler. The alternatives are less portable here:

| Need | Bash | Python | **Ruby** |
|------|------|--------|----------|
| JSON | `jq` (extra tool) | stdlib | **stdlib** |
| YAML | **`yq`** — extra tool, and two incompatible tools share the name | **PyYAML** — not stdlib | **stdlib** |

Ruby also ships on macOS and fits a Rails-oriented plugin (the architecture lens already
assumes a Ruby ecosystem). A Bash port would add fragile dependencies and reduce the
YAML-structural checks to brittle grep — so this stays Ruby on purpose.

### Requirements & portability

- **Ruby ≥ 2.0**, standard library only (`json`, `yaml`, `shellwords`). No gems, no Bundler.
- Verified on stock macOS system Ruby (2.6.10) and current Ruby (3.x). CI pins Ruby 3.3.
- Runs from anywhere — paths resolve relative to the script location.

### CI

`.github/workflows/contracts.yml` runs this on every pull request and on pushes to `main`
(job: `contract-integrity check`), which is the required status check for merging.

### Adding a check

Append a new `section("N. …")` block and call `ok(msg)` / `bad(msg)` (hard) or `note(msg)`
(warning). Keep checks **deterministic and structural** — no flaky heuristics; a check that
can false-positive is worse than no check. Natural future additions are noted in
`wip/improvements.md`.
