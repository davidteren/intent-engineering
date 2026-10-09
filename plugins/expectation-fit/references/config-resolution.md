# Config Resolution

How `fit-*` skills and lenses load and merge the "ways of working" config. The config
lets a repo owner toggle lenses, override severities, set architecture thresholds, and
declare which design patterns are allowed / blocked / pre-approved.

## Locations (in precedence order)

1. **Explicit override** (highest) — either of:
   - run argument `config:<path>` (directory that contains or *is* `.expectation-fit`, or a
     directory that holds `ways-of-working.yaml` / `patterns.yaml` / `thresholds.yaml`)
   - environment variable `EXPECTATION_FIT_CONFIG_DIR` (same path rules)
2. **Nearest project config** — the nearest `.expectation-fit/` directory found by **walking up**
   that contains **at least one** of the three yaml files (see Discover procedure). Empty
   placeholder `.expectation-fit/` dirs are skipped. Committable team config.
3. **Global defaults** — `${CLAUDE_PLUGIN_ROOT}/config/defaults/`. Shipped with the
   plugin. Used for any key the project file doesn't set.

Only `config:<path>` and `EXPECTATION_FIT_CONFIG_DIR` (or the legacy `INTENSE_CONFIG_DIR`)
change discovery. Caller wording such as "use plugin defaults" never skips the walk-up.

A project file need not be complete — it overrides only the keys it specifies; the rest
fall back to defaults. To **materialize** new default capabilities into an existing
project file (visible in git, editable) without wiping notes, run `/fit-setup upgrade`
(see `${CLAUDE_PLUGIN_ROOT}/skills/fit-setup/SKILL.md`).

## Authority order (what wins when sources disagree)

Descending authority for *conventions and judgment* (not only YAML merge). Single source
of truth — agents reference this section; do not invent a different order.

1. **Project config YAML** — resolved `.expectation-fit/*.yaml` fields (`conventions.notes`,
   pattern policy, thresholds, severity overrides). Highest for plugin config.
2. **`conventions.sources` files** — paths/globs listed under project config (review-bot
   packs, engineering standards, CI policy docs).
3. **Repo instruction docs** — `CLAUDE.md` / `AGENTS.md` whose directory is an ancestor of
   the work.
4. **Sibling code** — established patterns in the same tree.
5. **Plugin defaults / framework docs** under `${CLAUDE_PLUGIN_ROOT}/` — lowest.

Within conventions: **`notes` (tier 1) beat `sources` (tier 2)** when both speak. YAML
merge (project over `config/defaults/`) is separate and described under Merge rules.

### Base directory for `conventions.sources` globs

Relative globs in `conventions.sources` resolve from **one** project base:

| How config was found | Project base for relative globs |
|----------------------|----------------------------------|
| Walk-up / path ends in `.expectation-fit` | Parent of that `.expectation-fit/` directory |
| `config:` / `EXPECTATION_FIT_CONFIG_DIR` is a dir that **is** `.expectation-fit` | Parent of that dir |
| `config:` / `EXPECTATION_FIT_CONFIG_DIR` is a dir that **contains** the three yaml files directly | That directory itself |
| Defaults only (no project config) | `$PWD` |

Absolute paths in `sources` are used as-is (no rebasing).

The same project base (`PROJECT_BASE`) applies to relative `artifacts.run_dir`,
`artifacts.report_dir` and `out:` paths. Orchestrators turn them into absolute paths
before the first write.

### Convention auto-sources (Copilot, instructions, workflows)

Explicit `conventions.sources` is never enough in a real monorepo: Copilot packs and
PR-gate workflows already encode house rules. **`conventions.auto`** discovers them so
the convention lens (and audit CI-delta) see the same authority surface humans already
maintain in GitHub.

```yaml
conventions:
  sources: []           # always merged in (explicit)
  auto:
    mode: curated       # off | curated | all
    include: [agents, copilot, instructions, workflows]
    roots: []           # e.g. [backend, frontend] for a workspace of repos
    exclude: []         # REPLACE-only when set (no extends): list every glob you want,
                        # including defaults you still need, or omit the key to keep defaults
```

**Mode:**

| Mode | Behavior |
|------|----------|
| `off` | No discovery. Only explicit `sources` + normal AGENTS/CLAUDE read. |
| `curated` (default) | Expand **include** packs with high-signal globs; for `workflows`, keep only files that look like **PR code gates** (name or content signals below). |
| `all` | Expand include packs with broad globs (all workflow yml under roots). Still applies `exclude`. |

**Pack → default globs** (under each `root`, relative to project base; `.` = base):

| Pack | Globs |
|------|--------|
| `agents` | `AGENTS.md`, `CLAUDE.md`, `**/AGENTS.md`, `**/CLAUDE.md` under each root |
| `copilot` | `.github/copilot-instructions.md`, `**/.github/copilot-instructions.md`, `**/copilot-instructions.md` |
| `instructions` | `.github/instructions/**`, `**/.github/instructions/**` |
| `workflows` (curated) | `.github/workflows/*.{yml,yaml}` that match **gate signals** (below) |
| `workflows` (all) | `.github/workflows/*.{yml,yaml}` (minus exclude) |

**Listing method.** In each root, list candidate files with
`git -C <root> ls-files --cached --others --exclude-standard`. Match the pack globs against
that list. Do not use `find`: it walks into agent worktrees and reads no ignore file.
Outside a git repo, walk the tree and skip `.git` and `.claude/worktrees`.

**Scope of auto-discovered agents / instructions:** discovery may find many files under
`roots`, but the convention lens **applies** an `AGENTS.md`/`CLAUDE.md` only to files
whose path is under that doc's directory (ancestor chain of the changed file). Nested
app rules do **not** apply workspace-wide. Path-scoped `.github/instructions/**` still
honor `applyTo` frontmatter.

**Workflow gate signals** (`mode: curated` only). The rule is mechanical: keep a
workflow when a name token or a body token matches **and** no `exclude` glob matches.
Drop every other workflow.

- File name contains: `rubocop`, `eslint`, `semgrep`, `callback`, `migration`, `secret`,
  `detect-secret`, `brakeman`, `lint`, `test`, `rspec`, `jest`, `playwright`, `contract`,
  `security`, `codeql`, `typecheck`, `tsc`, `prettier`, `danger`, `pr-title`, `mutation`
- File body (read the whole file) mentions: `bin/check`, `bin/ci`, `rubocop`, `eslint`,
  `semgrep`, `rspec`, `jest`, `playwright`, `strong_migrations`, `online_migrations`,
  `pytest`, `npm test`, `go test`, `mix test`, `phpunit`, `rails test`, `brakeman`,
  `ruff`, `vitest`

**Path-scoped instructions:** files under `.github/instructions/` often have YAML
frontmatter `applyTo: "glob,glob"`. The convention lens **must** honor `applyTo` when
present: only apply those rules to matching files in the review/audit scope. Files
without `applyTo` apply repo-wide for that root.

**Authority of auto-discovered files:** same as explicit `sources` (tier 2 under
Authority order). `notes` still win. List the **resolved path list** in Coverage:

`Config sources (auto): N files (copilot=…, instructions=…, workflows=…); excluded=…`

**Merge:** resolved source set = unique(`sources` + auto-discovered − exclude). Explicit
`sources` always included even if they would match exclude (explicit wins).

### Severity align with CI gates

After lenses return findings, the **orchestrator** may promote severity when a discovered
PR-gate workflow (from `conventions.auto`) covers the same theme. This does **not** parse
every CI step; it matches **workflow basename + theme table**.

```yaml
severity_align:
  mode: curated_gates   # off | curated_gates
  min_severity: P1
  themes: []            # optional extra rows; see below
```

**Mode `off`:** no auto promotion (only explicit `severity_overrides`).  
**Mode `curated_gates`:** for each finding, if any auto-discovered workflow path matches a
theme row **and** the finding matches that row under the rules below, set severity to
the **more severe** of (current, theme.severity or min_severity) and append
`because: "CI gate: <workflow basename>"` into Coverage / finding evidence.

**Severity rank** (higher = more severe; never demote):

```
P0 > P1 > P2 > P3
```

Define `more_severe(a, b)` as the higher-ranked of the two. Examples:
`more_severe(P3, P1) = P1`; `more_severe(P0, P1) = P0`; `more_severe(P2, P2) = P2`.
Do **not** use string/lexicographic `max` (it can yield the milder severity).

**Finding match rules** (apply per theme row after the workflow basename matched):

1. If the row lists **non-empty `smells`**: the finding matches only when its `smell`
   is in that list. **Do not** promote on `principle` alone when smells are listed
   (avoids promoting every `architecture` finding because a `callback-*.yml` exists).
2. Else if the row lists **non-empty `principles`**: the finding matches when its
   `principle` is in that list. Use this only for **narrow** project themes — not for
   broad principles that most findings share.
3. Else (both empty): **Coverage note only** — do not change severity.

**Built-in theme map** (workflow basename contains any of `match` tokens, case-insensitive):

| match tokens (workflow name) | smells | principles | Effect |
|------------------------------|--------|------------|--------|
| `callback` | `callback-hell` | (empty) | Promote when smell matches |
| `migration`, `migrations` | (empty) | (empty) | Coverage note only until a schema smell id ships |
| `rubocop`, `eslint`, `prettier`, `lint` | (empty) | (empty) | Coverage note only (do not mass-promote convention findings) |
| `semgrep`, `brakeman`, `codeql`, `security`, `secret`, `detect-secret` | (empty) | (empty) | Coverage note only unless project `themes` add smells |
| `rspec`, `jest`, `playwright`, `test`, `minitest` | (empty) | (empty) | Coverage note only |
| `pr-title` | (empty) | (empty) | Coverage note only |

Project `severity_align.themes` entries (opt-in promote with explicit smells):

```yaml
- match: [callback]
  smells: [callback-hell]     # non-empty → smell required
  principles: []              # used only when smells is empty
  severity: P1                # optional floor; default min_severity
```

**Order of application (synthesis):**

1. Lens-emitted severity  
2. **`severity_align`** promotions (if mode on and gate matched; smell-first + rank above)  
3. Explicit **`severity_overrides`** (always last; win on conflict)  

List promotions in Coverage: `Severity align: #N callback-hell P2→P1 (callback-check.yml)`.

## Discover project `.expectation-fit/` (walk-up)

**Do not** bind project config only to `./.expectation-fit` relative to cwd. Nested checkouts
and monorepo workspaces often place cwd inside a sub-repo while the tuned config lives
at a parent workspace root. Silent fallback to defaults is the failure mode this
procedure prevents.

**Legacy folder.** Before the rename (0.9.0) the folder was `.intense/` and the env var was
`INTENSE_CONFIG_DIR`. Both still work for at least one release. At each level the walk-up
checks `.expectation-fit/` first, then `.intense/`. When the legacy folder wins, Coverage
says so and suggests `/fit-setup upgrade` to move it.

```bash
# Resolve PROJECT_CONFIG (directory containing at least one of the three yaml files)
# Precedence: config:<path> arg -> EXPECTATION_FIT_CONFIG_DIR -> INTENSE_CONFIG_DIR (legacy) -> walk-up -> empty (defaults only)
has_config_yaml() {
  [ -f "$1/ways-of-working.yaml" ] || [ -f "$1/patterns.yaml" ] || [ -f "$1/thresholds.yaml" ]
}

# Explicit path: succeed only when the resolved dir exists AND has at least one yaml.
# Prefer a config folder under arg only when it has yaml; else yaml directly under arg.
resolve_explicit_config() {
  arg="$1"
  case "$arg" in
    */.expectation-fit|.expectation-fit|*/.intense|.intense)
      if [ -d "$arg" ] && has_config_yaml "$arg"; then echo "$arg"; return 0; fi
      return 1 ;;
  esac
  for name in .expectation-fit .intense; do
    if [ -d "$arg/$name" ] && has_config_yaml "$arg/$name"; then
      echo "$arg/$name"
      return 0
    fi
  done
  if has_config_yaml "$arg"; then
    echo "$arg"
    return 0
  fi
  return 1
}

resolve_walk_up() {
  dir="$PWD"
  depth=0
  # Walk up to filesystem root (cap 32). Nearest config folder with at least one yaml wins.
  # At each level .expectation-fit beats the legacy .intense. Empty placeholders are skipped.
  while [ -n "$dir" ] && [ "$depth" -lt 32 ]; do
    for name in .expectation-fit .intense; do
      if [ -d "$dir/$name" ] && has_config_yaml "$dir/$name"; then
        echo "$dir/$name"
        return 0
      fi
    done
    [ "$dir" = "/" ] && break
    dir=$(dirname "$dir")
    depth=$((depth + 1))
  done
  return 1
}

PROJECT_CONFIG=""
CONFIG_SOURCE="defaults"
EXPLICIT="${CONFIG_ARG:-${EXPECTATION_FIT_CONFIG_DIR:-${INTENSE_CONFIG_DIR:-}}}"
if [ -n "$EXPLICIT" ]; then
  if PROJECT_CONFIG=$(resolve_explicit_config "$EXPLICIT"); then
    CONFIG_SOURCE="project:$PROJECT_CONFIG"
  else
    # Invalid explicit path: defaults only; never claim project:
    CONFIG_SOURCE="defaults (invalid config path: $EXPLICIT)"
    PROJECT_CONFIG=""
  fi
else
  PROJECT_CONFIG=$(resolve_walk_up) || PROJECT_CONFIG=""
  [ -n "$PROJECT_CONFIG" ] && CONFIG_SOURCE="project:$PROJECT_CONFIG"
fi
case "$PROJECT_CONFIG" in
  */.intense) CONFIG_SOURCE="$CONFIG_SOURCE (legacy folder; run /fit-setup upgrade to move it to .expectation-fit/)" ;;
esac
DEFAULTS="${CLAUDE_PLUGIN_ROOT}/config/defaults"
# Always record for Coverage (required: never silent about source):
#   Config: project:/path/to/.expectation-fit (walked up from <cwd>)
#   Config: project:/path/to/.intense (legacy folder; run /fit-setup upgrade ...)
#   Config: defaults (no .expectation-fit/ found, searched from <cwd> up to filesystem root). Next: run /fit-setup to save repo rules once.
#   Config: project:/path (via config: or EXPECTATION_FIT_CONFIG_DIR)
for f in ways-of-working patterns thresholds; do
  if [ -n "$PROJECT_CONFIG" ] && [ -f "$PROJECT_CONFIG/$f.yaml" ]; then
    echo "project: $f ($PROJECT_CONFIG/$f.yaml)"
  else
    echo "default: $f"
  fi
done
```

**Walk-up rules:**
- Start at `$PWD`; look for `$dir/.expectation-fit` (then legacy `$dir/.intense`) that **has at least one** of the three yaml
  files. Empty `.expectation-fit/` placeholders are skipped.
- Stop at the first usable match (**nearest wins**). A child with real config shadows a
  parent workspace.
- Continue past `.git` boundaries so a workspace-of-repos layout can share one
  `.expectation-fit/` at the workspace root when sub-repos have none.
- Cap walk depth at 32 parents.

Read whichever file exists for each of the three configs under `PROJECT_CONFIG`; if the
project file exists, deep-merge it over the default per the rules below. Pass the
resolved values to the lenses in their spawn prompt (e.g. resolved thresholds to
`fit-architecture-reviewer`, resolved `conventions.notes` and repo standards paths to
every selected lens, `conventions.sources` / `conventions.auto` to
`fit-convention-reviewer`, lens toggles to selection).

When no project `.expectation-fit/` is found, use defaults — the plugin works out of the box.
**Always** put the config source line in Coverage (including when using defaults).
Under it, list the three per-file source lines that the block above prints, for example
`project: ways-of-working (<path>)` next to `default: thresholds`.

## Merge rules (project over global)

Nested maps merge recursively at every depth. Only lists replace, unless the block sets `extends: true`.

- **Scalars and maps** (e.g. `confidence_gate`, `lenses.*`, `thresholds.rails.model.max_loc`):
  the project value **replaces** the global value key-by-key, at every depth. Keys the
  project omits keep the global value.
- **Lists** (e.g. `conventions.notes`, `patterns.preferred/allowed/blocked/approved`): the
  project list **replaces** the global list — **unless** the owning block sets
  `extends: true`, in which case the project list is **appended** to the global list.
  Default is replace (least-astonishing: what you write in the project file is what you
  get). Only blocks that expose an `extends` flag support append: the `conventions` block
  does; the `patterns.preferred/allowed/blocked/approved` lists are **replace-only** (no
  `extends` knob), so a project `patterns.yaml` list fully replaces the default — list
  every entry you want.
- **`version`**: informational; if a project file's `version` is higher than the plugin
  understands, note it in Coverage and proceed best-effort.

## How the resolved config is used

| Config | Consumer | Effect |
|--------|----------|--------|
| `lenses.*` | skill lens-selection | `on`/`off`/`auto` decides which lenses run (turn an agent off here) |
| `tools.architecture` | `fit-architecture-reviewer` | `enrich`/`prefer`/`report`/`off` — how the lens treats an installed external static-analysis tool (see below) |
| `severity_overrides` | synthesis | remap severity by principle/smell id (string or `{ severity, because }`). Applied **after** severity_align. A valid key is a principle id in `findings-schema.json` or a canonical smell id. List any other key in Coverage as `ignored severity_overrides key: <key>`. |
| `severity_align` | synthesis | promote severity when a curated CI gate matches a finding theme (`mode: off\|curated_gates`). See Severity align with CI gates. |
| `conventions.notes` | every selected lens | hand-authored repo rules (alongside CLAUDE.md/AGENTS.md). Every lens treats them as limits; only `fit-convention-reviewer` reports a broken note. |
| `conventions.sources` | `fit-convention-reviewer` | explicit path globs for high-authority files. Resolve from project base. |
| `conventions.auto` | `fit-convention-reviewer` + audit | discover Copilot / instructions / PR-gate workflows (`mode: off\|curated\|all`). See Convention auto-sources. |
| `confidence_gate` | synthesis | suppression anchor (default 75; P0 survives 50+) |
| `artifacts.run_dir` | skills | Layer A — per-run scratch for lens JSON (default `.expectation-fit/runs`) |
| `artifacts.report_dir` | skills | Layer B: report dir (default `.expectation-fit/reports`, git-ignored). Set `docs/expectation-fit` to commit reports. |
| `artifacts.cleanup_runs` | skills | delete the run dir after the report step (default `true`) |
| `report_dir` *(legacy)* | skills | alias for `artifacts.report_dir` (see Artifact paths). Run scratch still uses `artifacts.run_dir`. |
| `patterns.preferred/allowed/blocked/approved/unknown_pattern` | `fit-architecture-reviewer` | preferred-over (instead_of), classify, flag blocked-in-changed-code, suppress approved, raise unknown |
| `thresholds.*` | `fit-architecture-reviewer` | metric limits for structural smells |

## Artifact paths (orchestrators — shared)

Every `fit-review` / `fit-audit` / `fit-validate-plan` run uses **two layers**:

| Layer | What | Default |
|-------|------|---------|
| **A — run scratch** | `{lens}.json` while lenses run; ephemeral merge helpers | `.expectation-fit/runs/<run-id>/` |
| **B: report** | one human-facing file (`*.md`, or `*.json` in `mode:agent` with `out:`) | `.expectation-fit/reports/<stamp>-<skill>[-scope].md` |

**Keep analysis out of git by default.** Both default folders ignore themselves: the
canonical block writes a one-line `*` `.gitignore` into each run folder and into the
default report folder. A run adds nothing to `git status`. A project that wants to
commit reports sets `artifacts.report_dir: docs/expectation-fit` (no ignore file is
written there). Warn: a `docs/` folder is often published as a public site.

**Resolution order for the report path (Layer B):**

1. `out:<path>` on the skill invocation — if it ends in `.md` / `.json`, use as the file path; otherwise treat as a directory and place the default filename inside it. Outside-repo only when explicitly given.
2. Else the project `artifacts.report_dir`.
3. Else a project top-level `report_dir` (legacy alias for `artifacts.report_dir`).
4. Else the default `artifacts.report_dir` (`.expectation-fit/reports`).

When the project file has a top-level `report_dir` and no `artifacts` block, end the
Config line with: "legacy report_dir: used as artifacts.report_dir. Run /fit-setup
upgrade." Do not warn when a project file only lacks some keys, because the defaults
fill them.

**`mode:agent`:** the JSON reply is the deliverable. Write a report file only when the
caller passes `out:`. Without `out:`, `REPORT_PATH` stays empty and `artifact_path` is
`null`.

**Resolution order for the run dir (Layer A):**

1. Resolved `artifacts.run_dir` (project over defaults).
2. Else built-in `.expectation-fit/runs`.

**Run id + published filename** — this block is the **canonical** orchestrator procedure.
`fit-review`, `fit-audit`, and `fit-validate-plan` **must not re-author it**; they only bind
slots (`SKILL_SLUG`, `SCOPE`, `OUT_ARG`, `EXT`) and follow this block. `SCOPE` is the
raw branch, PR, plan path or target; the block normalizes it into `SCOPE_SLUG`, so
parallel runs name reports the same way.

```bash
# CANONICAL_ORCHESTRATOR_PATHS — single source of truth (do not duplicate in skills)
STAMP=$(date +%Y%m%d-%H%M%S)
RUN_ID="${STAMP}-$(head -c4 /dev/urandom | od -An -tx1 | tr -d ' ')"
# skill slug: audit | review | validate-plan
# SCOPE: raw branch / PR / plan path / target, or empty
# EXT=md normally; json when mode:agent
# Slug rule: take the basename; drop the extension only for an existing file; lowercase;
# replace each run of other characters with one hyphen; trim end hyphens.
#   docs/plans/2026-09-28-007-feat-prd-15-Topic-plan.md -> 2026-09-28-007-feat-prd-15-topic-plan
#   feat/ep-04-search -> ep-04-search    release/1.2.0 -> 1-2-0    (empty) -> (empty)
slug_of() {
  [ -n "$1" ] || return 0
  s=$(basename -- "$1"); [ -f "$1" ] && s="${s%.*}"
  printf '%s' "$s" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//; s/-*$//'
}
SCOPE_SLUG=$(slug_of "$SCOPE")
# RUN_DIR / REPORT_DIR / CLEANUP already resolved from artifacts.* (above)
# PROJECT_BASE = project base (see "Base directory for conventions.sources globs")
abs() { case "$1" in /*) echo "$1" ;; *) echo "${PROJECT_BASE}/$1" ;; esac; }
RUN_DIR=$(abs "$RUN_DIR"); REPORT_DIR=$(abs "$REPORT_DIR")
RUN="${RUN_DIR}/${RUN_ID}"
mkdir -p "$RUN"
printf '*\n' > "$RUN/.gitignore"   # run scratch never shows in git status
REPORT_PATH=""
if [ -n "$OUT_ARG" ]; then
  OUT_ARG=$(abs "$OUT_ARG")
  case "$OUT_ARG" in
    *.md|*.json) REPORT_PATH="$OUT_ARG" ;;
    *) REPORT_PATH="${OUT_ARG}/${STAMP}-${SKILL_SLUG}${SCOPE_SLUG:+-}${SCOPE_SLUG}.${EXT}" ;;
  esac
elif [ "$EXT" != json ]; then   # mode:agent without out: writes no file
  REPORT_PATH="${REPORT_DIR}/${STAMP}-${SKILL_SLUG}${SCOPE_SLUG:+-}${SCOPE_SLUG}.${EXT}"
fi
if [ -n "$REPORT_PATH" ]; then
  mkdir -p "$(dirname "$REPORT_PATH")"
  # The default report folder ignores itself; a folder the project chose does not.
  case "$(dirname "$REPORT_PATH")" in
    */.expectation-fit/reports) [ -f "$(dirname "$REPORT_PATH")/.gitignore" ] || printf '*\n' > "$(dirname "$REPORT_PATH")/.gitignore" ;;
  esac
fi
```

Bind **`run_artifact_dir = $RUN`** (not the published path) when filling `subagent-template.md`. Lenses write only under `$RUN`.

**After the report step** (the file write, or the JSON reply in `mode:agent` without
`out:`): if `artifacts.cleanup_runs` is true (default), delete the run scratch **only
after a safety check**:

```bash
# Only remove a path that is clearly a per-run scratch dir under the configured root.
# Require: non-empty, not repo root / ".", and under RUN_DIR with the expected RUN_ID suffix.
case "$RUN" in
  ""|"."|"/"|"$RUN_DIR"|"$RUN_DIR/") echo "cleanup skipped: unsafe RUN='$RUN'" ;;
  "$RUN_DIR"/"$RUN_ID") rm -rf "$RUN" ;;
  *) echo "cleanup skipped: RUN='$RUN' is not under RUN_DIR/RUN_ID" ;;
esac
```

Never `rm -rf` an unbound or mis-bound path. Always print the absolute report path to
the user: `Report: <absolute path>` (`Report: none (JSON reply only)` in `mode:agent`
without `out:`). Do not leave orphan lens JSON when cleanup succeeds.

**Scope exclusions:** never audit or review files under the resolved run dir, report
dir, or `out:` folder. `fit-review` and `fit-audit` load resolved config **before** they
build their file lists, and pass one exclude pathspec for each of those folders that is
inside the repo. A folder outside the repo gets no pathspec, so `git diff` never fails:

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
OUT_DIR="$OUT_ARG"; case "$OUT_ARG" in *.md|*.json) OUT_DIR=$(dirname "$OUT_ARG") ;; esac
EXCLUDES=()
for d in "$RUN_DIR" "$REPORT_DIR" ${OUT_DIR:+"$OUT_DIR"}; do
  case "$d" in /*) ;; *) d="${PROJECT_BASE}/$d" ;; esac   # same base as the canonical block
  case "$d" in "$REPO_ROOT"/?*) EXCLUDES+=(":(top,exclude)${d#"$REPO_ROOT"/}") ;; esac
done
# e.g. git diff --name-only "$BASE" -- "${EXCLUDES[@]}"
```

## Authority order for conventions

See **Authority order (what wins when sources disagree)** near the top of this file —
including `conventions.sources` between project YAML notes and `CLAUDE.md`/`AGENTS.md`,
and the project base for relative source globs. Do not use a shorter list here.

## External tool preference (`tools.architecture`)

Resolves like any scalar (project value replaces default; default `enrich`). It controls how
`fit-architecture-reviewer` treats an **installed** external static-analysis tool (reek/flog,
ruff/radon, phpstan/phpmd, eslint/madge, credo) so a team that already runs one
isn't given duplicate findings:

| Mode | Behavior |
|------|----------|
| `enrich` *(default)* | Run the plugin's heuristics **and** the tool; fold the tool's output as corroboration that raises confidence. (Today's behavior.) |
| `prefer` | Run the tool, map its findings to the findings schema, and **suppress the plugin's overlapping heuristic findings** (same file + unit + concern). No duplication; the tool wins where it speaks, heuristics cover the rest. |
| `report` | Run the tool and report **only its findings** (mapped to the schema); skip the plugin's own structural heuristics entirely. |
| `off` | Ignore external tools; plugin heuristics only. |

**Mapping (prefer/report):** the lens parses the tool's output and emits each finding through
`findings-schema.json` — deriving `smell`/`principle`, `severity`, a `confidence` of 100
(machine-confirmed), `file`/`line`, and a `fix`. Dedup against heuristic findings by
file+unit+concern. If the requested tool **isn't installed**, fall back to heuristics and note
in `observations` that the configured tool was absent (don't silently behave as `enrich`).
A lens set to `off` in `lenses.*` never runs regardless of `tools.*`.
