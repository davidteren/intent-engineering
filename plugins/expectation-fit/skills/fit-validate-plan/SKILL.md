---
name: fit-validate-plan
description: "Validate a plan, spec, or requirements document against the four expectation-fit lenses before implementation — surfacing surprising designs, non-idiomatic or reinvented approaches, needless complexity/scope, and missing UX decisions (states, flows, IA, accessibility). Returns dimensional 0-10 ratings and the gaps to resolve first. Use when a plan or spec doc exists. Run it on the final plan text, after any document review (for example ce-doc-review) and before implementation. It does not replace a document review."
argument-hint: "[mode:agent] [out:<path>] [path/to/plan-or-spec.md]"
---

# Expectation Fit — Plan Validation

Reviews a *document* (plan, spec, or requirements) for the design decisions that, if
left surprising / non-idiomatic / over-complex / UX-incomplete, will derail
implementation. Catches the problem at the cheapest point — before code exists. Fans
out the four lenses in plan mode, each rating its dimensions 0-10 and naming the gaps.

## Argument parsing

| Token | Effect |
|-------|--------|
| `mode:agent` | Emit JSON; no interactive routing. |
| `out:<path>` | Override **published** report path (file or dir). Defaults: scratch `.expectation-fit/runs/<run-id>/`, publish `docs/expectation-fit/<stamp>-validate-plan[-scope].md`. |
| `config:<path>` | Override project config directory (walk-up / `EXPECTATION_FIT_CONFIG_DIR` otherwise). |
| remainder | Path to the document. If omitted, find the most recent under `docs/plans/`, `docs/brainstorms/`; if none, ask once which file. |

If you get several documents, run the full flow once for each one. Each run gets its own
run id and report. Never put two documents in one lens dispatch.

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
(walk-up / `config:` / `EXPECTATION_FIT_CONFIG_DIR`, then merge over `config/defaults/`) — the
`lenses:` toggles, `conventions`, and `confidence_gate` apply here too. **Always** state
Config source in Coverage. (The architecture lens is code-only and does not run in plan
validation.) Then read `${CLAUDE_PLUGIN_ROOT}/references/lens-catalog.md`.

- **Always-on:** predictability (does the proposed design behave as its names/contracts
  imply?), simplicity (is the scope/approach the simplest that meets the goal? building
  for hypothetical futures?).
- **convention:** on when the doc proposes structure/patterns/naming for a known stack
  or repo — does it reinvent what convention already provides? Read repo `CLAUDE.md`/
  `AGENTS.md` and the relevant `frameworks/<stack>.md`.
- **experience:** on when the scope touches a surface in the `lens-catalog.md` list —
  assess described UX completeness (interaction states, user flows, IA, accessibility commitments,
  AI-slop risk).

Pass repo `CLAUDE.md`/`AGENTS.md` paths (`<standards-paths>`) and the resolved
`conventions.notes` to every selected lens. Keep `conventions.sources` and
`conventions.auto` with the convention lens only. Announce the team.

## Stage 3 — Dispatch

Resolve artifact paths per `${CLAUDE_PLUGIN_ROOT}/references/config-resolution.md`
(Artifact paths). Bind skill slots only:

| Slot | Value |
|------|--------|
| `SKILL_SLUG` | `validate-plan` |
| `SCOPE_SLUG` | sanitized plan basename, or empty |
| `OUT_ARG` | `out:` value or empty |
| `EXT` | `md` normally; `json` when `mode:agent` |

Run the **canonical** stamp / `RUN_ID` / `REPORT_PATH` procedure from that doc. Bind
`run_artifact_dir = $RUN` (Layer A only) and `repo_root` to `git rev-parse --show-toplevel`.

Spawn lenses in parallel with `Context: plan` and the `Document type:`. **Model
policy:** pass `model: sonnet` to convention and experience; let predictability and
simplicity inherit the session model — don't spawn the always-on lenses as `sonnet`.
Plan mode requires `scores` (dimensional rating per the scoring rubric) plus findings
that cite the doc location (`line` = the relevant section's start line, or 0 when none
applies) and describe the gap a planner/implementer would hit. Missing required
`scores` → lens **failed**. Lenses write `$RUN/{lens}.json` (via the Write tool).

## Stage 4 — Merge & rate

1. Validate, assign per-lens status (failed / skipped / clean), dedup, confidence-gate
   (as `fit-review` Stage 5; no apply — it's a doc).
2. Build the dimensional rating table (scoring rubric) from **clean** lenses: `Lens |
   Dimension | Score | Gap`, lowest first. Findings ≤ 7/10 dimensions become
   actionable gaps.
3. Collect tensions (e.g. simplicity vs convention in the proposed approach) and
   observations.

## Stage 5 — Report

Write the published report to `$REPORT_PATH` (markdown, or JSON in `mode:agent`) per
`${CLAUDE_PLUGIN_ROOT}/references/report-template.md`. Put `run_id` in the Header. Sections: Header (doc,
type, lens team, run_id), Dimensional Ratings (worst first), Findings/Gaps grouped by severity
with `Principle` + `Lens`, Tensions, Observations, Coverage (each lens failed/skipped/clean),
Verdict = **Ready to implement / Revise first**, listing the blocking gaps to resolve
before coding. The verdict is **Revise first** when any P0 or P1 survives the confidence
gate, or any selected lens **failed**. Otherwise it is **Ready to implement**. P2 and P3
gaps do not block. No time estimates.

Caller checks: if the request lists must-hold checks, keep them out of the lens prompts.
After the merge, rate each check as pass, fail or not addressed, with the plan line. Show
the results as a `Check | Result` table in Coverage. A failed check is also a finding
with its own severity.

Then: if `CLEANUP` is true, run the **guarded** cleanup from
`${CLAUDE_PLUGIN_ROOT}/references/config-resolution.md` (only when
`$RUN` equals `$RUN_DIR/$RUN_ID`). End a markdown reply with this line, where `Blocking`
counts the P0 and P1 findings that survive the gate:

```text
Verdict: <verdict>. Lowest score: <n>/10. Blocking: <n>. Failed lenses: <names or none>. Report: $REPORT_PATH
```

This skill never edits the document — it reports. (To apply edits, hand the report to
the planning workflow.)

---

## Reference files (read at runtime)

Depends on `${CLAUDE_PLUGIN_ROOT}` resolving (standard in Claude Code). Read before
Stage 2 — shared contract for every `fit-*` skill:

- `${CLAUDE_PLUGIN_ROOT}/references/config-resolution.md` — load/merge .expectation-fit config
- `${CLAUDE_PLUGIN_ROOT}/references/lens-catalog.md`
- `${CLAUDE_PLUGIN_ROOT}/references/subagent-template.md`
- `${CLAUDE_PLUGIN_ROOT}/references/scoring-rubric.md` — dimensional rating
- `${CLAUDE_PLUGIN_ROOT}/references/findings-schema.json`
- `${CLAUDE_PLUGIN_ROOT}/references/report-template.md`
