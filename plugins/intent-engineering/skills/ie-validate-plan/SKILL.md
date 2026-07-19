---
name: ie-validate-plan
description: "Validate a plan, spec, or requirements document against the four intent-engineering lenses before implementation — surfacing surprising designs, non-idiomatic or reinvented approaches, needless complexity/scope, and missing UX decisions (states, flows, IA, accessibility). Returns dimensional 0-10 ratings and the gaps to resolve first. Use when a plan or spec doc exists."
argument-hint: "[mode:agent] [out:<path>] [path/to/plan-or-spec.md]"
---

# Intent Engineering — Plan Validation

Reviews a *document* (plan, spec, or requirements) for the design decisions that, if
left surprising / non-idiomatic / over-complex / UX-incomplete, will derail
implementation. Catches the problem at the cheapest point — before code exists. Fans
out the four lenses in plan mode, each rating its dimensions 0-10 and naming the gaps.

## Argument parsing

| Token | Effect |
|-------|--------|
| `mode:agent` | Emit JSON; no interactive routing. |
| `out:<path>` | Override **published** report path (file or dir). Defaults: scratch `.intense/runs/<run-id>/`, publish `docs/intent-engineering/<stamp>-validate-plan[-scope].md`. |
| remainder | Path to the document. If omitted, find the most recent under `docs/plans/`, `docs/brainstorms/`; if none, ask once which file. |

## Stage 1 — Read & classify

Read the document. Classify by **content shape**, not path (path is a tie-breaker):

- **`requirements`** (what-to-build): actors, flows, acceptance examples, R/A/F IDs,
  user/business framing, no implementation units. A requirements doc may legitimately
  defer interaction mechanics to planning.
- **`plan`** (how-to-build): implementation units (U1, U2), per-unit files/approach/
  tests, technical decisions, sequencing. A plan that commits to building UI must
  enumerate the states.

Pass `Document type:` to every lens — it changes how strict each lens is (a
requirements doc is allowed to defer detail a plan must pin down).

## Stage 2 — Select lenses

First **load resolved config** per `${CLAUDE_PLUGIN_ROOT}/references/config-resolution.md`
(`.intense/*.yaml` over `config/defaults/`) — the `lenses:` toggles, `conventions`, and
`confidence_gate` apply here too. (The architecture lens is code-only and does not run
in plan validation.) Then read `${CLAUDE_PLUGIN_ROOT}/references/lens-catalog.md`.

- **Always-on:** predictability (does the proposed design behave as its names/contracts
  imply?), simplicity (is the scope/approach the simplest that meets the goal? building
  for hypothetical futures?).
- **convention:** on when the doc proposes structure/patterns/naming for a known stack
  or repo — does it reinvent what convention already provides? Read repo `CLAUDE.md`/
  `AGENTS.md` and the relevant `frameworks/<stack>.md`.
- **experience:** on when the doc describes any user-facing surface — assess described
  UX completeness (interaction states, user flows, IA, accessibility commitments,
  AI-slop risk).

Announce the team.

## Stage 3 — Dispatch

Resolve artifact paths per `${CLAUDE_PLUGIN_ROOT}/references/config-resolution.md`
(Artifact paths). Shared procedure (skill slug `validate-plan`):

```bash
STAMP=$(date +%Y%m%d-%H%M%S)
RUN_ID="${STAMP}-$(head -c4 /dev/urandom | od -An -tx1 | tr -d ' ')"
OUT_ARG="<out: value or empty>"
RUN_DIR="<artifacts.run_dir or legacy single-bucket or .intense/runs>"
REPORT_DIR="<artifacts.report_dir or legacy or docs/intent-engineering>"
CLEANUP="<artifacts.cleanup_runs; false if legacy single-bucket; default true>"
SKILL_SLUG="validate-plan"
SCOPE_SLUG="<sanitized plan basename or empty>"
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

Spawn lenses in parallel with `Context: plan` and the `Document type:`. **Bind
`run_artifact_dir = $RUN`** (Layer A only). Pass `model: sonnet` to convention
and experience; let predictability and simplicity inherit the session model (their
frontmatter default) — don't spawn the always-on lenses as `sonnet`. Plan mode requires
`scores`
(dimensional rating per the scoring rubric) plus findings that cite the doc location
(`line` = the relevant section's start line, or 0 when none applies) and describe the
gap a planner/implementer would hit. Lenses write `$RUN/{lens}.json` (via the Write
tool).

## Stage 4 — Merge & rate

1. Validate, dedup, confidence-gate (as `ie-review` Stage 5; no apply — it's a doc).
2. Build the dimensional rating table (scoring rubric): `Lens | Dimension | Score |
   Gap`, lowest first. Findings ≤ 7/10 dimensions become actionable gaps.
3. Collect tensions (e.g. simplicity vs convention in the proposed approach) and
   observations.

## Stage 5 — Report

Write the published report to `$REPORT_PATH` (markdown, or JSON in `mode:agent`) per
`${CLAUDE_PLUGIN_ROOT}/references/report-template.md`. Put `run_id` in the Header. Sections: Header (doc,
type, lens team, run_id), Dimensional Ratings (worst first), Findings/Gaps grouped by severity
with `Principle` + `Lens`, Tensions, Observations, Coverage, Verdict = **Ready to
implement / Revise first**, listing the blocking gaps to resolve before coding. The
verdict blocks on `requirements`-level or design-blocking gaps; advisory gaps are noted
but don't block. No time estimates.

Then: if `CLEANUP` is true, run the **guarded** cleanup from
`${CLAUDE_PLUGIN_ROOT}/references/config-resolution.md` (only when
`$RUN` equals `$RUN_DIR/$RUN_ID`). Always tell the user `Report: $REPORT_PATH`.

This skill never edits the document — it reports. (To apply edits, hand the report to
the planning workflow.)

---

## Reference files (read at runtime)

Depends on `${CLAUDE_PLUGIN_ROOT}` resolving (standard in Claude Code). Read before
Stage 2 — shared contract for every `ie-*` skill:

- `${CLAUDE_PLUGIN_ROOT}/references/config-resolution.md` — load/merge .intense config
- `${CLAUDE_PLUGIN_ROOT}/references/lens-catalog.md`
- `${CLAUDE_PLUGIN_ROOT}/references/subagent-template.md`
- `${CLAUDE_PLUGIN_ROOT}/references/scoring-rubric.md` — dimensional rating
- `${CLAUDE_PLUGIN_ROOT}/references/findings-schema.json`
- `${CLAUDE_PLUGIN_ROOT}/references/report-template.md`
