---
name: fit-validate-plan
description: "Validate a plan, spec, or requirements document against the four expectation-fit lenses before implementation — surfacing surprising designs, non-idiomatic or reinvented approaches, needless complexity/scope, and missing UX decisions (states, flows, IA, accessibility). Returns dimensional 0-10 ratings and the gaps to resolve first. Use when a plan or spec doc exists. Run it on the final plan text, after any document review (for example ce-doc-review) and before implementation. It does not replace a document review."
argument-hint: "[mode:agent] [out:<path>] [lenses:<list>] [prior:<report-path>] [path/to/plan-or-spec.md ...]"
---

# Expectation Fit — Plan Validation

Reviews a *document* (plan, spec, or requirements) for the design decisions that, if
left surprising / non-idiomatic / over-complex / UX-incomplete, will derail
implementation. Catches the problem at the cheapest point — before code exists. Fans
out the four lenses in plan mode, each rating its dimensions 0-10 and naming the gaps.

## Argument parsing

| Token | Effect |
|-------|--------|
| `mode:agent` | Emit JSON; no interactive routing. Writes a report file only with `out:`. |
| `out:<path>` | Override the report path (file or dir). Pass a folder. A file name skips the stamp and can overwrite an earlier report. Default paths: `${CLAUDE_PLUGIN_ROOT}/references/config-resolution.md` (Artifact paths). |
| `prior:<report-path>` | Earlier report of the same target. Its `fixed` and `declined` rows go to every lens through the `<prior>` slot (subagent-template). Turns the run into a re-check: each prior gap is marked closed or still open. |
| `config:<path>` | Override project config directory (walk-up / `EXPECTATION_FIT_CONFIG_DIR` otherwise). |
| `lenses:<list>` | Run only these lenses, comma-separated (e.g. `lenses:predictability,simplicity`). Overrides auto-selection and the config `lenses:` toggles for this run. Config, merge, gate and report still run. Coverage marks each other lens `not_selected` (not requested). |
| remainder | Path to the document, or several paths. Several paths form one set: one run, one report, with one flow per document inside it. If omitted, find the most recent under `docs/plans/`, `docs/brainstorms/`; if none, ask once which file. |

If you get several documents, one run accepts the whole set: one run id and one report.
Inside that run, run one flow per document: one lens dispatch per document and one
report section per document. Never put two documents in one lens dispatch.

## Stage 1 — Read & classify

Read each document. Classify each one by **content shape**, not path (path is a
tie-breaker):

- **`requirements`** (what-to-build): actors, flows, acceptance examples, R/A/F IDs,
  user/business framing, no implementation units. A requirements doc may legitimately
  defer interaction mechanics to planning.
- **`plan`** (how-to-build): implementation units (U1, U2), per-unit files/approach/
  tests, technical decisions, sequencing. A plan that commits to building UI must
  enumerate the states.

Pass `Document type:` to every lens, per document. It changes how strict each lens is
(a requirements doc is allowed to defer detail a plan must pin down). For a set, each
document's dispatch also lists the paths of the other documents in the set, so the lens
can flag a conflict across documents.

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

A `lenses:<list>` token wins over the toggles and these rules. Pass repo
`CLAUDE.md`/`AGENTS.md` paths (`<standards-paths>`) and the resolved
`conventions.notes` to every selected lens. Keep `conventions.sources` and
`conventions.auto` with the convention lens only. Announce the team.

## Stage 3 — Dispatch

Resolve artifact paths per `${CLAUDE_PLUGIN_ROOT}/references/config-resolution.md`
(Artifact paths). Bind skill slots only:

| Slot | Value |
|------|--------|
| `SKILL_SLUG` | `validate-plan` |
| `SCOPE` | raw plan path (the first one, with `-set` appended for several; the canonical block makes the slug), or empty |
| `OUT_ARG` | `out:` value or empty |
| `EXT` | `md` normally; `json` when `mode:agent` |

Run the **canonical** stamp / `RUN_ID` / `REPORT_PATH` procedure from that doc. Bind
`run_artifact_dir = $RUN` (Layer A only), `repo_root` to `git rev-parse --show-toplevel`,
and `plugin_root = $PLUGIN_ROOT`.

Spawn lenses in parallel with `Context: plan` and the `Document type:`. **Model
policy:** pass `model: sonnet` to convention and experience; let predictability and
simplicity inherit the session model — don't spawn the always-on lenses as `sonnet`.
Plan mode requires `scores` (dimensional rating per the scoring rubric) plus findings
that cite the doc location (`file` = the document path; `line` = the exact plan line of
the evidence quote, or 0 when none applies) and describe the gap a planner/implementer
would hit. For a set, each lens returns one flat `scores` object per document dispatch. Missing required
`scores` → lens **failed**. Lenses write `$RUN/{lens}.json` (via the Write tool).

With `prior:`, fill the `<prior>` slot with the prior gaps and its two plan rules: mark
each prior gap closed or still open, with its plan line; drop a score only when the lens
names the new gap. Lenses still read the whole plan and can raise new gaps.

## Stage 4 — Merge & rate

1. Run **Merge and gate** in `${CLAUDE_PLUGIN_ROOT}/references/report-template.md`
   with Context: plan, once per document. No apply, because the input is a doc. In its
   step 1, before dedup, grep the document for the first line of each evidence quote
   (`grep -n -F`) and set `line` from the hit; with no hit, list the line as unverified
   in Coverage.
2. Build the dimensional rating table (scoring rubric) from lenses with status
   `clean` or `ok`: `Lens | Dimension | Score | Prior | Gap`, lowest first (`Prior` is
   the score from the `prior:` report, or `-`). Findings ≤ 7/10 dimensions become
   actionable gaps.
3. Collect tensions (e.g. simplicity vs convention in the proposed approach) and
   observations.

## Stage 5 — Report

Write the report to `$REPORT_PATH` (markdown; in `mode:agent`, the JSON reply, written to a file only with `out:`) per
`${CLAUDE_PLUGIN_ROOT}/references/report-template.md`. Sections: Header (per
report-template, with the Provenance line; each doc with its type), Dimensional Ratings (worst first), Findings/Gaps grouped by severity
with `Principle` + `Lens`, Tensions, Observations, Coverage (each lens status per the report-template Lens status table;
when `git rev-list --count HEAD..@{u}` is above zero, add `Checkout is N commits behind
<upstream> as of last fetch. Code facts may be stale.` Never run `git fetch`),
Verdict = **Ready to implement / Revise first** with lens coverage (report-template
Verdict), listing the blocking gaps to resolve before coding. For a set, give each
document its own section with its Dimensional Ratings, Findings/Gaps and Tensions; the
Header, Coverage and Verdict cover the whole set. The Header carries `plan_sha256`
(`shasum -a 256 <plan> | cut -c1-64`, one per document), and with `prior:` also
`supersedes: <prior report>` and the round (the prior round plus one; round 1 without
`prior:`).

The verdict is **Revise first** when any P0 or P1 survives the confidence gate in any
document of the set, or when a lens status or a partial read blocks it (see the
report-template Lens status table). Otherwise it is **Ready to implement**. P2 and P3
gaps do not block. No time estimates.

Caller checks: if the request lists must-hold checks, keep them out of the lens prompts.
After the merge, rate each check as pass, fail or not addressed, with the plan line. Show
the results as a `Check | Result` table in Coverage. A failed check is also a finding
with its own severity.

Then: if `CLEANUP` is true, run the **guarded** cleanup from
`${CLAUDE_PLUGIN_ROOT}/references/config-resolution.md` (only when
`$RUN` equals `$RUN_DIR/$RUN_ID`). End a markdown reply with this line, where `Blocking`
counts the P0 and P1 findings that survive the gate, and the report path is the absolute
path from the `Report:` line in that doc:

```text
Verdict: <verdict>. Lowest score: <n>/10. Blocking: <n>. Failed lenses: <names or none>. Report: $REPORT_PATH
```

This skill never edits the document — it reports. (To apply edits, hand the report to
the planning workflow.)

## Fallback

No sub-agents: follow "When you cannot spawn agents" in
`${CLAUDE_PLUGIN_ROOT}/references/subagent-template.md`. Concurrency cap: use the queue/
backfill rule. Everything else unchanged.

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

**Plugin root.** `PLUGIN_ROOT` is the absolute path two folders above this file's
folder. Bind it as `{plugin_root}` in every lens prompt (subagent-template, Slot
bindings), so no lens prompt carries a literal plugin-root variable.
