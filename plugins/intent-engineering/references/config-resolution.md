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
fall back to defaults.

## Authority order (what wins when sources disagree)

Descending authority for *conventions and judgment* (not only YAML merge):

1. **Project `.intense/*.yaml`** (including `conventions.notes`, pattern policy, thresholds,
   severity overrides) — highest for plugin config.
2. **Repo instruction docs** — `CLAUDE.md` / `AGENTS.md` (and paths listed under
   `conventions.sources`).
3. **Sibling code** — established patterns in the same tree.
4. **Plugin defaults / framework docs** under `${CLAUDE_PLUGIN_ROOT}/` — lowest.

Within conventions specifically: **`notes` beat `sources`** when both speak. YAML merge
(project over `config/defaults/`) is separate and described under Merge rules.

## Discover project `.intense/` (walk-up)

**Do not** bind project config only to `./.intense` relative to cwd. Nested checkouts
and monorepo workspaces often place cwd inside a sub-repo while the tuned config lives
at a parent workspace root. Silent fallback to defaults is the failure mode this
procedure prevents.

```bash
# Resolve PROJECT_INTENSE (directory containing the three yaml files)
# Precedence: config:<path> arg → INTENSE_CONFIG_DIR → walk-up → empty (defaults only)
resolve_intense_dir() {
  if [ -n "$CONFIG_ARG" ]; then
    case "$CONFIG_ARG" in
      */.intense|.intense) echo "$CONFIG_ARG" ;;
      *) if [ -d "$CONFIG_ARG/.intense" ]; then echo "$CONFIG_ARG/.intense"
         elif [ -f "$CONFIG_ARG/ways-of-working.yaml" ] || [ -f "$CONFIG_ARG/patterns.yaml" ] || [ -f "$CONFIG_ARG/thresholds.yaml" ]; then echo "$CONFIG_ARG"
         else echo "$CONFIG_ARG/.intense"; fi ;;
    esac
    return
  fi
  if [ -n "${INTENSE_CONFIG_DIR:-}" ]; then
    CONFIG_ARG="$INTENSE_CONFIG_DIR"
    resolve_intense_dir
    return
  fi
  dir="$PWD"
  depth=0
  # Walk up to filesystem root (cap 32). Nearest `.intense` wins — a sub-repo with
  # its own config shadows a parent workspace; a sub-repo *without* one inherits the
  # parent workspace's config (the multi-repo workspace case).
  while [ -n "$dir" ] && [ "$depth" -lt 32 ]; do
    if [ -d "$dir/.intense" ]; then
      echo "$dir/.intense"
      return
    fi
    [ "$dir" = "/" ] && break
    dir=$(dirname "$dir")
    depth=$((depth + 1))
  done
  return 1
}

PROJECT_INTENSE=$(resolve_intense_dir) || PROJECT_INTENSE=""
DEFAULTS="${CLAUDE_PLUGIN_ROOT}/config/defaults"
CONFIG_SOURCE="defaults"
[ -n "$PROJECT_INTENSE" ] && CONFIG_SOURCE="project:$PROJECT_INTENSE"
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
- **Lists** (e.g. `conventions.notes`, `patterns.allowed/blocked/approved`): the project
  list **replaces** the global list — **unless** the owning block sets `extends: true`,
  in which case the project list is **appended** to the global list. Default is replace
  (least-astonishing: what you write in the project file is what you get). Only blocks that
  expose an `extends` flag support append: the `conventions` block does; the
  `patterns.allowed/blocked/approved` lists are **replace-only** (no `extends` knob), so a
  project `patterns.yaml` list fully replaces the default — list every entry you want.
- **`version`**: informational; if a project file's `version` is higher than the plugin
  understands, note it in Coverage and proceed best-effort.

## How the resolved config is used

| Config | Consumer | Effect |
|--------|----------|--------|
| `lenses.*` | skill lens-selection | `on`/`off`/`auto` decides which lenses run (turn an agent off here) |
| `tools.architecture` | `ie-architecture-reviewer` | `enrich`/`prefer`/`report`/`off` — how the lens treats an installed external static-analysis tool (see below) |
| `severity_overrides` | synthesis | remap a finding's severity by principle/smell id. Values may be a severity string (`P1`) or a map `{ severity: P1, because: "…" }` (the `because` string is copied into Coverage / Observations) |
| `conventions.notes` | `ie-convention-reviewer` | hand-authored repo rules (alongside CLAUDE.md/AGENTS.md) |
| `conventions.sources` | `ie-convention-reviewer` | list of path globs (relative to the discovered project root parent of `.intense/`, or cwd) whose files are high-authority convention sources — review-bot instruction packs, engineering standards, CI policy docs. Read them after CLAUDE.md/AGENTS.md; **notes still win** over sources when both speak (project config is highest) |
| `confidence_gate` | synthesis | suppression anchor (default 75; P0 survives 50+) |
| `artifacts.run_dir` | skills | Layer A — per-run scratch for lens JSON (default `.intense/runs`) |
| `artifacts.report_dir` | skills | Layer B — published human report dir (default `docs/intent-engineering`) |
| `artifacts.cleanup_runs` | skills | delete the run dir after a successful publish (default `true`) |
| `report_dir` *(legacy)* | skills | if set **without** `artifacts:`, run scratch under `report_dir/<run-id>/` and published report under `report_dir/<stamp>-…` (sibling of the run dir); `cleanup_runs: false` |
| `patterns.allowed/blocked/approved/unknown_pattern` | `ie-architecture-reviewer` | classify, flag blocked-in-changed-code, suppress approved, raise unknown |
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

When the convention/architecture lenses judge "is this how this repo does things?", the
authority order is:

1. `.intense/*.yaml` (explicit, structured) — highest
2. Repo `CLAUDE.md` / `AGENTS.md` (prose standards)
3. Existing sibling code (de-facto convention)
4. Plugin defaults + framework docs (`resources/frameworks/*`) — lowest

A higher source overrides a lower one. A consistent repo-local choice is never a
violation, even when it differs from the framework norm.

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
