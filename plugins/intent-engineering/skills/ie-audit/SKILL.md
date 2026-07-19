---
name: ie-audit
description: "Audit a whole codebase, subsystem, or feature against the intent-engineering lenses (predictability, convention, simplicity, experience, and architecture on supported frameworks) and produce a posture report — per-dimension 0-10 scores plus the top surprise/convention/complexity/UX/structural gaps. Use to assess an existing codebase or area, not a specific diff. Sampling-aware for large targets."
argument-hint: "[mode:agent] [out:<path>] [<path/glob/subsystem to audit, default: whole repo>]"
---

# Intent Engineering — Codebase Audit

Assesses the intent-engineering posture of existing code (no diff). Where
`ie-review` judges a change, `ie-audit` judges a body of code: how predictable,
conventional, simple, and usable it is today, scored per dimension with the worst gaps
surfaced first. This is a read-only assessment — it never edits code.

## Argument parsing

| Token | Effect |
|-------|--------|
| `mode:agent` | Emit JSON instead of markdown. |
| `out:<path>` | Override **published** report path (file or dir). Defaults: scratch `.intense/runs/<run-id>/`, publish `docs/intent-engineering/<stamp>-audit[-scope].md`. |
| remainder | Path, glob, or named subsystem/feature to audit. Default: the repo (excluding deps, build output, generated, and vendored dirs). |

## Stage 1 — Scope the target

Resolve the audit set. Be explicit and bounded:

1. Determine the file set: the given path/glob, or the repo's source dirs. Exclude
   `node_modules`, `vendor`, `dist`/`build`, generated files, lockfiles, and
   artifact dirs (resolved `artifacts.run_dir`, `artifacts.report_dir`, legacy
   `wip/`, `.intense/runs/`, `docs/intent-engineering/`).
2. Detect the stack(s) by extension/manifest to pick `frameworks/<stack>.md` docs.
3. **Sampling rule (large targets).** If the set exceeds what lenses can read closely
   (rough guide: > ~40 files or very large files), select a representative sample:
   the highest-churn / largest / most-depended-on files plus the public entry points
   and a cross-section of each layer. **State the sampling explicitly** — what was and
   wasn't covered goes in Coverage. Never silently truncate and imply full coverage.

## Stage 2 — Select lenses

First **load resolved config** per `${CLAUDE_PLUGIN_ROOT}/references/config-resolution.md`
(`.intense/*.yaml` over `config/defaults/`); the `lenses:` toggles are authoritative,
and `thresholds` + pattern policy feed the architecture lens. Note the source in
Coverage. Then read `${CLAUDE_PLUGIN_ROOT}/references/lens-catalog.md`.

- Predictability + simplicity always on.
- Convention on when stack/repo standards exist.
- Experience on only if the target has user-facing surfaces.
- **Architecture on when a supported framework is detected** (Rails: `Gemfile` + `app/`
  structure; Python: `pyproject.toml`/`setup.py` + `.py` sources). This is the lens that
  audits fat models/routers, God objects/modules, misused services, business logic in
  schemas, layer leaks, and classifies/raises patterns — usually the highest-value pass in
  a codebase audit. Pass it the resolved `thresholds` + pattern policy + the
  `tools.architecture` preference (`enrich`/`prefer`/`report`/`off`).

Honor config `lenses:` toggles over these defaults. Find repo `CLAUDE.md`/`AGENTS.md`
+ `.intense` conventions for the convention and architecture lenses. Announce the team.

## Stage 3 — Dispatch

Resolve artifact paths per `${CLAUDE_PLUGIN_ROOT}/references/config-resolution.md`
(Artifact paths). Shared procedure (skill slug `audit`):

```bash
STAMP=$(date +%Y%m%d-%H%M%S)
RUN_ID="${STAMP}-$(head -c4 /dev/urandom | od -An -tx1 | tr -d ' ')"
# From Stage 2 config + Argument parsing (see config-resolution.md):
OUT_ARG="<out: value or empty>"
RUN_DIR="<artifacts.run_dir or legacy single-bucket or .intense/runs>"
REPORT_DIR="<artifacts.report_dir or legacy or docs/intent-engineering>"
CLEANUP="<artifacts.cleanup_runs; false if legacy single-bucket; default true>"
SKILL_SLUG="audit"
SCOPE_SLUG="<sanitized target slug or empty>"
EXT="md"   # json when mode:agent
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

Spawn lenses in parallel with `Context: audit` (subagent template). **Bind
`run_artifact_dir = $RUN`** (Layer A only). Pass `model: sonnet` to convention,
experience, and architecture; let predictability and simplicity inherit the session model
(their frontmatter default) — don't spawn the always-on lenses as `sonnet`. Pass the file
set (or sample) and the stack docs to read. **Audit mode requires `scores`** — each lens returns 0-10 per
dimension it owns (scoring rubric) plus findings citing `file:line`. Respect the
concurrency cap. Lenses write `$RUN/{lens}.json` (via the Write tool).

For very large audits, a lens may itself fan out across file groups; the orchestrator
just needs the merged per-lens return.

## Stage 4 — Merge & score

1. Validate, dedup, confidence-gate (resolved `confidence_gate`, default 75; P0 at 50+
   survives) and apply config policy (severity_overrides; suppress `approved` paths;
   keep `blocked`-pattern findings) as in `ie-review` Stage 5 (no apply — audit is
   read-only).
2. Assemble the **posture table** from each lens's `scores` (read
   `${CLAUDE_PLUGIN_ROOT}/references/scoring-rubric.md`): `Lens | Dimension | Score |
   Gap`, lowest scores first. Do not average into one number — the gaps are the
   product.
3. Collect tensions and observations.

## Stage 5 — Report

Write the published report to `$REPORT_PATH` (markdown, or JSON in `mode:agent`) per
`${CLAUDE_PLUGIN_ROOT}/references/report-template.md`. Put `run_id` in the Header. Sections: Header (target,
stack, sampling note, run_id), Posture table (worst first), Findings (P0..P3, grouped, with
`Principle` + `Lens`), Tensions, Observations, Coverage (sampling bounds, suppressions,
failed lenses), Verdict = the **top 3 posture gaps to fix first** with why. No apply,
no push, no time estimates.

Then: if `CLEANUP` is true, run the **guarded** cleanup from
`${CLAUDE_PLUGIN_ROOT}/references/config-resolution.md` (only `rm -rf` when
`$RUN` equals `$RUN_DIR/$RUN_ID`). Always tell the user `Report: $REPORT_PATH`.

---

## Reference files (read at runtime)

Depends on `${CLAUDE_PLUGIN_ROOT}` resolving (standard in Claude Code). Read before
Stage 2 — shared contract for every `ie-*` skill:

- `${CLAUDE_PLUGIN_ROOT}/references/config-resolution.md` — load/merge .intense config
- `${CLAUDE_PLUGIN_ROOT}/references/lens-catalog.md`
- `${CLAUDE_PLUGIN_ROOT}/references/subagent-template.md`
- `${CLAUDE_PLUGIN_ROOT}/references/scoring-rubric.md` — audit scoring
- `${CLAUDE_PLUGIN_ROOT}/references/findings-schema.json`
- `${CLAUDE_PLUGIN_ROOT}/references/report-template.md`
