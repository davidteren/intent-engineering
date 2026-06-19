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
| `report_dir` | skills | default run-artifact dir (still overridable with `out:`) |
| `patterns.allowed/blocked/approved/unknown_pattern` | `ie-architecture-reviewer` | classify, flag blocked-in-changed-code, suppress approved, raise unknown |
| `thresholds.*` | `ie-architecture-reviewer` | metric limits for structural smells |

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
