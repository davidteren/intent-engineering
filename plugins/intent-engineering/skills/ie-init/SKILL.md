---
name: ie-init
description: "Setup and upgrade Intent Engineering project config in .intense/ — full wizard for greenfield monoliths and multi-repo workspaces (placement, conventions.auto roots, severity_align, pattern preference), plus upgrade that merges missing capabilities without clobbering notes. Optional calibrate measures repo distributions and proposes thresholds. Stack-aware; idempotent. Use to set up, extend, or upgrade a project's .intense/ config."
argument-hint: "[all | ways | patterns | thresholds | fresh | upgrade | multi-repo | roots:a,b | calibrate [p90|p75|…]] (blank = wizard)"
---

# Intent Engineering — Init / setup / upgrade

Scaffolds and upgrades project config under `.intense/` so a team can declare ways of
working (lens toggles, conventions, auto sources, severity align), design-pattern
policy (preferred / allow / block / approved), and architecture thresholds — then
commit them. Once present, `.intense/` supersedes the plugin defaults
(`config-resolution.md`) for every `ie-*` run in that tree (via walk-up).

**Modes** (auto-detected when `$ARGUMENTS` is blank; overridable by token):

| Mode | When | What it does |
|------|------|--------------|
| **fresh** | no project `.intense/` yet (or user said `fresh` / `all` / file tokens) | Full setup wizard → write files |
| **upgrade** | `.intense/` exists (or user said `upgrade`) | Diff capabilities vs defaults; merge only missing keys with confirm |
| **calibrate** | user said `calibrate` [percentile] | Measure distributions; propose thresholds with evidence |

Also supports legacy file tokens: `all`, `ways`, `patterns`, `thresholds` (skip profile
questions when non-interactive; still run stack-aware copy rules).

## Interactive tool

If presenting menus interactively in Claude Code, **pre-load `AskUserQuestion`**
(deferred tool): call `ToolSearch` with `select:AskUserQuestion` once before the first
menu. If the harness has no blocking-question tool (ToolSearch returns nothing / call
fails), fall back to a numbered list and wait for the user's reply — never silently pick.

---

## Procedure

### 0. Resolve mode + detect layout (always)

#### 0a. Mode

1. If `$ARGUMENTS` starts with `calibrate` → **calibrate** (optional `p90` / `p75` / `p95`;
   default **p90**). Jump to Step 2c.
2. Else if `$ARGUMENTS` contains `upgrade` → **upgrade**. Jump to Step U after a light
   detect pass (0b–0c still run so the report names stacks/roots).
3. Else if `$ARGUMENTS` is `fresh` or a file token (`all` / `ways` / `patterns` /
   `thresholds`) → **fresh** with that selection.
4. Else (blank): discover nearest `.intense/` via walk-up
   (`${CLAUDE_PLUGIN_ROOT}/references/config-resolution.md`).
   - Found → recommend **upgrade**; still offer fresh re-scaffold (overwrite only with
     confirm). Present: `1) upgrade  2) fresh (re-scaffold)  3) calibrate`.
   - Not found → **fresh**.

#### 0b. Profile: monolith vs multi-repo

From the **intended project base** (cwd's git root, or a parent workspace if cwd is a
child app):

**Multi-repo signals** (any two → default profile **multi-repo**):

- Two or more immediate child dirs each with their own `.git`, or with `AGENTS.md` /
  `CLAUDE.md` / `Gemfile` / `package.json` / `pyproject.toml`.
- Child names look like product halves (`*_be`, `*_fe`, `backend`, `frontend`, `api`,
  `web`, `mobile`, `e2e`).
- Cwd is inside a child app but the parent has multiple app-like siblings.

Otherwise default **monolith**.

Always **confirm** with the user (AskUserQuestion): monolith vs multi-repo stack.
Recommend the detected default.

#### 0c. Stack detection

- **Read `${CLAUDE_PLUGIN_ROOT}/references/stack-catalog.md`** — the registry is the
  source of truth for detection and which pack a stack carries. Match the tree against
  `Detection signals`. Do not hardcode detection here.
- For multi-repo: detect **per root** under the project base (and under each
  `conventions.auto.roots` candidate). Collect the set of stacks (e.g. rails + react).
- Note each stack's **Arch pack** status and **Threshold ns** from the catalog **column
  only** (never a hardcoded "today" list):
  - **Arch pack ✅** — scaffold that stack's threshold namespace + pattern ids.
  - **Arch pack ⬜** — convention-only; no threshold/pattern pack yet.
  - **Unknown / no match** — ways-of-working only for that root.

#### 0d. Surface inventory (informational; feeds later questions)

Under the project base and each multi-repo root, note presence of:

- `AGENTS.md` / `CLAUDE.md`
- `.github/copilot-instructions.md` or `**/copilot-instructions.md`
- `.github/instructions/**`
- `.github/workflows/*` that look like PR gates (name/body signals in
  `config-resolution.md` → Convention auto-sources)

Report a one-line inventory in the wizard summary (e.g. "agents=2, copilot=1,
instructions packs=3, gate-like workflows≈8").

---

### 1. Placement (fresh + multi-repo; skip for pure calibrate)

**Target dir** for config files is always `{project_base}/.intense/`.

| Profile | Default project base | Confirm |
|---------|----------------------|---------|
| **monolith** | git root of cwd | Usually no question; write `.intense/` there |
| **multi-repo** | **workspace root** that contains the sibling apps (parent of BE/FE/…), **not** deep inside one app | Ask: shared workspace `.intense/` (Recommended) vs per-repo `.intense/` only |

**Shared workspace config (recommended for multi-repo):**

- One `.intense/` at the workspace root.
- Child apps inherit via **walk-up** when agents run from `backend/` etc.
- Set `conventions.auto.roots` to the sibling dir names (relative to project base).

**Per-repo only:** only when the user insists stacks diverge sharply; warn that
cross-stack notes and severity will not share unless duplicated.

If cwd is already inside a child app and multi-repo is chosen, **change writes** to the
workspace root after confirmation — do not silently put config only in the child.

For **upgrade**, resolve existing `PROJECT_INTENSE` via walk-up; do not move it unless
the user explicitly asks to migrate placement.

---

### 2. Choose what to scaffold (fresh) / menu

Parse `$ARGUMENTS`:

| Token | Effect |
|-------|--------|
| `all` | ways + patterns + thresholds (full set; not calibrate) |
| `ways` / `patterns` / `thresholds` | that file only |
| `fresh` | full wizard; default file set = all |
| `upgrade` | Step U |
| `calibrate` [p…] | Step 2c |
| blank | mode from 0a; then menu if still needed |

**Fresh interactive menu** (multi-select) when selection is still open:

| Option | File | What it controls |
|--------|------|------------------|
| Ways of working | `.intense/ways-of-working.yaml` | lenses, tools, severity, conventions (incl. auto), severity_align, confidence, artifacts |
| Pattern policy | `.intense/patterns.yaml` | preferred / allowed / blocked / approved |
| Thresholds | `.intense/thresholds.yaml` | architecture metric limits (Arch pack ✅ stacks only) |
| **Calibrate** | updates thresholds | measure + propose (after files exist) |
| All | all three | full config set (not calibrate) |

Recommend **All** for first run. Recommend **Calibrate** after All when any Arch pack ✅
is present.

Non-interactive / `$ARGUMENTS`-driven runs: skip menus; scaffold documented defaults
(and any values already known from arguments). File comments explain later edits.

---

### 2b. Capability questions (fresh interactive; also offered in upgrade)

When scaffolding or upgrading **ways-of-working** and/or **patterns** interactively,
ask short questions and write answers into the files. Defaults differ by profile:

| Question | Monolith default | Multi-repo default |
|----------|------------------|--------------------|
| Which files? | All | All |
| Lens toggles | predict/convention/simplicity **on**; experience/architecture **auto** | same |
| `tools.architecture` | `enrich` (or `prefer` if reek/rubocop/eslint/phpstan/credo already in CI) | same |
| `conventions.auto.mode` | `curated` | `curated` + **roots** filled from detected siblings |
| `severity_align.mode` | `curated_gates` | `curated_gates` |
| Prefer interactor over service_object? | **ask** (Rails Arch pack only) | **ask** (if any rails root) |
| Grandfather `app/services/**`? | only if blocking services | same |
| Artifact paths | defaults from config-resolution | same |
| Calibrate now? | offer after write | offer per Arch pack stack |

#### Questions (use AskUserQuestion; skip if non-interactive)

1. **Which lenses run?** Default as table. User may turn any **off**. Write `lenses.*`.

2. **External-tool preference** (if architecture not off): enrich / prefer / report / off.
   Write `tools.architecture`.

3. **Convention auto-sources** — "Discover Copilot packs, path-scoped instructions, and
   PR-gate workflows?" → `curated` (Recommended) / `all` / `off`. Write
   `conventions.auto.mode`.  
   - Multi-repo: confirm **roots** list (detected siblings; user can edit). Write
     `conventions.auto.roots: [be, fe, …]`. Empty roots = project base only.  
   - Keep default `include` and `exclude` from the template unless the user trims packs.

4. **Severity align with CI gates** — "Promote finding severity when a discovered PR
   workflow matches the theme (e.g. callback check)?" → `curated_gates` (Recommended) /
   `off`. Write `severity_align.mode` (and keep `min_severity: P1` unless changed).

5. **Pattern stance** (when scaffolding patterns **and** a stack catalog has
   `interactor` + `service_object`, typically Rails):  
   - Prefer interactors for new multi-step domain work? → if yes, set **only**  
     `preferred: [{ id: interactor, instead_of: [service_object], when: "…", note: "…" }]`.  
     Do **not** also add `service_object` to `blocked` for the same stance (preferred
     already P1s new instead_of use; double-listing creates duplicate findings).  
   - Grandfather legacy services? → if yes,  
     `approved: [{ path: app/services/**, reason: "legacy; no NEW services" }]`.  
   - Optional advanced: block without preferred only when the team wants a ban with no
     replacement id.  
   - If no Rails (or user declines), leave preferred/blocked empty (or stack seed only).

6. **Where do reports go?** Confirm `artifacts.*` defaults from
   `${CLAUDE_PLUGIN_ROOT}/references/config-resolution.md`. Write overrides only if the
   user changes them. Always restate resolved paths in the final summary.

7. **Seed `conventions.sources`?** If AGENTS/CLAUDE (or triage docs) exist under roots,
   offer to add those **paths** to `sources` (not paste file bodies). Preview list;
   user accepts / edits. Explicit sources always win over exclude.

Non-interactive: scaffold defaults verbatim (auto mode `curated`, severity_align on,
preferred empty). Set `conventions.auto.roots` when `$ARGUMENTS` includes
`multi-repo` and/or `roots:a,b,c` (comma-separated sibling dirs). Without those tokens,
roots stay empty (base only) unless this run already confirmed multi-repo interactively.

---

### 2c. Calibrate thresholds (`calibrate` / menu)

When the user asks to calibrate (or `$ARGUMENTS` starts with `calibrate`):

1. Detect stack(s) via stack-catalog; require at least one **Arch pack ✅**. If none, stop
   and explain.
2. Load metric keys from each stack's namespace in
   `${CLAUDE_PLUGIN_ROOT}/config/defaults/thresholds.yaml` and path globs from the stack
   architecture doc / pattern catalog (same units the architecture lens measures:
   LOC, public methods, associations, callbacks, method length, etc.).
3. Measure distributions over the relevant tree (exclude `vendor`/`node_modules`/build):
   for each metric compute **n, median, p75, p90, p95, max** (simple sort + index is fine;
   Bash or a short Ruby/Python one-liner is OK). Multi-repo: measure under each root that
   matches that stack.
4. Target percentile = argument (`p90` default) or user choice. Propose
   `threshold = ceil(percentile)` (or just above p90 so the fat tail flags, not the bulk).
5. **Present** a table: metric | median | p75 | p90 | max | default | proposed. Flag any
   metric where the shipped default is far outside the distribution (either direction).
6. On confirmation, write/update `.intense/thresholds.yaml` for those stack namespaces.
   **Never clobber without confirmation.** Put **evidence in comments**:

   ```yaml
   max_callbacks: 2   # median 0, p75 0, p90 2, max 29 (measured 2026-07-29, n=515, target p90)
   ```

7. If the user declines write, print the proposed YAML block for copy-paste.

If full measurement is too heavy for the session, fall back to the smaller form: run
the same measurement summary into the next `/ie-audit` Observations section and leave
thresholds unchanged until the human pastes numbers.

---

### 3. Copy / write templates (fresh; idempotent, stack-aware)

Source templates are `${CLAUDE_PLUGIN_ROOT}/config/defaults/<file>`. Write to
`{project_base}/.intense/<file>`. **Never overwrite an existing `.intense/<file>`**
without explicit confirmation — a surprising clobber of committed team config is the
failure mode to avoid (least astonishment / no data loss). If a target exists, report
it and ask whether to overwrite, diff, or skip; default to **skip**.

Before write on interactive fresh: show a **short preview** of the values that differ
from raw defaults (roots, auto mode, severity_align, preferred patterns, lens offs).
Confirm once, then write.

#### `ways-of-working.yaml`

Start from the default template, then apply capability answers:

- `lenses.*`, `tools.architecture`, `artifacts.*` from questions 1–2 and 6.
- `conventions.auto.mode`, `conventions.auto.roots`, optional `include`/`exclude` tweaks.
- `conventions.sources` from question 7 (paths that exist).
- `severity_align.mode` (+ keep `min_severity` / `themes` structure from template).
- Do **not** invent long `notes` at init; leave `notes: []` (use `/ie-from-pr-learnings`
  later for PR-mined notes).

```bash
mkdir -p .intense   # at project_base
SRC="${CLAUDE_PLUGIN_ROOT}/config/defaults/ways-of-working.yaml"
DST=".intense/ways-of-working.yaml"
# Prefer: copy then edit keys, or emit merged YAML with comments preserved where practical.
if [ -e "$DST" ]; then echo "EXISTS: $DST"; else …; fi
```

#### `thresholds.yaml`

**Scaffold only the detected stack namespace(s)** (union for multi-repo), not every stack
in the global defaults file. Config-resolution deep-merges a partial file over defaults.

Emit the file header comment + each `<stack>:` block for detected Arch pack ✅ stacks:

```bash
SRC="${CLAUDE_PLUGIN_ROOT}/config/defaults/thresholds.yaml"
DST=".intense/thresholds.yaml"
# For each STACK in detected Arch-pack stacks, extract that top-level block with awk
# (same pattern as single-stack extract; append blocks for multi-stack).
```

For **Arch pack ⬜** / unknown only: skip `thresholds.yaml` and say no architecture pack
exists yet.

#### `patterns.yaml`

Copy default policy shape, then:

1. Seed `allowed:` with pattern ids from **each** detected stack's catalog
   (`${CLAUDE_PLUGIN_ROOT}/resources/patterns/<stack>.yaml`) when that helps the team —
   or leave empty with a top comment naming the stacks (empty allowed = no explicit
   allow-list; lens still classifies). Prefer **commented** examples over a huge
   allow-list unless the user asked for full seed.
2. Apply **preferred / blocked / approved** from capability question 5 when yes.
3. Note stacks in the file's top comment.
4. Pattern ids must exist in a catalog; never invent ids.

The written files keep explanatory comments so the team can edit in place.

---

### U. Upgrade mode (`upgrade`)

Goal: add **missing capabilities** from current plugin defaults without wiping hand-tuned
`notes`, `sources`, `severity_overrides`, roots, or pattern lists.

#### U1. Load

1. Resolve `PROJECT_INTENSE` (walk-up / `config:` / `INTENSE_CONFIG_DIR`).
2. If none: say so and offer **fresh** instead.
3. Load project yaml + defaults from `${CLAUDE_PLUGIN_ROOT}/config/defaults/`.
4. Re-run light detect (0b–0d) for roots/stacks recommendations.

#### U2. Capability table

Build and **show** a table (do not write yet):

| Capability | In project? | Plugin default / recommendation | Proposed action |
|------------|-------------|----------------------------------|-----------------|
| `conventions.auto` block | present / missing / partial | mode curated; roots for multi-repo | add missing keys only |
| `conventions.auto.roots` | empty / set | detected siblings | set if empty and multi-repo |
| `severity_align` | present / missing | curated_gates | add if missing |
| `artifacts.*` | present / legacy `report_dir` only | two-layer defaults | offer migrate; never force |
| `patterns.preferred` | empty / set | optional interactor preference | ask if rails + empty |
| `patterns.blocked` / approved | … | … | ask if preferred chosen |
| Missing config **files** | ways / patterns / thresholds | stack-aware scaffold | create missing files only |
| Thresholds never calibrated | n/a | offer calibrate | handoff Step 2c |

**Deep-merge reminder:** maps merge key-by-key. If the project has `conventions.notes`
but omits `conventions.auto`, defaults already supply `auto` at runtime. Upgrade still
**materializes** important blocks into the project file when the user wants them
visible/editable (least surprise for humans reading git).

#### U3. User picks

Interactive multi-select: enable missing / leave alone / customize. Default: enable
safe missing blocks (`auto`, `severity_align`, missing files) **without** overwriting
existing non-empty lists or notes.

#### U4. Apply rules (strict)

- **Never** delete or replace existing `conventions.notes` lines.
- **Never** clear non-empty `sources`, `preferred`, `blocked`, `approved`, or
  `severity_overrides` without explicit overwrite confirm.
- **Add** missing top-level or nested keys from defaults (e.g. insert `severity_align:`
  block; insert `conventions.auto:` if absent; fill `roots` only when empty and user
  accepted).
- **Create** missing of the three files with stack-aware scaffolding (same as Step 3).
- **Legacy** `report_dir` without `artifacts:`: offer to add `artifacts.*` and leave
  legacy key commented or removed only on confirm (document behavior in summary).
- Show a **diff-style** summary before write; confirm once.

#### U5. Optional handoffs

After upgrade: offer `/ie-init calibrate` and `/ie-from-pr-learnings` (do not run them
unless the user asks).

---

### 4. Gitignore for run scratch (optional; re-offered until the path is ignored)

Resolve the **active** run-scratch path first (same rules as
`${CLAUDE_PLUGIN_ROOT}/references/config-resolution.md`):

- If project `.intense/ways-of-working.yaml` has `artifacts.run_dir` → use that.
- Else if it has top-level `report_dir:` and **no** `artifacts:` block (**legacy
  single-bucket**) → scratch is under `report_dir/<run-id>/`. Offer to ignore
  `report_dir/` only when that path is clearly ephemeral (e.g. still
  `wip/intent-engineering`); if `report_dir` looks like a docs/publish path, **skip**
  the gitignore offer and explain that legacy mode keeps scratch next to published
  reports without auto-cleanup.
- Else → default `.intense/runs/`.

After scaffolding or upgrading ways-of-working (or on any init that mentions artifacts),
if the project `.gitignore` does **not** already ignore the resolved scratch root,
**offer** to append it (example for the default):

```
# Intent Engineering — ephemeral lens run scratch (published reports live under docs/)
.intense/runs/
```

This is **not** remembered across declines — if the line is still missing, the offer
reappears on the next `/ie-init`. That is intentional (least surprise: no hidden
"don't ask again" flag). Never force; never add `.intense/` itself (config YAML must
stay committable). Do not invent a `wip/` ignore for the plugin default — `wip/` is no
longer the plugin report home.

For multi-repo **shared** config: prefer the workspace root `.gitignore`. If only a
child has a gitignore, note that runs may live at workspace `.intense/runs/` and the
ignore should be where that path is tracked.

---

### 5. Report

List what was created, updated, skipped, or proposed. Then tell the user:

- **Profile + placement:** monolith/multi-repo; absolute path of `.intense/`; roots if any.
- **Capabilities enabled:** auto mode, severity_align, preferred patterns, stacks.
- The files are **meant to be committed** (project config, not artifacts) — do **not**
  add `.intense/` to `.gitignore` (only `.intense/runs/` if they accepted Step 4).
- Published reports land under `docs/intent-engineering/` by default; run scratch is
  cleaned up after each successful publish when `cleanup_runs: true`.
- Edit config to taste; every `ie-*` run merges project over plugin defaults (project
  wins; lists replace unless `extends: true`).
- **Natural next steps:**
  - `/ie-audit` for posture under the new config
  - `/ie-init calibrate p90` if Arch pack ✅ and thresholds still generic
  - `/ie-from-pr-learnings` when PR triage exists (smarter notes over time; not required
    at first install)
  - For multi-repo: run agents from a child cwd and confirm Coverage shows
    `Config: project:…` via walk-up

This skill only writes under `.intense/` (and optionally one `.gitignore` append the
user accepted). It never commits or pushes.

---

## Argument quick reference

| Invocation | Mode |
|------------|------|
| `/ie-init` | Wizard: detect fresh vs upgrade; profile; capabilities |
| `/ie-init all` | Fresh full file set (still capability questions if interactive) |
| `/ie-init ways` | Ways only |
| `/ie-init patterns` | Patterns only |
| `/ie-init thresholds` | Thresholds only (stack namespaces) |
| `/ie-init fresh` | Force fresh wizard |
| `/ie-init upgrade` | Capability diff + merge missing |
| `/ie-init calibrate` | Threshold measurement (default p90) |
| `/ie-init calibrate p75` | Calibrate at p75 |
| `/ie-init multi-repo` | Fresh with multi-repo profile default |
| `/ie-init roots:backend,frontend` | Seed `conventions.auto.roots` (with or without multi-repo) |

---

## Reference files (read at runtime)

- `${CLAUDE_PLUGIN_ROOT}/references/config-resolution.md` — walk-up, merge, auto sources,
  severity_align, artifacts
- `${CLAUDE_PLUGIN_ROOT}/references/stack-catalog.md` — stack detection + Arch pack
- `${CLAUDE_PLUGIN_ROOT}/config/defaults/` — source templates
- `${CLAUDE_PLUGIN_ROOT}/resources/patterns/<stack>.yaml` — valid pattern ids
- `${CLAUDE_PLUGIN_ROOT}/skills/ie-from-pr-learnings/SKILL.md` — post-init learnings loop
  (not part of first install)
