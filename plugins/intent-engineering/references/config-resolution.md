# Config Resolution

How `ie-*` skills and lenses load and merge the "ways of working" config. The config
lets a repo owner toggle lenses, override severities, set architecture thresholds, and
declare which design patterns are allowed / blocked / pre-approved.

## Locations (in precedence order)

1. **Project config** — `.intense/` at the **repo root** (read from the current working
   directory). Highest precedence. Committable, so the team shares one source of truth.
   Files: `.intense/ways-of-working.yaml`, `.intense/patterns.yaml`,
   `.intense/thresholds.yaml`.
2. **Global defaults** — `${CLAUDE_PLUGIN_ROOT}/config/defaults/`. Shipped with the
   plugin. Used for any key the project file doesn't set.

A project file need not be complete — it overrides only the keys it specifies; the rest
fall back to defaults.

## Loading procedure (orchestrator, before lens dispatch)

```bash
# project dir (repo root); fall back to cwd
PROJECT_INTENSE=".intense"
DEFAULTS="${CLAUDE_PLUGIN_ROOT}/config/defaults"
for f in ways-of-working patterns thresholds; do
  if [ -f "$PROJECT_INTENSE/$f.yaml" ]; then echo "project: $f"; else echo "default: $f"; fi
done
```

Read whichever file exists for each of the three configs; if the project file exists,
deep-merge it over the default per the rules below. Pass the resolved values to the
lenses in their spawn prompt (e.g. resolved thresholds to `ie-architecture-reviewer`,
resolved `conventions.notes` to `ie-convention-reviewer`, lens toggles to selection).

When no project `.intense/` exists at all, use defaults silently — the plugin works
out of the box. (Mention in Coverage which config source was used.)

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
| `severity_overrides` | synthesis | remap a finding's severity by principle/smell id |
| `conventions.notes` | `ie-convention-reviewer` | repo-authoritative conventions (alongside CLAUDE.md/AGENTS.md) |
| `confidence_gate` | synthesis | suppression anchor (default 75; P0 survives 50+) |
| `artifacts.run_dir` | skills | Layer A — per-run scratch for lens JSON (default `.intense/runs`) |
| `artifacts.report_dir` | skills | Layer B — published human report dir (default `docs/intent-engineering`) |
| `artifacts.cleanup_runs` | skills | delete the run dir after a successful publish (default `true`) |
| `report_dir` *(legacy)* | skills | if set **without** `artifacts:`, single-bucket mode (both layers under this path, `cleanup_runs: false`) |
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
3. **Legacy single-bucket:** if the project has top-level `report_dir:` and **no** `artifacts:` block, both layers use `report_dir/<run-id>/` and `cleanup_runs` is forced `false` (preserves pre-0.6 behavior for existing configs).

**Run id + published filename** (keep identical across the three orchestrators):

```bash
STAMP=$(date +%Y%m%d-%H%M%S)
RUN_ID="${STAMP}-$(head -c4 /dev/urandom | od -An -tx1 | tr -d ' ')"
# skill slug: audit | review | validate-plan
# SCOPE_SLUG: optional, sanitized path/branch fragment, or empty
RUN="${RUN_DIR}/${RUN_ID}"
mkdir -p "$RUN"
mkdir -p "$REPORT_DIR"
if [ -n "$OUT_ARG" ]; then
  case "$OUT_ARG" in
    *.md|*.json) REPORT_PATH="$OUT_ARG" ;;
    *) REPORT_PATH="${OUT_ARG}/${STAMP}-${SKILL_SLUG}${SCOPE_SLUG:+-}${SCOPE_SLUG}.${EXT}" ;;
  esac
else
  REPORT_PATH="${REPORT_DIR}/${STAMP}-${SKILL_SLUG}${SCOPE_SLUG:+-}${SCOPE_SLUG}.${EXT}"
fi
# EXT=md normally; json when mode:agent
mkdir -p "$(dirname "$REPORT_PATH")"
```

Bind **`run_artifact_dir = $RUN`** (not the published path) when filling `subagent-template.md`. Lenses write only under `$RUN`.

**After a successful write of `$REPORT_PATH`:** if `artifacts.cleanup_runs` is true (default), `rm -rf "$RUN"`. Always print the published path to the user: `Report: <path>`. Do not leave orphan lens JSON in the project tree when cleanup is on.

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
