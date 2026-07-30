# Config Resolution

How `ie-*` skills and lenses load and merge the "ways of working" config. The config
lets a repo owner toggle lenses, override severities, set architecture thresholds, and
declare which design patterns are allowed / blocked / pre-approved.

## Locations (in precedence order)

1. **Explicit override** (highest) — either of:
   - run argument `config:<path>` (directory that contains or *is* `.intense`, or a
     directory that holds `ways-of-working.yaml` / `patterns.yaml` / `thresholds.yaml`)
   - environment variable `INTENSE_CONFIG_DIR` (same path rules)
2. **Nearest project config** — the nearest `.intense/` directory found by **walking up**
   from the current working directory (see Discover procedure). Committable team config.
   Files: `ways-of-working.yaml`, `patterns.yaml`, `thresholds.yaml` inside that dir.
3. **Global defaults** — `${CLAUDE_PLUGIN_ROOT}/config/defaults/`. Shipped with the
   plugin. Used for any key the project file doesn't set.

A project file need not be complete — it overrides only the keys it specifies; the rest
fall back to defaults. To **materialize** new default capabilities into an existing
project file (visible in git, editable) without wiping notes, run `/ie-init upgrade`
(see `skills/ie-init/SKILL.md`).

## Authority order (what wins when sources disagree)

Descending authority for *conventions and judgment* (not only YAML merge). Single source
of truth — agents reference this section; do not invent a different order.

1. **Project config YAML** — resolved `.intense/*.yaml` fields (`conventions.notes`,
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
| Walk-up / path ends in `.intense` | Parent of that `.intense/` directory |
| `config:` / `INTENSE_CONFIG_DIR` is a dir that **is** `.intense` | Parent of that dir |
| `config:` / `INTENSE_CONFIG_DIR` is a dir that **contains** the three yaml files directly | That directory itself |
| Defaults only (no project config) | `$PWD` |

Absolute paths in `sources` are used as-is (no rebasing).

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
    exclude: []         # extra globs to drop (merged with defaults when present)
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
| `agents` | `AGENTS.md`, `CLAUDE.md`, `**/AGENTS.md`, `**/CLAUDE.md` |
| `copilot` | `.github/copilot-instructions.md`, `**/.github/copilot-instructions.md`, `**/copilot-instructions.md` |
| `instructions` | `.github/instructions/**`, `**/.github/instructions/**` |
| `workflows` (curated) | `.github/workflows/*.{yml,yaml}` that match **gate signals** (below) |
| `workflows` (all) | `.github/workflows/*.{yml,yaml}` (minus exclude) |

**Workflow gate signals** (`mode: curated` only) — keep a workflow if **any** hold:

- Filename contains: `rubocop`, `eslint`, `semgrep`, `callback`, `migration`, `secret`,
  `detect-secret`, `brakeman`, `lint`, `test`, `rspec`, `jest`, `playwright`, `contract`,
  `security`, `codeql`, `typecheck`, `tsc`, `prettier`, `danger`, `pr-title`
- File body (first ~80 lines) mentions: `pull_request:`, `bin/check`, `rubocop`, `eslint`,
  `semgrep`, `rspec`, `jest`, `playwright`, `strong_migrations`, `online_migrations`

Drop workflows that are clearly infra-only after exclude (labeler, terraform branch
create/delete, image deploy dispatch, renovate-only). When unsure in `curated`, **exclude**.

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

## Discover project `.intense/` (walk-up)

**Do not** bind project config only to `./.intense` relative to cwd. Nested checkouts
and monorepo workspaces often place cwd inside a sub-repo while the tuned config lives
at a parent workspace root. Silent fallback to defaults is the failure mode this
procedure prevents.

```bash
# Resolve PROJECT_INTENSE (directory containing at least one of the three yaml files)
# Precedence: config:<path> arg → INTENSE_CONFIG_DIR → walk-up → empty (defaults only)
has_intense_yaml() {
  [ -f "$1/ways-of-working.yaml" ] || [ -f "$1/patterns.yaml" ] || [ -f "$1/thresholds.yaml" ]
}

# Explicit path: succeed only when the resolved dir exists AND has at least one yaml.
# Never return a path that would label Coverage as project: while falling back to defaults.
resolve_explicit_config() {
  arg="$1"
  candidate=""
  case "$arg" in
    */.intense|.intense) candidate="$arg" ;;
    *) if [ -d "$arg/.intense" ]; then candidate="$arg/.intense"
       elif has_intense_yaml "$arg"; then candidate="$arg"
       fi ;;
  esac
  if [ -n "$candidate" ] && [ -d "$candidate" ] && has_intense_yaml "$candidate"; then
    echo "$candidate"
    return 0
  fi
  return 1
}

resolve_walk_up() {
  dir="$PWD"
  depth=0
  # Walk up to filesystem root (cap 32). Nearest `.intense` with at least one yaml wins.
  # Empty placeholder `.intense/` dirs are skipped (no project: without real config).
  while [ -n "$dir" ] && [ "$depth" -lt 32 ]; do
    if [ -d "$dir/.intense" ] && has_intense_yaml "$dir/.intense"; then
      echo "$dir/.intense"
      return 0
    fi
    [ "$dir" = "/" ] && break
    dir=$(dirname "$dir")
    depth=$((depth + 1))
  done
  return 1
}

PROJECT_INTENSE=""
CONFIG_SOURCE="defaults"
EXPLICIT="${CONFIG_ARG:-${INTENSE_CONFIG_DIR:-}}"
if [ -n "$EXPLICIT" ]; then
  if PROJECT_INTENSE=$(resolve_explicit_config "$EXPLICIT"); then
    CONFIG_SOURCE="project:$PROJECT_INTENSE"
  else
    # Invalid explicit path: defaults only; never claim project:
    CONFIG_SOURCE="defaults (invalid config path: $EXPLICIT)"
    PROJECT_INTENSE=""
  fi
else
  PROJECT_INTENSE=$(resolve_walk_up) || PROJECT_INTENSE=""
  [ -n "$PROJECT_INTENSE" ] && CONFIG_SOURCE="project:$PROJECT_INTENSE"
fi
DEFAULTS="${CLAUDE_PLUGIN_ROOT}/config/defaults"
# Always record for Coverage (required — never silent about source):
#   Config: project:/path/to/.intense (walked up from <cwd>)
#   Config: defaults (no .intense/ found, searched from <cwd> up to filesystem root)
#   Config: project:/path (via config: or INTENSE_CONFIG_DIR)
for f in ways-of-working patterns thresholds; do
  if [ -n "$PROJECT_INTENSE" ] && [ -f "$PROJECT_INTENSE/$f.yaml" ]; then
    echo "project: $f ($PROJECT_INTENSE/$f.yaml)"
  else
    echo "default: $f"
  fi
done
```

**Walk-up rules:**
- Start at `$PWD`; look for `$dir/.intense` at each level.
- Stop at the first match (**nearest wins**). A child repo with its own `.intense/`
  shadows a parent workspace.
- Continue past `.git` boundaries so a workspace-of-repos layout can share one
  `.intense/` at the workspace root when sub-repos have none.
- Cap walk depth at 32 parents.

Read whichever file exists for each of the three configs under `PROJECT_INTENSE`; if the
project file exists, deep-merge it over the default per the rules below. Pass the
resolved values to the lenses in their spawn prompt (e.g. resolved thresholds to
`ie-architecture-reviewer`, resolved `conventions.notes` / `conventions.sources` to
`ie-convention-reviewer`, lens toggles to selection).

When no project `.intense/` is found, use defaults — the plugin works out of the box.
**Always** put the config source line in Coverage (including when using defaults).

## Merge rules (project over global)

- **Scalars and maps** (e.g. `confidence_gate`, `lenses.*`, `thresholds.rails.model.max_loc`):
  the project value **replaces** the global value key-by-key. Keys the project omits
  keep the global value.
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
| `tools.architecture` | `ie-architecture-reviewer` | `enrich`/`prefer`/`report`/`off` — how the lens treats an installed external static-analysis tool (see below) |
| `severity_overrides` | synthesis | remap severity by principle/smell id (string or `{ severity, because }`). Applied **after** severity_align. |
| `severity_align` | synthesis | promote severity when a curated CI gate matches a finding theme (`mode: off\|curated_gates`). See Severity align with CI gates. |
| `conventions.notes` | `ie-convention-reviewer` | hand-authored repo rules (alongside CLAUDE.md/AGENTS.md) |
| `conventions.sources` | `ie-convention-reviewer` | explicit path globs for high-authority files. Resolve from project base. |
| `conventions.auto` | `ie-convention-reviewer` + audit | discover Copilot / instructions / PR-gate workflows (`mode: off\|curated\|all`). See Convention auto-sources. |
| `confidence_gate` | synthesis | suppression anchor (default 75; P0 survives 50+) |
| `artifacts.run_dir` | skills | Layer A — per-run scratch for lens JSON (default `.intense/runs`) |
| `artifacts.report_dir` | skills | Layer B — published human report dir (default `docs/intent-engineering`) |
| `artifacts.cleanup_runs` | skills | delete the run dir after a successful publish (default `true`) |
| `report_dir` *(legacy)* | skills | if set **without** `artifacts:`, run scratch under `report_dir/<run-id>/` and published report under `report_dir/<stamp>-…` (sibling of the run dir); `cleanup_runs: false` |
| `patterns.preferred/allowed/blocked/approved/unknown_pattern` | `ie-architecture-reviewer` | preferred-over (instead_of), classify, flag blocked-in-changed-code, suppress approved, raise unknown |
| `thresholds.*` | `ie-architecture-reviewer` | metric limits for structural smells |

## Artifact paths (orchestrators — shared)

Every `ie-review` / `ie-audit` / `ie-validate-plan` run uses **two layers**:

| Layer | What | Default |
|-------|------|---------|
| **A — run scratch** | `{lens}.json` while lenses run; ephemeral merge helpers | `.intense/runs/<run-id>/` |
| **B — published report** | one human-facing file (`*.md`, or `*.json` in `mode:agent`) | `docs/intent-engineering/<stamp>-<skill>[-scope].md` |

**Resolution order for the published path (Layer B):**

1. `out:<path>` on the skill invocation — if it ends in `.md` / `.json`, use as the file path; otherwise treat as a directory and place the default filename inside it. Outside-repo only when explicitly given.
2. Else resolved `artifacts.report_dir` (project `.intense/` over defaults).
3. Else built-in `docs/intent-engineering`.

**Resolution order for the run dir (Layer A):**

1. Resolved `artifacts.run_dir` (project over defaults).
2. Else built-in `.intense/runs`.
3. **Legacy single-bucket:** if the project has top-level `report_dir:` and **no**
   `artifacts:` block, run scratch uses `report_dir/<run-id>/` and the published report
   lands at `report_dir/<stamp>-<skill>[-scope].{md,json}` (a **sibling** of the run dir,
   not nested inside it). `cleanup_runs` is forced `false` (preserves pre-0.6 configs).

**Run id + published filename** — this block is the **canonical** orchestrator procedure.
`ie-review`, `ie-audit`, and `ie-validate-plan` **must not re-author it**; they only bind
slots (`SKILL_SLUG`, `SCOPE_SLUG`, `OUT_ARG`, `EXT`) and follow this block.

```bash
# CANONICAL_ORCHESTRATOR_PATHS — single source of truth (do not duplicate in skills)
STAMP=$(date +%Y%m%d-%H%M%S)
RUN_ID="${STAMP}-$(head -c4 /dev/urandom | od -An -tx1 | tr -d ' ')"
# skill slug: audit | review | validate-plan
# SCOPE_SLUG: optional, sanitized path/branch fragment, or empty
# EXT=md normally; json when mode:agent
# RUN_DIR / REPORT_DIR / CLEANUP already resolved from artifacts.* (above)
RUN="${RUN_DIR}/${RUN_ID}"
mkdir -p "$RUN"
if [ -n "$OUT_ARG" ]; then
  case "$OUT_ARG" in
    *.md|*.json) REPORT_PATH="$OUT_ARG" ;;
    *) REPORT_PATH="${OUT_ARG}/${STAMP}-${SKILL_SLUG}${SCOPE_SLUG:+-}${SCOPE_SLUG}.${EXT}" ;;
  esac
else
  REPORT_PATH="${REPORT_DIR}/${STAMP}-${SKILL_SLUG}${SCOPE_SLUG:+-}${SCOPE_SLUG}.${EXT}"
fi
mkdir -p "$(dirname "$REPORT_PATH")"
```

Bind **`run_artifact_dir = $RUN`** (not the published path) when filling `subagent-template.md`. Lenses write only under `$RUN`.

**After a successful write of `$REPORT_PATH`:** if `artifacts.cleanup_runs` is true
(default), delete the run scratch **only after a safety check**:

```bash
# Only remove a path that is clearly a per-run scratch dir under the configured root.
# Require: non-empty, not repo root / ".", and under RUN_DIR with the expected RUN_ID suffix.
case "$RUN" in
  ""|"."|"/"|"$RUN_DIR"|"$RUN_DIR/") echo "cleanup skipped: unsafe RUN='$RUN'" ;;
  "$RUN_DIR"/"$RUN_ID") rm -rf "$RUN" ;;
  *) echo "cleanup skipped: RUN='$RUN' is not under RUN_DIR/RUN_ID" ;;
esac
```

Never `rm -rf` an unbound or mis-bound path. Always print the published path to the user:
`Report: <path>`. Do not leave orphan lens JSON when cleanup succeeds.

**Scope exclusions:** never audit/review files under the resolved `artifacts.run_dir`, `artifacts.report_dir`, or legacy `report_dir` / `wip/` paths.

## Authority order for conventions

See **Authority order (what wins when sources disagree)** near the top of this file —
including `conventions.sources` between project YAML notes and `CLAUDE.md`/`AGENTS.md`,
and the project base for relative source globs. Do not use a shorter list here.

## External tool preference (`tools.architecture`)

Resolves like any scalar (project value replaces default; default `enrich`). It controls how
`ie-architecture-reviewer` treats an **installed** external static-analysis tool (reek/flog/
brakeman, ruff/radon, phpstan/phpmd, eslint/madge, credo) so a team that already runs one
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
