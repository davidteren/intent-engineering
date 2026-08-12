# ie-review: Grok workflow orchestrator

**Date:** 2026-08-12
**Context:** review
**Scope:** `.grok/workflows/ie-review.rhai` (347-line Grok workflow)
**Intent:** Find surprise in the Grok first-cut of `/ie-review`. Report only. Do not apply fixes.
**Stack:** rhai (Grok workflow script)
**Config:** plugin defaults (no `.intense/` found)
**run_id:** none (this workflow does not allocate `.intense/runs/<run-id>/`)

### Lens team

| Lens | Why it ran |
|------|------------|
| predictability | Always-on. |
| convention | Code review. Always-on for this surface. |
| simplicity | Always-on. |
| experience | This workflow always runs all five. Catalog would skip: no user-facing surface. |
| architecture | This workflow always runs all five. Catalog would skip: no Arch pack for rhai. |

## Findings

### P1 -- High-impact (normal use)

| # | File | Issue | Principle | Lens | Conf |
|---|------|-------|-----------|------|------|
| 1 | `.grok/workflows/ie-review.rhai:248` | `complete()` changes shape; `confirmed` flips type | api-design | predictability | 100 |
| 2 | `.grok/workflows/ie-review.rhai:341` | Merge failure still reports a published path | wysiwyg | predictability | 100 |
| 3 | `.grok/workflows/ie-review.rhai:228` | Cap keeps first 16, so later lenses never verify | least-astonishment | predictability | 100 |
| 4 | `.grok/workflows/ie-review.rhai:72` | Lens prompts reinvent dispatch instead of using `subagent-template.md` | convention-over-configuration | convention | 100 |
| 5 | `.grok/workflows/ie-review.rhai:111` | Orchestrator never loads config-resolution or `.intense` defaults | convention-over-configuration | convention | 100 |
| 6 | `.grok/workflows/ie-review.rhai:219` | Merge dedupes by file+title and skips Stage 5 policy | convention-over-configuration | convention | 100 |
| 7 | `.grok/workflows/ie-review.rhai:321` | Report phase adds a write-capable merge agent and a second write | kiss | simplicity | 75 |

- **#1** -- Early exits return `confirmed` as `[]` plus observations (lines 248-260). Success returns `confirmed` as `confirmed.len()` (a number), plus verdict, path, and scratch, and it omits observations (lines 330-338). Merge failure returns `confirmed` as the finding array and a path, with no verdict (lines 341-346). A caller cannot treat `complete()` as one object. Fix: use one `complete()` object on every exit. Always include summary, verdict, path (empty when unpublished), scratch, `confirmed` (always an array), `confirmed_count`, reviewed, statuses, and observations. On the success path, pass the confirmed array plus a separate count.

- **#2** -- Merge failure (lines 341-346) still sets `path: report_rel`. Success (line 333) also sets that path without checking that the merge agent wrote the file. A stale file from an earlier run then looks like this run's report. Fix: on merge failure, set path to an empty string (or omit it) and do not name `report_rel`. On success, write `report_text` from this script and set path only when that write succeeds.

- **#3** -- `MAX_FINDINGS` is 16 (line 61). `unique` keeps lens order (predictability, then convention, then simplicity, experience, architecture). The cap loop (lines 235-239) takes the first 16. Each lens schema allows 8 findings, so two full early lenses fill the cap. Later lenses never reach Verify. Fix: sort unique by severity (P0, P1, P2, P3) then confidence descending before the cap. Push an observation that names how many findings were dropped. Pass that observation into the merge prompt. Do not cap by insertion order.

- **#4** -- `lens_prompt()` builds a short custom prompt (read these files, Target, Hunt for). It never fills `subagent-template.md` slots: intent, scope_mode, standards_paths, run_artifact_dir, or the artifact-write output-contract. AGENTS.md and ie-review Stage 4 require dispatch from that template. Fix: replace `lens_prompt()` with a fill of `plugins/intent-engineering/references/subagent-template.md`. Bind `run_artifact_dir` to a per-run dir under `artifacts.run_dir`. Pass Context: review, a 2-3 line intent, scope mode, and ancestor AGENTS.md/CLAUDE.md paths. Keep Grok `output_schema` as the machine wrapper only.

- **#5** -- Runtime setup sets `plugin_root`, `base_ref`, and `report_rel` from args only. There is no walk-up, no `INTENSE_CONFIG_DIR`, and no merge of `ways-of-working.yaml`. AGENTS.md How a run works step 1: load resolved config always before lens selection. Fix: before `let lenses`, resolve config per `plugins/intent-engineering/references/config-resolution.md`. Walk up for `.intense/`, else use `plugins/intent-engineering/config/defaults/`. Apply `lenses.*`, `confidence_gate`, `artifacts.*`, `conventions.*`, and `severity_align`. Pass `Config: <source>` into the merge Coverage block.

- **#6** -- `unique[]` treats two findings as the same only when `u.file == f.file && u.title == f.title`. No line window, no normalize, no cross-lens promotion, no `severity_align`. The merge agent is only told to drop confidence below 75. Skill Stage 5 and AGENTS.md say dedup by file+line+title, then policy, then the gate. Fix: before Verify, implement ie-review Stage 5 in Rhai. Dedup by `normalize(file)+line(+/-3)+normalize(title)`. Keep highest severity and confidence. Promote one confidence step when 2+ lenses agree. Apply `severity_align` then `severity_overrides`. Gate at `confidence_gate` 75 (P0 at 50+). Do not leave the gate as merge-prompt prose only.

- **#7** -- The merge prompt tells the agent to Write the published report, return the same markdown, then the workflow writes it again via `write_scratch_file`. The agent is `capability_mode: read-write` only for that extra hop. Fix: keep the merge agent read-only and have it return markdown only. Write `report_rel` and the scratch file in this workflow from `merged.output.report`. Remove the Write-tool instruction from the merge prompt.

### P2 -- Moderate

| # | File | Issue | Principle | Lens | Conf |
|---|------|-------|-----------|------|------|
| 8 | `.grok/workflows/ie-review.rhai:223` | Dedup by file plus title hides other lenses and lines | least-astonishment | predictability | 100 |
| 9 | `.grok/workflows/ie-review.rhai:290` | Verifier rejects vanish with no rejected list | error-handling | predictability | 75 |
| 10 | `.grok/workflows/ie-review.rhai:321` | Report-only merge agent still has full write access | least-astonishment | predictability | 75 |
| 11 | `.grok/workflows/ie-review.rhai:310` | `confirmed` count is pre-gate, not what the report keeps | wysiwyg | predictability | 75 |
| 12 | `.grok/workflows/ie-review.rhai:121` | Default report path overwrites the last review | least-astonishment | predictability | 100 |
| 13 | `.grok/workflows/ie-review.rhai:121` | Default report path ignores stamp-skill two-layer convention | convention-over-configuration | convention | 100 |
| 14 | `.grok/workflows/ie-review.rhai:185` | Lens status uses `findings` instead of report-template skipped/clean | convention-over-configuration | convention | 100 |

- **#8** -- Lines 219-226: if `u.file == f.file && u.title == f.title` then `seen = true`. The first lens that emitted that pair wins. The `/ie-review` skill dedups on file + line(+/-3) + title and records agreeing lenses. Same title at a different line is dropped. A second lens that agreed is dropped. Fix: dedup on file + line + trimmed title. On a match, keep the higher severity and confidence and append the new lens id to a `lenses` list on the kept finding. Do not drop a same-title finding at a different line. Do not drop a second lens that agreed.

- **#9** -- Lines 285-294 keep a finding only when `v.success && real == true` and evidence is non-empty. Everything else is dropped. The merge prompt (lines 317-318) receives only `confirmed`. The user-facing signal is one log line (line 295). A harness failure looks the same as `real=false`. Fix: for every verdict, store `{finding, real, reason, evidence, harness_ok}`. Pass rejected findings and harness failures to the merge prompt as Coverage. Treat `v.success != true` as `verifier_failed`, not as `real=false`.

- **#10** -- `meta.when_to_use` (line 4): "Report only. Does not apply fixes." Merge is spawned with `capability_mode: read-write` (line 323) and told to Write the published report (lines 307-308). The only "do not edit product code" guard is prompt text (line 299). Fix: pick one contract and make it visible. Either keep read-write and change `meta.when_to_use` to name the tree write (published report under `docs/intent-engineering/`; no code fixes), or set the merge agent to read-only and write the report in this script. Do not pair "Report only / Does not apply fixes" with an unbounded write agent.

- **#11** -- Line 310 tells the merge agent to drop findings below 75 unless P0 at 50+. Line 335 then reports `confirmed: confirmed.len()`, which is the post-verify, pre-gate list from lines 290-291. The dashboard count can be larger than the published table. Fix: apply the confidence gate in this script (drop below 75 unless severity is P0 and confidence is 50+). Pass only gated findings to the merge prompt and to `complete()`. If a pre-gate count is needed, name it `verified_count`, not `confirmed`.

- **#12** -- Lines 121-126: `report_rel` starts as `docs/intent-engineering/workflow-ie-review.md`. `stamp` only changes the path when `out` is absent. The `/ie-review` skill defaults to a stamped published file so runs do not clobber each other. Two default runs overwrite the same file. Fix: when `args.out` is omitted, set `report_rel` to `docs/intent-engineering/<stamp>-ie-review.md`. Generate stamp from the host date plus a short target slug when `args.stamp` is also omitted. Do not default to a single reusable filename.

- **#13** -- `report_rel` defaults to `docs/intent-engineering/workflow-ie-review.md`; stamp yields `<stamp>-ie-review.md`; scratch is `write_scratch_file("report.md")`. AGENTS.md rule 5 and config-resolution `CANONICAL_ORCHESTRATOR_PATHS` require `.intense/runs/<run-id>/` plus `docs/intent-engineering/<stamp>-<skill>[-scope].md` with skill slug `review`. Fix: default Layer B to `docs/intent-engineering/<stamp>-review.md` (`SKILL_SLUG` review). Keep `args.out` as the override. Write lens JSON under `.intense/runs/<run-id>/` (or a Grok scratch that mirrors that layout). Stop using a fixed `workflow-ie-review.md` name that overwrites the last run.

- **#14** -- Empty arrays become status `clean`; non-empty become status `findings`. `report-template.md` Lens status allows only `failed`, `skipped`, and `clean`. `clean` already covers both zero findings and listed findings. `skipped` is never assigned. A caller that reads statuses cannot apply the all-clear rule. Fix: emit only `failed`, `skipped`, or `clean`. A successful lens with findings is `clean` (findings listed in the report). Use `skipped` when lens-catalog or config did not select the lens. Delete the `findings` status.

### P3 -- Minor

| # | File | Issue | Principle | Lens | Conf |
|---|------|-------|-----------|------|------|
| 15 | `.grok/workflows/ie-review.rhai:11` | Inline lens schema omits findings-schema enums | convention-over-configuration | convention | 75 |
| 16 | `.grok/workflows/ie-review.rhai:61` | `MAX_FINDINGS=16` is an unpublished drop cap | convention-over-configuration | convention | 100 |

- **#15** -- `lens_schema` types `lens`, `principle`, `severity`, and `fix_class` as plain strings and `confidence` as integer, with no enums. `findings-schema.json` is the single contract and constrains those fields. The merge prompt later tells the writer to read that file, so two contracts exist. Invalid values can pass the harness. Fix: build `output_schema` from `plugins/intent-engineering/references/findings-schema.json`. Copy the enums for `lens`, `principle`, `severity`, `confidence`, and `fix_class` into the Rhai map so invalid values cannot pass the harness.

- **#16** -- `const MAX_FINDINGS = 16`; unique findings are copied in arrival order and the rest are dropped with a log line. ie-review `SKILL.md` has no such cap. The README does not mention it. A late P0 can drop because a P3 arrived first. Fix: delete `MAX_FINDINGS` and the first-N drop, or sort by severity then confidence before the cap and document the budget in `.grok/workflows/README.md`. Do not drop P0s because they arrived after P3s in lens order.

## Tensions

Name the two sides. Do not pick one here.

1. **#4** -- Grok `parallel(jobs)` needs a prompt string and cannot spawn Claude Agent tools, versus the repo rule that every ie-review orchestrator fills `subagent-template.md`.
2. **#6** -- Full Stage 5 in Rhai, versus the documented first-cut skeptic pipeline that does not replace `/ie-review`.
3. **#7** -- KISS (template or one writer in Rhai), versus convention (an LLM can follow `report-template.md` more closely than a Rhai string).
4. **#9** -- Fail-closed verification (drop anything unverified), versus error-handling transparency (show rejects and harness failures).
5. **#10** -- Least-astonishment (capability matches "Report only"), versus the product rule that orchestrators publish under `docs/intent-engineering/`.
6. **#13** -- The workflow README documents the fixed default path, versus AGENTS.md two-layer stamp convention that wins on conflict.
7. **#14** -- README says five lenses run together (so skip-as-not-selected is unused), versus report-template all-clear rules that treat `skipped` and `clean` as different.
8. **#15** -- Grok `output_schema` must be an inline map, versus one `findings-schema.json` as the only contract.
9. **#16** -- Repo ie-review has no drop cap, versus a Grok agent-budget cap that may be required to finish Verify.

## Observations

- Experience and architecture always run. A not-applicable empty return is marked `clean`, not `skipped`. A backend-only target can look like five clean lenses.
- Always running experience and architecture is simpler than copying lens-catalog selection. Those agents already return zero findings when the surface or stack is absent. Residual tension: YAGNI (skip unused agents) versus KISS (do not reimplement selection).
- Lens status is set from the raw findings array length (line 184) before empty title or file rows are dropped. Status `findings` can pair with zero accepted items.
- `plugin_root` defaults to the repo-relative path `plugins/intent-engineering`. Another repo must pass an absolute path, or lenses read the wrong tree. That default is the Grok-runtime convention. `${CLAUDE_PLUGIN_ROOT}` applies inside the plugin, not this file.
- The failed-lens early exit (lines 247-253) correctly refuses all-clear when no usable findings remain.
- Two notes conflict on `trimmed()`. One says Rhai `trim` mutates in place, so `trimmed()` is not a discarded-return bug. The other says `s.trim()` returns a new string, so the helper is an identity and a predictability bug. This is not in the verified list. Residual risk: confirm the Rhai runtime, then drop the helper or keep a real trim.
- `lens_schema` is a loosened inline copy of `findings-schema.json`. The Grok runtime needs an inline schema. `scripts/check-contracts.rb` does not cover this file, so the copy can drift.
- Documented first-cut deviations, treated as reasoned not findings: report-only, no apply, one skeptic per finding, five lenses together. The first cut correctly skipped apply, config walk-up, and `severity_align`. That thinning is earned. Dedup is still file+title first-wins, not the skill's file+line window with highest severity.
- This file is a Grok workflow orchestrator, not a user-facing surface. It defines meta, five parallel lens jobs, verify, and merge. There is no UI component, view, template, form, or interactive control. `pause`, `phase`, and `complete` are runtime status hooks for the `/workflows` dashboard. They are not a designed interface with loading, empty, error, focus, or keyboard states. Experience hunts do not apply. Report look-and-feel is out of scope in this file (the merge agent writes that later from `report-template.md`).
- No `resources/frameworks` doc for Rhai or Grok. Stack-idiom checks skipped.

## Coverage

**Reviewed:** `.grok/workflows/ie-review.rhai` (one file, full read). Detected stack is rhai (Grok workflow script).

**Config:** defaults (no `.intense/` found). Config sources (auto): 3 files (`agents` = `AGENTS.md` + `CLAUDE.md`, `copilot` = 0, `instructions` = 0, `workflows` = `.github/workflows/contracts.yml`); excluded = 0.

**Sampling / remote:** none. No untracked paths. No Layer A run dir (this workflow does not write `.intense/runs/<run-id>/`).

**Confidence gate:** applied at merge. Drop below 75 unless severity is P0 and confidence is 50+. 16 verified findings presented; 0 dropped by the gate. Workflow `confirmed` count is pre-gate (see #11).

**Per-lens status:**

| Lens | Workflow status | Report status | Note |
|------|-----------------|---------------|------|
| predictability | findings | clean | Findings listed above. `findings` is not a report-template status (see #14). |
| convention | findings | clean | Findings listed above. |
| simplicity | findings | clean | Findings listed above. |
| experience | clean | clean | Analyzed. No user-facing surface. Zero findings after the gate. |
| architecture | clean | skipped | `SKIPPED: no architecture rule pack for rhai`. Catalog Arch packs cover rails, python, laravel, express, phoenix, and react only. `ruby` exists in the catalog but the Arch pack is empty. No matching `frameworks/<stack>-architecture.md` or `patterns/<stack>.yaml`. |

No selected lens **failed**.

## Verdict

**Ready with fixes.**

16 findings remain: 7 P1, 7 P2, 2 P3. No P0. No failed lens. Architecture is skipped (no rhai pack). Experience is clean (no UI). Do not treat this as all-clear.

Highest-impact fixes first: one `complete()` shape (#1), honest publish path (#2), severity-ordered cap or no cap (#3, #16), then Stage 5 merge plus config load (#5, #6) and a read-only merge writer (#7, #10).
