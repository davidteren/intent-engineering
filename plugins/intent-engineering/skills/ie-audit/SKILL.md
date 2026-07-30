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
| `config:<path>` | Override project config directory (walk-up / `INTENSE_CONFIG_DIR` otherwise). |
| remainder | Path, glob, or named subsystem/feature to audit. Default: the repo (excluding deps, build output, generated, and vendored dirs). |

## Stage 1 — Scope the target

Resolve the audit set. Be explicit and bounded:

1. Determine the file set: the given path/glob, or the repo's source dirs. Exclude
   `node_modules`, `vendor`, `dist`/`build`, generated files, lockfiles, and
   artifact dirs (resolved `artifacts.run_dir`, `artifacts.report_dir`, legacy
   `wip/`, `.intense/runs/`, `docs/intent-engineering/`).
2. Detect the stack(s) via `${CLAUDE_PLUGIN_ROOT}/references/stack-catalog.md`
   (Detection signals); load matching `frameworks/<stack>.md` docs. Do not hardcode a
   closed stack list.
3. **Sampling rule (large targets).** If the set exceeds what lenses can read closely
   (rough guide: > ~40 files or very large files), select a representative sample:
   the highest-churn / largest / most-depended-on files plus the public entry points
   and a cross-section of each layer. **State the sampling explicitly** — what was and
   wasn't covered goes in Coverage. Never silently truncate and imply full coverage.

## Stage 2 — Select lenses

First **load resolved config** per `${CLAUDE_PLUGIN_ROOT}/references/config-resolution.md`
(walk-up / `config:` / `INTENSE_CONFIG_DIR`, then merge over `config/defaults/`); the
`lenses:` toggles are authoritative, and `thresholds` + pattern policy feed the
architecture lens. **Always** state the Config source in Coverage (never silent
defaults). Then read `${CLAUDE_PLUGIN_ROOT}/references/lens-catalog.md` and
`${CLAUDE_PLUGIN_ROOT}/references/stack-catalog.md`.

- Predictability + simplicity always on.
- Convention on when stack/repo standards exist (catalog Convention doc and/or
  `CLAUDE.md`/`AGENTS.md`).
- Experience on only if the target has user-facing surfaces.
- **Architecture on when a detected stack has Arch pack ✅** in the stack catalog
  (and the audit target includes structural code). This is usually the highest-value
  pass in a codebase audit. Pass the resolved `thresholds` + pattern policy + the
  `tools.architecture` preference (`enrich`/`prefer`/`report`/`off`). Never gate
  architecture on a closed two-stack list.

Honor config `lenses:` toggles over these defaults. Find repo `CLAUDE.md`/`AGENTS.md`
+ `.intense` conventions for the convention and architecture lenses. Announce the team.

## Stage 3 — Dispatch

Resolve artifact paths per `${CLAUDE_PLUGIN_ROOT}/references/config-resolution.md`
(Artifact paths). Bind skill slots only:

| Slot | Value |
|------|--------|
| `SKILL_SLUG` | `audit` |
| `SCOPE_SLUG` | sanitized target slug, or empty |
| `OUT_ARG` | `out:` value or empty |
| `EXT` | `md` normally; `json` when `mode:agent` |

Run the **canonical** stamp / `RUN_ID` / `REPORT_PATH` procedure from that doc. Bind
`run_artifact_dir = $RUN` (Layer A only).

Spawn lenses in parallel with `Context: audit` (subagent template). **Model policy:**
pass `model: sonnet` to convention, experience, and architecture; let predictability
and simplicity inherit the session model — don't spawn the always-on lenses as `sonnet`.
Pass the file set (or sample) and the stack docs to read. **Audit mode requires
`scores`** — each lens returns 0-10 per dimension it owns (scoring rubric) plus findings
citing `file:line`. Missing required `scores` → lens **failed**. Respect the concurrency
cap. Lenses write `$RUN/{lens}.json` (via the Write tool).

For very large audits, a lens may itself fan out across file groups; the orchestrator
just needs the merged per-lens return.

## Stage 4 — Merge & score

1. Validate, assign per-lens status (failed / skipped / clean), dedup, confidence-gate
   (resolved `confidence_gate`, default 75; P0 at 50+ survives) and apply config policy
   as in `ie-review` Stage 5: **`severity_align` then `severity_overrides`**, suppress
   `approved` paths, keep `blocked` / preferred-instead_of findings (no apply — audit is
   read-only).
2. Assemble the **posture table** from each **clean** lens's `scores` (read
   `${CLAUDE_PLUGIN_ROOT}/references/scoring-rubric.md`): `Lens | Dimension | Score |
   Gap`, lowest scores first. Do not average into one number — the gaps are the
   product. Omit or mark failed lenses rather than inventing scores.
3. Collect tensions and observations.
4. **CI / conventions delta.** In Observations or Coverage, list:
   - auto-discovered gates/sources (`conventions.auto`) and any promotions from
     `severity_align`;
   - explicit notes/overrides that mention rules with **no** matching CI/source file;
   - high-signal CI files not covered by auto include/exclude (drift either way).

## Stage 5 — Report

Write the published report to `$REPORT_PATH` (markdown, or JSON in `mode:agent`) per
`${CLAUDE_PLUGIN_ROOT}/references/report-template.md`. Put `run_id` in the Header. Sections: Header (target,
stack, sampling note, run_id, **Config source**), Posture table (worst first), Findings (P0..P3, grouped, with
`Principle` + `Lens`), Tensions, Observations (incl. CI/conventions delta), Coverage (sampling bounds, suppressions,
each lens failed/skipped/clean, Config line), Verdict = the **top 3 posture gaps to fix first** with
why. Do **not** claim a healthy all-clear if any selected lens **failed**. No apply,
no push, no time estimates.

Then: if `CLEANUP` is true, run the **guarded** cleanup from
`${CLAUDE_PLUGIN_ROOT}/references/config-resolution.md` (only `rm -rf` when
`$RUN` equals `$RUN_DIR/$RUN_ID`). Always tell the user `Report: $REPORT_PATH`.

---

## Reference files (read at runtime)

Depends on `${CLAUDE_PLUGIN_ROOT}` resolving (standard in Claude Code). Read before
Stage 2 — shared contract for every `ie-*` skill:

- `${CLAUDE_PLUGIN_ROOT}/references/config-resolution.md` — load/merge .intense config + artifact paths
- `${CLAUDE_PLUGIN_ROOT}/references/lens-catalog.md`
- `${CLAUDE_PLUGIN_ROOT}/references/stack-catalog.md` — stack detection + Arch pack ✅
- `${CLAUDE_PLUGIN_ROOT}/references/subagent-template.md`
- `${CLAUDE_PLUGIN_ROOT}/references/scoring-rubric.md` — audit scoring
- `${CLAUDE_PLUGIN_ROOT}/references/findings-schema.json`
- `${CLAUDE_PLUGIN_ROOT}/references/report-template.md`
