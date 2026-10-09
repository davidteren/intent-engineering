# Changelog

All notable changes to **expectation-fit** (formerly intent-engineering). Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning is
[SemVer](https://semver.org/). For the current project state see **[STATUS.md](STATUS.md)**;
for the design see **PLAN.md**.

## [Unreleased]

## [0.9.0] - 2026-10-09

### Breaking
The plugin is renamed from intent-engineering to expectation-fit (#41). Old names map to
new names as follows:

| Before (intent-engineering 0.8.x) | Now (expectation-fit 0.9.0) |
|---|---|
| `/ie-review` | `/fit-review` |
| `/ie-audit` | `/fit-audit` |
| `/ie-validate-plan` | `/fit-validate-plan` |
| `/ie-plan-assist` | `/fit-plan-assist` |
| `/ie-from-pr-learnings` | `/fit-from-pr-learnings` |
| `/ie-init` | `/fit-setup` |
| `ie-<lens>-reviewer` agents | `fit-<lens>-reviewer` agents |
| `intent-engineering@intent-engineering-marketplace` | `expectation-fit@expectation-fit-marketplace` |
| `.intense/` config folder | `.expectation-fit/` (legacy `.intense/` still read through 0.9.x; removal planned for 1.0) |
| `INTENSE_CONFIG_DIR` | `EXPECTATION_FIT_CONFIG_DIR` (legacy variable still read through 0.9.x; removal planned for 1.0) |
| Reports in a tracked folder by default | Reports default to `.expectation-fit/reports/` (git-ignored) |

### Fixed
- **`fit-review` defines empty, plan-only and docs-only diffs (#59).** An empty diff
  dispatches no lens (even one set to `on`) and still writes the normal report with a
  "Nothing to review" line and the verdict Ready. `FILES` now comes from the head the
  lenses read, so remote scopes see the right change. A plan-only diff hands off to one
  `fit-validate-plan` run over all changed docs, which now accepts several paths as one
  set with one report and one flow per document. A docs-only diff keeps the same lens team and adds a claim-check
  line to the intent.
- **The `fit-review` fix step applies only gated fixes and checks for copies (#60).**
  Stage 5 step 7 and the subagent-template apply rules say that observations are never
  applied. The `fix(fit-review)` commit and the Applied section hold only fixes that
  passed the step 7 gate; callers commit other fixes separately. Before a fix that
  replaces text, the step searches for other copies and reclassifies the fix to manual
  when it cannot fix them all in the touched file. The shared rules tell lenses that a
  fix which prints or runs untrusted text must say how it makes that text safe. New
  refusal case in `evals.json`.
- **The merge stage lists every dropped finding and verifies before apply (#47).** Coverage
  has a Rejected list (title, file:line, lens, severity, confidence, `why`) in place of
  counts by anchor, and a Re-grades log for every orchestrator change to severity or
  confidence. Caller constraints limit what `fit-review` fixes, never what it reports
  (`accepted_by_caller`). Agreement between lenses no longer raises confidence, in the
  skill and the Grok workflow. Dedup merges findings on one defect within 3 lines even
  when titles differ, and keeps `gated_auto` only when every copy has it. Interactive
  `fit-review` re-reads each finding with a read-only sub-agent before it applies, and
  `evals.json` gains the refusal case.
- **Reports no longer look cleaner or more complete than the run was (#46).** The Lens
  status table in `references/report-template.md` gives each word one meaning and adds
  `ok` (ran, findings shown) next to `clean` (ran, no finding shown); `skipped` now means
  only "selected but could not analyze", and `not_selected` covers the rest. Both
  runtimes set `clean` or `ok` after the confidence gate. The all-clear line reads "No
  findings surfaced in this pass", the Header names every catalog lens with a reason,
  Coverage prints a READ line per lens and an optional Cost line, and a partial read
  blocks the all-clear line and Ready. `fit-review` hands the diff to lenses as
  `$RUN/diff.patch`. `check-contracts.rb` checks that every Grok status word has a row.
- **Lens runs without subagents or file writes have rules, and reports show how lenses ran (#43).**
  `references/subagent-template.md` now names the agent to dispatch per lens
  (`expectation-fit:fit-<lens>-reviewer`, or a general agent that reads the agent file),
  forbids one agent for two lenses, defines a compact reply, covers hosts that forbid
  file writes, and adds a single-agent fallback section that all three orchestrators use.
  Convention and architecture lenses open observations with `Config: <source>`. The
  report Header carries `Execution: subagents | single-agent`, and a lens whose returned
  `lens` differs from the dispatched one fails. New `lenses:<list>` token on `fit-review`,
  `fit-validate-plan` and `fit-audit`. `check-contracts.rb` ties the template's agent
  prefix to the plugin name in `plugin.json`.
- **Off-schema findings are repaired, not dropped, and mode:agent has a full example (#53).**
  The shared merge steps moved from `fit-review` Stage 5 into a new "Merge and gate"
  section of `references/report-template.md`, and all three orchestrators point there.
  Step 1 now repairs word severities, off-anchor confidences, unknown `fix_class` values
  and `file:line` values, and Coverage lists each repair and drop. The template and every
  lens agent list the allowed values. The `mode:agent` section has a complete example,
  field rules, and verdict words per context, and the reply stays raw JSON. `base:` now
  works with a PR target. The config docs state that nested maps merge at every depth.
  `check-contracts.rb` checks the allowed values, the example fields that `fit-review`
  Stage 6 names, and that no skill cites a `fit-review` Stage for a shared rule.

### Changed
- **Renamed to Expectation Fit (#41).** The plugin is now `expectation-fit` (marketplace
  `expectation-fit-marketplace`). Skills and agents use the `fit-` prefix: `fit-review`,
  `fit-audit`, `fit-validate-plan`, `fit-plan-assist`, `fit-from-pr-learnings`, and
  `fit-setup` (was `ie-init`). Project config moves to `.expectation-fit/`, and the env var to
  `EXPECTATION_FIT_CONFIG_DIR`. The old `.intense/` folder and `INTENSE_CONFIG_DIR` still
  work for at least one release; Coverage names the legacy folder and `/fit-setup upgrade`
  offers the move. The Grok runtime is now `.grok/workflows/fit-review.rhai`. Published
  reports from before the rename stay in `docs/intent-engineering/` as history.
- **Run scratch and reports stay out of git by default (#42).** The default report folder
  is now `.expectation-fit/reports/` (was `docs/expectation-fit/`). Each run folder and
  the default report folder get a one-line `*` `.gitignore`, so a run adds nothing to
  `git status`. To keep committing reports, set `artifacts.report_dir: docs/expectation-fit`.
  This repo's dogfood runs can pass `out:docs/intent-engineering/`. Other contract
  changes in `config-resolution.md`: relative `run_dir`, `report_dir` and `out:` resolve
  from the project base, and the `Report:` line prints an absolute path. `fit-review`
  and `fit-audit` load config before they build their file lists and exclude the run,
  report and `out:` folders by pathspec. `mode:agent` writes a report file only with
  `out:` (else `artifact_path` is `null`), and cleanup runs after the report step. The
  legacy single-bucket mode is gone: a top-level `report_dir` is now an alias for
  `artifacts.report_dir`, and `/fit-setup upgrade` carries it over. `/fit-setup`
  question 6 warns that reports under a published `docs/` site are public.
- **Reports name the plugin copy and the reviewed commit (#45).** Version is now 0.9.0 in
  `plugin.json` and `marketplace.json`, so installs leave the stale 0.8.0 cache; the
  plugin README has an Upgrade section. `report-template.md` defines one `Provenance:`
  line (plugin version and root, repo, branch, commit, dirty flag, run id) that every
  review, audit and plan report carries, plus matching `mode:agent` JSON keys. A
  published report is a point-in-time record: later status goes in a dated addendum,
  and Applied names the real fix SHA. `completed_at` carries a UTC offset. Lens prompts
  get the absolute plugin root through a `{plugin_root}` slot instead of a literal
  variable. Lenses take `line` from `grep -n` or a Read, and orchestrators check each
  line against its evidence quote before dedup (unverified lines go to Coverage).
  `fit-review` pins `REVIEWED_SHA` and `BASE_SHA` in Stage 1, diffs remote scopes
  against the pinned commit, treats the current branch as `local-aligned` when
  `origin/<branch>` is an ancestor of HEAD, and skips apply when HEAD moved.
  `fit-audit` shows commits ahead of the default branch; `fit-validate-plan` warns when
  the checkout is behind its upstream. The Grok workflow resolves one absolute plugin
  root (or pauses), and its report carries the Provenance and `Runtime:` lines.
- **Re-runs build on the last report (#52).** New shared token `prior:<report-path>`
  (review, audit, validate-plan): the prior report's `fixed` and `declined` rows reach
  every lens through one `<prior>` slot, and a Shared rule forbids re-raising them
  without new evidence. Findings tables gain a `Status` column (`open`, `fixed <sha>`,
  `declined: <reason or link>`), also as a JSON `status` field; interactive
  `fit-review` sets it at run time and never auto-applies a prior declined item. The
  review verdict now follows severity (Not ready with an open P0/P1, Ready with fixes
  with an open P2, else Ready; a failed lens still blocks Ready), and `fit-review` stops
  re-running at Ready. `base:<head_sha of the last report>` is documented as the delta
  re-review; a SHA that is not an ancestor of HEAD falls back to a full-branch review.
  The canonical path block takes the raw scope and applies one slug rule, and each
  `out:` row says to pass a folder. `fit-validate-plan` stamps `plan_sha256`, shows lens
  coverage in the verdict, and with `prior:` marks each prior gap closed or open, adds a
  Prior column and a `supersedes` line with the round. A Shared rule keeps decisions the
  document marks as settled closed.

### Fixed
- **Config settings no longer fail silently or vary by run (#49).** The defaults drop the
  dead `silent-failure` override example, and Coverage lists any unknown
  `severity_overrides` key as ignored (new `fit-review` eval case 5). Lens toggles are
  quoted, so YAML 1.1 loaders read strings, and `check-contracts.rb` fails on a bare
  `on`. The curated workflow gate rule is mechanical (whole-file body tokens, no
  `pull_request:` token, no "when unsure" rule). Auto discovery lists candidates with
  `git ls-files`, so agent worktrees are not read.
- **Every run shows config health and a next step (#54).** A defaults run ends its Config
  line with "Next: run /fit-setup to save repo rules once." (the Grok workflow adds the
  same observation). A legacy top-level `report_dir` names `/fit-setup upgrade`. Coverage
  lists the three per-file source lines. Only `config:` and the config env var change
  discovery. `/fit-setup` writes a project header instead of `(GLOBAL DEFAULTS)`, names
  the legacy folder on upgrade, and both `/fit-setup` and `/fit-from-pr-learnings` end
  with the git state of `.expectation-fit/`. Project notes are limits for every lens;
  only the convention lens reports a broken note. Both READMEs recommend `/fit-setup`
  once a repo is reviewed more than once.
- **Settled decisions and repo rules reach every lens (#55).** `tension` can name a
  principle against a settled decision (for example plan KTD-6). A tension finding stays in
  Findings, is listed in Tensions, and is never auto-applied. Every lens now gets repo
  `CLAUDE.md`/`AGENTS.md` paths and `conventions.notes`; `sources` and `auto` stay with the
  convention lens. This changes the #26 view that only the convention lens holds local
  authority. The lens template has an optional `<known-context>` block and a "Respect
  known context" rule; `fit-review plan:` quotes plan decision lines verbatim to every lens,
  and Coverage says `Plan: <path>` or `Plan: none`. New `fit-review` eval case 6.
- **Grok `fit-review` workflow reads the right code and cannot claim a false Ready
  (#44).** Prompts say agents have no shell and limit what they read. The script, not an
  agent, builds the diff: `base` must be a commit SHA, and a ref name, a missing base, or
  a non-path target with spaces pauses the run. `scope_mode` is set by the script. The
  target is a JSON-encoded label, and the config agent sees the changed files for the
  experience rule. The confidence gate runs before verify. Skeptics return `confirmed`,
  `not_real` or `unverifiable`; any unverifiable or failed verify sets Not ready. Confirmed
  findings keep the skeptic's reason and evidence, and `end_line` defaults to `line`. A
  lens that reports `failed:` gets status failed. The convention lens docs now match the
  lens catalog. Copy the file to `~/.grok/workflows/` after each pull.
- **Lens catalog lists full doc paths, and the contract check catches drift (#51).** The
  "Resource docs it reads" column names every doc as a full path under `resources/`
  (8 bare names fixed), and `check-contracts.rb` section 4 now fails on a doc that does
  not exist there. `AGENTS.md` forbids repo-only paths in shipped files, says a smell-card
  guard may qualify a finding but not suppress a whole class, and replaces the old local
  install path with a `claude -p ... --plugin-dir` dev loop. `README.md` installs from
  GitHub.
- **Repo upkeep: dogfood gaps become issues, and the site drops release facts (#61).**
  "Dogfood as you go" in `AGENTS.md` adds a contributor step to file each confirmed plugin
  gap as a public-safe issue. The PR template and `scripts/README.md` no longer send
  follow-ups to `wip/`. `docs/index.html` links to `/releases/latest` and `/releases`
  and names no current version or check count. The "New architecture stack" bullet names
  every place that lists the stacks.
- **`/fit-from-pr-learnings` reads `fit-review` declines and says when to run (#62).**
  Run it after the PR merges (a commit on an open PR branch restarts CI and review bots);
  one run can take several `pr:` tokens. In `pr:` mode it reads the newest `fit-review`
  report for the PR head branch in `artifacts.report_dir`. Only a decline whose reason
  holds beyond the PR becomes a `conventions.notes` line, citing the report path and
  finding number, and the Step 4 confirm still gates every note. The report Header names
  the report read. New eval case 4.
- **Lens judgment (#48).** The `gated_auto` rubric now excludes changes that outside
  callers can see (public classes, signatures, defaults, documented CLI flags), so
  `/fit-review` never applies them. A new eval case pins this. Lenses get `Repo root`,
  `Base` and `Plan` lines in scope, check the base before they blame the change, and put
  pre-existing and no-change items in observations. A failed or empty search is unknown:
  an unconfirmed absence claim caps at confidence 50 (template and Grok skeptic). The
  template has one shared severity rubric, and `findings-schema.json` points to it. The
  simplicity lens searches the requirements before a YAGNI cut.
- **Predictability escape classes (#58).** New smells for a comment, docstring or test
  name that claims code missing at HEAD (`least-astonishment.md`), a destructive step
  that runs before its last check (`error-handling.md`), and a config writer that
  coerces any input shape (`defaults-and-configuration.md`). The predictability lens now
  reads the "Surprising defaults" section of `defaults-and-configuration.md` (agent,
  lens catalog, Grok workflow and principle index).
- **Experience lens covers CLI, docs and developer output (#57).** `lens-catalog.md` is
  the one selection rule: it now lists CLI output, error and recovery messages, exit
  codes, the stdout/stderr split and changed README or upgrade steps, and a library or
  gem counts when it ships any of these. `fit-review`, `fit-audit`, `fit-validate-plan`,
  the Grok config prompt and `ways-of-working.yaml` point to it, and
  `check-contracts.rb` fails on a restated skip rule. `ux-interaction-smells.md` has a
  new "CLI and developer output" section (clig.dev added to Sources), a traced
  framework-default guard, and a tighter live-region shape. `accessibility.md` limits
  `role="tab"` to in-page panels.
- **Architecture lens policy and tool fixes (#50).** The `python` arch pack now needs a
  web or worker framework; a plain Python CLI or library returns `SKIPPED:` unless
  `lenses.architecture: on`. brakeman is no longer listed as an architecture tool, and
  `fit-setup` and the README no longer suggest `tools.architecture: prefer`. All six
  stack docs and `findings-schema.json` gain a `long-method` smell id (Rails gains a
  "General metrics" section). Under `enrich`, the lens runs a present tool, notes once
  per run which tools ran, and Coverage shows that note. "Pattern-bearing location" is
  defined once in `resources/patterns/README.md`, and the lens never reports a
  preferred or blocked rule as met (new `fit-audit` eval case 4). **Behavior change:**
  `approved` now silences blocked, instead_of and unidentified findings on its path,
  but smell findings still show and net-new blocked use still gets P1 (before, review
  and audit suppressed every architecture finding on an approved path). Each
  unidentified-pattern `suggested_fix` now holds a ready-to-paste `approved` entry.
- **Mechanical `fit-validate-plan` verdict (#56).** The verdict is Revise first when any
  P0 or P1 survives the gate or a selected lens failed; otherwise Ready to implement.
  A markdown reply ends with one `Verdict: … Lowest score: … Blocking: … Failed lenses:
  … Report: …` line (new eval case 4). Several documents run as separate flows (one
  lens dispatch and one report section each) inside one run and one report (#59). Plan lenses search the whole document before they call a rule missing,
  search call sites before they call code unused, and word a fix that rests on unseen
  framework behavior as a test. Caller checks go in a `Check | Result` table in
  Coverage. `findings-schema.json` gives plan meanings for P0 and P1. The skill
  description and the README place it after document review and before implementation.

### Added
- **Experience lens dogfood + fold-back** (issue #23). Ran the experience lens
  read-only on a real Hotwire/Rails app (ongela) and folded the false positives
  back into `resources/agnostic/ux-interaction-smells.md`: sibling-consistency
  and framework-default guards, a Hotwire caveat on the double-submit signal, a
  backdrop-click carve-out, a nested-attributes delete carve-out, and a
  three-tier error-path model. Report:
  `docs/intent-engineering/2026-08-14-experience-dogfood-ongela.md`.
- **Second experience-lens dogfood on a larger app** (fizzy, issue #23). Confirmed
  the ongela guards held and added six new smells plus a cross-surface guard:
  bodyless `head :4xx` dead-ends, live regions with no `aria-live`, accessible
  name/action mismatch, static-role-vs-conditional-behavior drift, autosave that
  cannot observe failure, implicit-submit-only controls, and a cross-surface /
  affordance confidence guard. Report:
  `docs/intent-engineering/2026-08-16-experience-dogfood-fizzy.md`.
- **Optional Grok `ie-review` workflow** (`.grok/workflows/ie-review.rhai`).
  Config-selected lenses, then one skeptic per finding, fail-closed. Report
  goes to run scratch. Does not replace the `/ie-review` skill or apply
  product-code fixes. First live run:
  `docs/intent-engineering/2026-08-12-workflow-ie-review.md`.

### Changed
- **GitHub Pages site refresh.** Light and dark themes, a finding (not a
  gradient hero) as the central visual, hashed CSS/JS, an Open Graph image,
  and HTML views of the published reports at `/reports.html`.
- **Experience lens: per-stack notes + template-diff auto-selection** (issue #38,
  follow-up to #23). Hotwire recognition notes name the concrete signals the dogfoods
  surfaced; the authoritative selection rule in `lens-catalog.md` now treats a surface as
  present whenever the diff touches a template/view/component/client-controller path for
  any architecture-supported stack, so a mixed backend+frontend change no longer skips
  experience review.
- README, plugin README, AGENTS.md, PLAN.md, and the GitHub Pages site
  (`docs/index.html`) now describe the optional Grok `ie-review` runtime.
- Grok `ie-review` after that dogfood pass: one `complete()` shape, severity-ordered
  verify cap, file+line dedup, reject list, in-script confidence gate, unique
  default report path.
- Grok `ie-review` remaining report items: config agent, template-shaped lens
  prompts, normalized dedup plus agreement bump, schema enums, skipped/clean/failed
  statuses, read-only merge, Layer A lens JSON in scratch. No write-capable
  publisher. Script owns the verdict.

## [0.8.0] — 2026-07-30

Setup that matches real workspaces: multi-repo init, CI-aware conventions, preferred
patterns, and a path from PR review into `.intense/`.

### Added
- **`/ie-init` setup/upgrade wizard.** Modes **fresh** | **upgrade** (calibrate remains
  from 0.7.0, now part of the same entry point). Profiles **monolith** | **multi-repo**
  (detect siblings + confirm; tokens `multi-repo`, `roots:a,b`). Fresh covers workspace
  placement, `conventions.auto` (+ `roots`), `severity_align`, optional interactor
  preference (preferred-only, not double-blocked), multi-stack thresholds, and a
  capability preview before write. Upgrade diffs missing capabilities vs plugin defaults
  and merges keys only (never wipes `notes`). Evals expanded (ids 4–6).
- **`/ie-from-pr-learnings`.** Mine PR triage docs or `pr:` URLs into
  `conventions.notes` / `sources`, `severity_overrides`, and optional pattern policy.
  Workspace-aware; never clobbers or pushes.
- **`conventions.auto`** (defaults + config-resolution). Discover Copilot packs,
  path-scoped `.github/instructions/**` (`applyTo`), and curated PR-gate workflows
  under optional multi-repo `roots`. Generic workflow `exclude` defaults only.
- **`severity_align`** (defaults + synthesis order). Promote severity when a discovered
  gate matches a theme under **smell-first** rules (non-empty smells require smell match).
  Built-in lint/test/security rows are **Coverage note only** (no mass-promote). Rank is
  `P0 > P1 > P2 > P3` via `more_severe` (never string max). Explicit `severity_overrides`
  still win last.
- **`patterns.preferred`**. Directional "use A instead of B" for new work
  (`instead_of`); architecture lens enforces with blocked/approved.

### Changed
- Convention and architecture agents honor auto sources, preferred policy, and
  authority order from `config-resolution.md` (pattern policy wins over CLAUDE text).
- Explicit `config:` / `INTENSE_CONFIG_DIR` that lack yaml never claim `project:`
  while using defaults.
- Orchestrators (`ie-review`, `ie-audit`) document severity_align after lens merge.
- Landing site, READMEs, and STATUS describe six skills and the wizard first-run.
- Contract suite **141** checks (was 138) across 12 sections.

## [0.7.0] — 2026-07-29

Hardening + discoverability: config walk-up, skill evals, experience greppable smells,
threshold calibrate, and apply-safety contracts. Landing site and docs brought in line
with current release numbers and contract counts.

### Fixed
- **Config walk-up (#25).** Project `.intense/` is discovered by walking up from cwd
  (nearest wins; depth cap 32; checks `/`); not only `./.intense`. Escape hatches:
  `config:<path>` and `INTENSE_CONFIG_DIR`. Coverage must always state the Config source
  (search range: cwd → filesystem root). `config:` path detection includes
  `patterns.yaml`.
- **Catalog-only stack selection.** Skills/init no longer hardcode Rails+Python;
  architecture selection reads only `stack-catalog.md` Arch pack ✅/⬜.
- **Auto-apply safety.** Shared `fix_class` / `gated_auto` rubric; interactive review
  applies only gated_auto + confidence ≥ 75 + severity ≤ P2; Stage 1 captures
  `TREE_CLEAN`.
- **Lens status honesty.** failed / skipped / clean; architecture pack-miss uses
  `SKIPPED:`; no all-clear when a selected lens failed.
- **Polymorphic `severity_overrides`.** String or `{ severity, because }` map; `because`
  surfaces in Coverage/Observations.

### Added
- **Skill evals (#28).** `evals.json` next to each skill (happy-path + refusal cases).
  Contract section 12 parses them (missing = warning; bad shape = hard fail).
- **Experience greppable smells (#23 core).** `resources/agnostic/ux-interaction-smells.md`
  + experience agent / lens-catalog / principle-index. (Real UI dogfood still open on #23.)
- **`ie-init calibrate` (#27).** Measure repo metric distributions; propose thresholds at
  a target percentile (default p90) with evidence comments.
- **`conventions.sources` + CI delta (#26).** Path globs for high-authority convention
  docs; audit reports CI↔config drift checklist.
- **Ruby/Rails comment bar.** YARD for API docs; succinct; only under valid conditions.

### Changed
- **Single-sourced orchestration paths.** Skills bind slots only; canonical bash in
  `config-resolution.md` (`CANONICAL_ORCHESTRATOR_PATHS`).
- **Score keys** on every lens agent Output (audit/plan).
- **Contract check** sections 11–12 (skill↔catalog drift; skill evals + walk-up/sources).
  Suite is **138 checks** across 12 sections.
- **Authority order** documented in config-resolution (`.intense` > CLAUDE/AGENTS/sources
  > sibling code > plugin defaults).

## [0.6.0] — 2026-07-19

Portable report layout: drop `wip/` as the plugin default so installs work in repos that
never used that convention.

### Changed
- **Two-layer artifacts.** Run scratch (per-lens JSON) defaults to
  `.intense/runs/<run-id>/`; the published human report defaults to
  `docs/intent-engineering/<stamp>-<skill>[-scope].md` (`.json` in `mode:agent`).
  After a successful publish, run scratch is deleted (`artifacts.cleanup_runs: true`).
- **Config:** `ways-of-working.yaml` now has `artifacts.run_dir`, `artifacts.report_dir`,
  and `artifacts.cleanup_runs` instead of a single `report_dir` pointing at `wip/`.
- **Legacy:** a top-level `report_dir:` **without** an `artifacts:` block still means
  single-bucket mode under that path with cleanup off (existing project configs keep
  working).
- **`/ie-init`** offers to append `.intense/runs/` to `.gitignore` and documents the
  new report defaults.
- Orchestrators (`ie-audit`, `ie-review`, `ie-validate-plan`), `config-resolution.md`,
  `report-template.md`, and `subagent-template.md` bind `run_artifact_dir` to Layer A
  (`$RUN`) only; `out:<path>` overrides the **published** path.

### Removed
- **`wip/intent-engineering` as the default report home.** Optional personal `wip/`
  scratch is unrelated to the plugin default.

## [0.5.0] — 2026-06-19

Hardening release: all six architecture packs (Rails, Python, Laravel, Express, Phoenix,
React) **dogfooded read-only on real production apps** and tuned from the findings, plus a new
**external-tool-deferral config** so a team already running reek/eslint/phpstan/… isn't given
duplicate findings. No new stacks — this release makes the existing six trustworthy on real
codebases.

### Added
- **External-tool preference / anti-duplication config** (`tools.architecture` in
  `ways-of-working.yaml`): `enrich` (default — heuristics + tool as corroboration), `prefer`
  (run the tool, map its findings to the schema, suppress overlapping heuristics — no
  duplication), `report` (tool findings only), `off` (ignore tools). For a team that already
  runs reek/rubocop/ruff/phpstan/eslint/credo, the architecture lens defers to it instead of
  re-deriving the same smells. Honored by `ie-architecture-reviewer`; documented in
  `config-resolution.md`; wired through `ie-review`/`ie-audit`.
- **`/ie-init` opt-in for lenses + tool preference** — when scaffolding `ways-of-working.yaml`
  interactively, `ie-init` now asks which lenses run (turn any agent off) and how the
  architecture lens should treat an installed static-analysis tool, writing the answers into
  `.intense/`. (Lens on/off/auto toggles already existed in the config; this surfaces them at
  init and adds the tool preference.)

### Changed
- **Rails pack tuned from a real-world dogfood** (read-only run on a mature OSS Rails 8 app,
  ~1244 app files, concern-heavy, 99 service objects) — the original stack, validated on a
  real app for the first time. The prose judgment matched reality (fat-controller,
  misused-service multi-method, job, serializer, policy all reported **clean**) and found real
  fat-models + queries-in-views, but the *measurement instructions* were calibrated for small
  un-decomposed apps. Folded back:
  - **Concern-tree resolution for `fat-model`** (highest value) — follow `include Model::Topic`
    to `app/models/concerns/model/topic.rb` and sum LOC/associations/callbacks/methods across
    the tree; a grep of the model *file* returned `associations=0` on a 1685-LOC god model.
  - **`rails.service_object.max_loc` 120 → 250, LOC demoted to P3** — method count is the real
    axis; a long single-`call` service decomposed into inner strategy/builder classes is
    healthy, not a God service.
  - **Public-action vs raw-`def` counting** for `fat-controller` (count public actions above
    the first `private`/`protected`, minus callbacks — a raw `def` count flagged thin
    controllers), `app/models/form/**` added to the `form_object` pattern path, and a concrete
    heuristic god-object fan-out grep recipe for the reek-less default path.
- **Phoenix pack tuned from a real-world dogfood** (read-only run on a mature OSS Phoenix app,
  ~476 lib files). The prose discipline held — `business-logic-in-changeset`, `law-of-demeter`,
  and `process-misuse` all reported **clean with zero false positives**, and it found real
  `context-bypass` in controllers/LiveViews — but three signal-level detectors would have
  spammed false P2s on idiomatic Phoenix unattended. Folded back:
  - **Precise `context-bypass` matching** — grep the Ecto macro as `from(<binding> in <Schema>)`,
    NOT a bare `from(`, because a context query-builder is often a *function literally named
    `from`* (`Stats.Query.from(site, params)`); the bare grep produced ~37 false hits.
  - **Tiered `Repo.` bypass** — query-building/writes in the web layer = P2; a lone
    `Repo.preload`/`Repo.reload` on a context-provided struct = P3.
  - **`phoenix.controller.max_actions` 12 → 15** + an API/RPC-controller caveat (dashboard
    controllers have many thin RPC actions); **`phoenix.live_view.max_loc` 200 → 400** (colocated
    `~H`/`attr` function-component markup inflates LOC; judge handler/domain LOC, not markup).
  - Notes: Oban worker / mix-task data-access is a milder P3 placement nudge (not the web-layer
    P2 bypass); count `with` legs as flat, not nested.
- **Express pack tuned from a real-world dogfood** (read-only run on a mature OSS Express
  forum — CommonJS, ~611 src files, hand-rolled DB, `api/`-as-service layer). The smell
  *definitions* and severities held, but the **recognition mechanics were tuned for ESM + ORM
  + `services/` + named-lib conventions** and misfired on a real CommonJS app — producing both
  false negatives (god-modules invisible to the export counter) and false positives (every
  async handler + thin write controller flagged). Folded back:
  - **CommonJS-aware export counting** — the public surface is every `module.exports.x =` /
    `Obj.x =` assignment, including the mixin form `module.exports = function (Obj) { Obj.a = … }`;
    a naive `grep export` returns 0 for a 600-line/30-fn module.
  - **`api/`-named service recognition** — the service layer is often named for the transport it
    fronts (`api/`) with a `(caller, data)` signature, not `services/` + `*Service`; without
    this, thin REST controllers calling `api/` got false-flagged as layer-leaks.
  - **Project-local async-wrapper carve-out** — look for a repo's own handler-wrapping helper
    (try/catch→`next(err)`) before declaring an `async-error-gap`; many apps roll their own
    instead of `express-async-errors`.
  - **Tightened `layer-leak` grep** — key on `res.json`/`res.status`/`require('express')`, not a
    bare `req`/`res`; a passed-in `data.req`/`caller` for `.uid`/`.ip` is data, not coupling.
  - **`express.middleware.max_loc` 40 → 100** (real cross-cutting auth/render middleware runs
    long; lean on the behavioral signal) + a render-controller vs REST-controller severity note
    + hook-bus (`hooks.fire`) recognition in `event_subscriber`.
- **Laravel pack tuned from a real-world dogfood** (read-only run on a mature open-source
  Laravel 12 app with a non-default *domain-organized* layout). The pack's prose held
  (confirm-don't-count prevented every false positive; the app came back structurally clean),
  but the structured signals were calibrated for vanilla Laravel. Folded back:
  - **Layout-agnostic recognition** — added `app/**/{Controllers,Services,Requests,Resources,Jobs,Events,Listeners,Policies,Middleware,Repositories,Repos}/**`
    fallback path globs to every pattern (only `eloquent_model` had one), so domain-organized
    apps classify on path as well as base-class/suffix.
  - **Two new catalog patterns** (`query_object`, `notification`) and a broadened `action`
    pattern that also recognises hand-rolled domain-operation objects (`Tools/`/`Operations/`,
    `run()`/`handle()`) — these were `(unmatched)` on the dogfood. `laravel.yaml` 13 → 15.
  - **Threshold + caveats** — `laravel.controller.max_actions` 10 → 15 (GET form-render twins
    legitimately double the count); doc caveats that a bare `::all()`/`::where(` Blade grep
    over-triggers on enums/static helpers, and that the Law-of-Demeter grep is low-signal
    (manual spot-check, not a count).
- **React pack tuned from a real-world dogfood** (read-only run on a large production React 18
  + Next + MobX app, ~429 components). The React-core heuristics held (real god-components and
  a derived-state-in-effect found); two gaps were folded back:
  - **MobX awareness** — `state_store` and `higher_order_component` now recognise MobX
    (`makeAutoObservable`/`@observable`/`@action`/`mobx-react`, `observer()`); a `react.store.*`
    threshold block (`max_loc` 800, `max_observables` 15, `max_actions` 25) gives stores a
    looser, responsibility-based budget, and `god-module` now names the **god store**. The
    dogfood's worst finding — a 4117-LOC MobX god-store — previously only matched a weak path
    signal.
  - **Framework-idiom carve-outs** — `observer()`/`connect()` wrapping is flagged as idiomatic
    (not "wrapper hell"); Next.js `page`/`layout`/`getServerSideProps` and route-manifest tables
    are named as expected-long, not god components/modules.

## [0.4.0] — 2026-06-15

Third feature release: four new architecture stacks — **Laravel, Express/Node, Phoenix/Elixir,
and React** — each authored research-first and added purely through the v0.3.0 stack registry
(data + a catalog row, no lens/skill code changes). The architecture lens now covers **six
stacks**. (Python is FastAPI-first.)

### Added
- **React architecture stack** — fourth registry-only stack addition:
  - `resources/frameworks/react-architecture.md` — 8 structural smells (`god-component`,
    `logic-in-component`, `fat-hook`, `prop-drilling`, `effect-overuse`, `god-context`,
    `god-module`, `law-of-demeter`) + general metrics; optional eslint/madge enrichment.
  - `resources/patterns/react.yaml` — 11-pattern catalog (function_component, custom_hook,
    context_provider, reducer, data_fetching_hook, state_store, higher_order_component,
    render_prop, error_boundary, memoized_component, compound_component).
  - `config/defaults/thresholds.yaml` — a `react.*` threshold namespace; registered in
    `stack-catalog.md` (Arch pack ✅, flipped from convention-only) + `principle-index.md`.
    Detected from `package.json` (`react`) + `.jsx`/`.tsx`. Research-backed (React docs "You
    Might Not Need an Effect" / custom hooks / context, patterns.dev, Martin Fowler). The arch
    pack complements the existing react convention doc + the experience lens. Dogfood pending.
- **Phoenix / Elixir architecture stack** — third registry-only stack addition:
  - `resources/frameworks/phoenix-architecture.md` — 8 structural smells (`fat-controller`,
    `context-bypass`, `god-context`, `fat-liveview`, `business-logic-in-changeset`,
    `god-module`, `process-misuse`, `law-of-demeter`) + general metrics; optional credo/boundary
    enrichment.
  - `resources/patterns/phoenix.yaml` — 11-pattern catalog (context, phoenix_controller,
    ecto_schema, ecto_changeset, live_view, function_component, genserver, supervisor, plug,
    router, oban_worker).
  - `resources/frameworks/phoenix.md` — Elixir/Phoenix convention doc (contexts as the seam,
    Ecto cast/validate scope, OTP-models-runtime-not-code-organization, `{:ok,_}|{:error,_}`,
    least-astonishment traps).
  - `config/defaults/thresholds.yaml` — a `phoenix.*` threshold namespace; registered in
    `stack-catalog.md` (Arch pack ✅) + `principle-index.md`. Detected from `mix.exs`
    (`:phoenix`) + `lib/<app>_web/`. Research-backed (Phoenix Contexts guide, Elixir
    process/design anti-patterns, Ecto docs). Covers structural/layering + OTP *placement*;
    deep supervision-tree correctness is out of scope by design. Dogfood on a real repo pending.
- **Express / Node architecture stack** — second registry-only stack addition:
  - `resources/frameworks/express-architecture.md` — 8 structural smells (`fat-route-handler`,
    `god-module`, `god-object`, `misused-service`, `layer-leak`, `fat-middleware`,
    `async-error-gap`, `law-of-demeter`) + general metrics; optional eslint/madge enrichment.
  - `resources/patterns/express.yaml` — 12-pattern catalog (router, controller, middleware,
    service, repository, model, error_handler, validator, config, app_factory,
    background_worker, event_subscriber).
  - `resources/frameworks/express.md` — Node/Express convention doc (3-layer architecture,
    async error handling, config-from-env, app/server separation, least-astonishment traps).
  - `config/defaults/thresholds.yaml` — an `express.*` threshold namespace; registered in
    `stack-catalog.md` (Arch pack ✅) + `principle-index.md`. Detected from `package.json`
    (`express`) + `app.js`/`routes/`. Research-backed (bulletproof-nodejs 3-layer,
    goldbergyoni nodebestpractices, Express docs, 12-factor). Dogfood on a real repo pending.
- **Laravel (PHP) architecture stack** — the first stack added *through the registry* (data
  only, no skill edits), proving the extension point:
  - `resources/frameworks/laravel-architecture.md` — 8 structural smells (`fat-controller`,
    `fat-model`, `god-class`, `misused-service`, `query-in-view` (N+1), `logic-in-routes`,
    `fat-job`, `law-of-demeter`) + general metrics; optional phpstan/larastan/phpmd/phpinsights
    enrichment.
  - `resources/patterns/laravel.yaml` — 14-pattern catalog (eloquent_model, controller,
    form_request, action, service, api_resource, job, event_listener, policy, middleware,
    repository, service_provider, data_object).
  - `resources/frameworks/laravel.md` — Laravel/PHP convention doc (naming table, Eloquent/
    FormRequest/eager-loading idioms, `env()`-vs-`config()` and model-event traps).
  - `config/defaults/thresholds.yaml` — a `laravel.*` threshold namespace.
  - Registered in `stack-catalog.md` (Arch pack ✅) + `principle-index.md`; detected from
    `composer.json`/`artisan`/`app/`+`routes/`. Research-backed (alexeymezenin best-practices,
    Laravel docs, lorisleiva/laravel-actions, PSR-12). 75 → 83 contract checks, green.
  - **Dogfood pending** — no Laravel repo available locally; to be run on a real app.

## [0.3.0] — 2026-06-15

Second feature release: the architecture lens gains a **Python (FastAPI-first)** stack and
a **stack registry** that makes every future language/framework a data-only addition.

### Added
- **Python architecture stack** for the 5th (architecture) lens — it now supports Rails
  **and** Python (FastAPI-first, but the smells apply to any layered Python service):
  - `resources/frameworks/python-architecture.md` — 8 structural smells (`fat-router`,
    `god-module`, `god-object`, `misused-service`, `business-logic-in-schema`,
    `fat-dependency`, `layer-leak`, `law-of-demeter`) + general metrics, with optional
    `ruff`/`radon`/`vulture`/`import-linter` enrichment.
  - `resources/patterns/python.yaml` — 13-pattern catalog (router, dependency,
    pydantic_schema, settings, service, repository, background_task, app_factory,
    exception_handler, middleware, adapter_client, document_renderer, dataclass_value).
  - `config/defaults/thresholds.yaml` — a `python.*` threshold namespace.
- Stack detection for Python (`pyproject.toml`/`setup.py`/`setup.cfg` + `.py` sources)
  wired into `/ie-review`, `/ie-audit`, `/ie-init`, the architecture agent, and the lens
  catalog.
- **Stack registry** (`references/stack-catalog.md`) — one source of truth for every known
  stack: detection signals, the packs it loads (convention doc, architecture doc, pattern
  catalog, threshold namespace), and whether the architecture lens supports it. The lens,
  the skills, and `ie-init` read the registry instead of hardcoding detection, so adding a
  stack is data + one catalog row rather than edits across five files. This is the
  extension point for the queued stacks (PHP/Laravel, Elixir/Phoenix, Express/Node, React).
- **Stack-aware `/ie-init`** — scaffolds only the *detected* stack's `thresholds.yaml`
  namespace (not the whole multi-stack file) and seeds `patterns.yaml` policy from that
  stack's catalog, driven by the registry. Convention-only / unknown stacks get the
  stack-agnostic `ways-of-working.yaml` with a note.

### Changed
- `ie-architecture-reviewer` frontmatter description + intro made **stack-neutral** (point at
  the registry instead of enumerating stacks), so the agent prompt no longer needs a per-stack
  edit and can't drift stale as stacks are added.
- `scripts/check-contracts.rb` section 8 (cross-references) generalized from Rails-only to
  **every stack** with a `<stack>.*` threshold namespace: each must have a
  `<stack>-architecture.md`, all metrics it cites must be defined, and pattern-policy ids
  resolve against the union of all catalogs. New section 10 enforces stack-registry
  consistency (✅ rows ↔ files ↔ threshold namespaces). 67 → 75 checks, green.

### Notes
- Dogfooded the Python pack read-only against a real-world FastAPI service. Verdict
  healthy with near-zero false positives; the run caught two pack bugs (a bare-`Request`/
  `Response` grep that collided with Pydantic model names; a missing renderer pattern for
  openpyxl/pandas-heavy modules) and a placement smell — all fixed in the docs/catalog
  before release.

## [0.2.0] — 2026-06-14

First public release. The feature-complete build landed 2026-06-03; it was published on
2026-06-14 with the hardening, documentation, and CI below. (Git history was reset to a
single commit at publish time.)

### Added
- **Five review lenses** — predictability, convention, simplicity, experience (the four
  universal lenses) and architecture (5th, framework-specific, Rails-only, code/audit).
- **Five skills** — `/ie-init`, `/ie-plan-assist`, `/ie-validate-plan`, `/ie-review`,
  `/ie-audit`.
- **Shared contract layer** (`references/`) — findings schema, subagent template, lens
  catalog, scoring rubric, report template, principle index, config resolution.
- **Researched knowledge base** (`resources/`) — 9 principle docs, 7 framework docs
  (incl. `rails-architecture`), 6 agnostic docs, each with violation-smell checklists and
  cited sources.
- **`.intense` project config** — lens toggles, pattern policy, architecture thresholds;
  project overrides plugin defaults.
- **Rails architecture audit** + a **14-pattern catalog** (heuristic-first; optional
  reek/flog/brakeman enrichment); the `/ie-init` scaffolder.
- **Packaging** — `plugin.json`, `marketplace.json`; `resources/` bundled inside the plugin
  for install self-containment.
- **Docs** — `AGENTS.md` (contributor guide), `CLAUDE.md`, expanded `README.md`
  (source-principles table + full overview), `STATUS.md` (current state), this
  `CHANGELOG.md`, and `LICENSE` (MIT).
- **`scripts/check-contracts.rb`** — automated contract-integrity check (67 checks across 9
  sections: JSON/YAML parse, lens-identity 4-way agreement, agent frontmatter,
  `${CLAUDE_PLUGIN_ROOT}` path resolution, pattern-catalog schema, emitted `principle:` ids,
  git-tracked agents, threshold ↔ doc and policy ↔ catalog cross-references, and resource-doc
  structure & citations).
- **CI** — `.github/workflows/contracts.yml` runs the check on every PR and on pushes to `main`.

### Changed (hardening, after the feature-complete build)
- **Per-lens model directive** in `subagent-template.md` + `ie-audit` + `ie-validate-plan`:
  predictability/simplicity inherit the session model; convention/experience/architecture
  use `sonnet` (fixes a default that silently downgraded the always-on lenses).
- `report-template.md` specifies an **all-clear empty state**; `report.json` named
  consistently for `mode:agent` across the template and all three orchestrators.
- Plugin README **"five contexts" → four**; `plan:` token added to the `ie-review`
  argument-hint; `ie-review`/`ie-audit` frontmatter reworded to the five-lens framing.
- `patterns.*` lists documented as replace-only; `scores` key authority noted in the schema;
  `rails.general.max_method_loc` wired into `rails-architecture.md`.
- `.idea/` added to the repo `.gitignore`; the repo `agents/` negation reframed as defensive
  portability after the global `agents/` ignore was removed; legacy `.wip/`, empty `docs/`,
  and `.DS_Store` cruft removed.

### Fixed
- **The `agents/` gitignore trap.** A global gitignore ignored `agents/`, so all five lens
  agents were never committed — an installed plugin would have had **zero agents**. The repo
  `.gitignore` re-includes `plugins/intent-engineering/agents/`. **Keep that negation on any
  clone/fork.** Found by the dogfood loop, not by luck.
- Self-audit findings: lens-count drift in `ie-review`/`ie-audit` frontmatter (said "four",
  run up to five); a bare `subagent-template.md` citation in the predictability lens; unbound
  `OUT_ARG`/`REPORT_DIR` in the orchestrators' dispatch bash; a stale "TBD — default
  report-only" fix-policy note in `PLAN.md`.

### Decisions
- **Four consolidated universal lenses** (predictability / convention / simplicity /
  experience); principle docs stay 1:1. Architecture is a distinct **5th lens**,
  framework-specific and code/audit-only.
- Framework seeds: Rails/Ruby, React/TypeScript, Python, Swift/iOS.
- `ie-review` applies safe verified fixes (mirrors `ce-code-review`; never pushes).
- Research via parallel sub-agents, one per doc, write-as-you-go.
- Renamed **intuitive-engineering → intent-engineering**; `ie-` prefix kept; project config
  dir `.intense/`.
- Architecture metrics heuristic-first (optionally enriched by reek/flog/brakeman); pattern
  recognition by naming/dir/base-class/gem heuristics (AST later); config merge =
  project-over-global, lists replace unless `extends: true`.

[0.2.0]: https://github.com/davidteren/intent-engineering/releases/tag/v0.2.0
[0.7.0]: https://github.com/davidteren/intent-engineering/releases/tag/v0.7.0
[0.8.0]: https://github.com/davidteren/intent-engineering/releases/tag/v0.8.0
