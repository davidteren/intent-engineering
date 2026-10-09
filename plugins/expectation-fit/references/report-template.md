# Report Template

Canonical shape for the synthesized **published** report and the in-chat summary.
ASCII-safe (pipe tables, `->` not arrows, no box-drawing) so it degrades gracefully
across terminals.

**Two layers** (see `config-resolution.md` → Artifact paths):

| Layer | Default path | Contents |
|-------|--------------|----------|
| A — run scratch | `.expectation-fit/runs/<run-id>/` | per-lens `{lens}.json` while the run is open |
| B: report | `.expectation-fit/reports/<stamp>-<skill>[-scope].md` (git-ignored) | this report (or `.json` in `mode:agent` with `out:`) |

Override Layer B with `out:<path>`. After a successful publish, Layer A is deleted when
`artifacts.cleanup_runs` is true (default). Include `run_id` in the Header so the run
is still identifiable after cleanup.

**A published report is a point-in-time record.** Add later status as a dated addendum.
Do not edit the original lines.

## Provenance line

Every `fit-review`, `fit-audit` and `fit-validate-plan` report carries this one line in
its Header. It names the plugin copy that ran and the commit that the lenses read:

```
Provenance: Expectation Fit <version> from <plugin root>; <repo root>@<branch> <sha>[ +uncommitted]; run <run_id>
```

- `<version>` comes from `<plugin root>/.claude-plugin/plugin.json`. `<plugin root>` is
  the absolute plugin root (see `subagent-template.md`, Slot bindings).
- `<sha>` is the commit that the lenses read (short form). `+uncommitted` marks a dirty
  tree. Show `$HOME` as `~` in both paths.
- `fit-review` appends `; base <base_sha>`. `fit-audit` appends
  `; <N> commits ahead of <default>`.

```bash
PLUGIN_VERSION=$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$PLUGIN_ROOT/.claude-plugin/plugin.json" | head -1)
REPO_ROOT=$(git rev-parse --show-toplevel)
BRANCH=$(git rev-parse --abbrev-ref HEAD)        # fit-review remote scopes: the reviewed branch
REVIEWED_SHA=${REVIEWED_SHA:-$(git rev-parse --short HEAD)}
# TREE_CLEAN: fit-review reuses its Stage 1 value. Do not recompute it there.
# fit-audit and fit-validate-plan capture it once here, before any write:
# [ -z "$(git status --porcelain)" ] && TREE_CLEAN=true || TREE_CLEAN=false
COMPLETED_AT=$(date +%Y-%m-%dT%H:%M:%S%z)       # local time with UTC offset; STAMP stays local
```

## Findings table (review & audit)

Group by severity. The `Issue` cell is one terse clause (the scannable index). Depth
goes in the keyed detail line, not the cell.

```
### P0 -- Critical surprise
| # | File | Issue | Principle | Lens | Conf | Status |
|---|------|-------|-----------|------|------|--------|
| 1 | `app/models/order.rb:42` | `fetch_total` also writes a cache row | least-astonishment | predictability | 100 | open |

- **#1** -- `fetch_total` is named as a pure read but persists a cache row as a side
  effect; a caller reading the name will not expect a write (and will be surprised in
  a transaction/read-replica context). Fix: rename to `fetch_and_cache_total`, or move
  the write to an explicit `refresh_total_cache!`.
```

Seven columns. `Status` is `open`, `fixed <sha>` or `declined: <reason or link>`; it is
the per-finding decision record that a later run reads through `prior:<report-path>`.
Keyed `- **#N** --` detail line for findings whose one-liner isn't
self-sufficient (usually P0/P1). Same table shape for every severity — never render
one severity as field-blocks and another as a table. Numbering is stable and
monotonic across the whole report.

## Report sections (in order)

1. **Header** — scope or target, intent, context (review/audit/plan), the
   **Provenance line** (above), `completed_at`, `Execution: subagents | single-agent`,
   and the lens team: every catalog lens with its selection and a one-line reason, for
   example `experience: not_selected, no user-facing paths in scope`. Audit adds the
   stack and the sampling note. Plan adds the document path and type, `plan_sha256`
   (hash of the plan file at run time), and on a re-check `supersedes: <prior report>`
   and the round number. Skills point here; they do not list Header fields of their own.
2. **Applied** *(fit-review interactive only, when fixes were applied)* — `# | File |
   Fix | Lens`, then validation outcome + commit status. Name the fix commit by its real
   SHA from `git rev-parse --short HEAD` after the commit, never a placeholder. Applied
   findings appear here, not in the severity tables. Only fixes that passed the
   fit-review Stage 5 step 7 gate appear here.
3. **Findings** — pipe tables grouped P0..P3, terse `Issue` cell, keyed detail lines.
   Omit empty severities. **The all-clear line is allowed only when every selected lens
   is `clean` and read all of its scope** (see Lens status below). If severities are
   empty and that holds, do NOT drop the section. Render:
   `No findings surfaced in this pass (N lenses, M files reviewed).`
   In a single-agent run, render:
   `No findings surfaced in this pass (N lenses in one agent, M files reviewed).`
   Then set Verdict to Ready / Healthy. One run is a sample: a second run can surface
   what this one missed. If a status or a partial read blocks the all-clear line, do
   **not** use it. State which lenses and why, and set Verdict accordingly (review: Not
   ready or Ready with fixes; plan: Revise first). (In `mode:agent`, empty `findings`
   with a clean verdict is valid only under the same rule.)
4. **Posture** *(audit & plan only)* — the scoring table from `scoring-rubric.md`,
   lowest scores first, from lenses with status `clean` or `ok`.
5. **Tensions** — any findings carrying a `tension`: name the two principles in
   conflict, or the principle and the quoted decision line. Then give the trade-off, so
   the owner decides rather than the tool dictating. These findings also stay in
   Findings at their severity.
6. **Observations** — soft notes / residual risks unioned across lenses.
7. **Coverage** — what was reviewed, what was skipped (untracked, sampling bounds,
   remote-mode limits), `Plan: <path>` or `Plan: none` (review), finding lines that
   could not be verified (see `subagent-template.md`, output contract), and:
   - **Rejected.** Every finding that the merge did not report: title, file:line,
     lens, severity, confidence and `why`. The `why` values are
     `below_confidence_gate`, `not_real` (a re-read refuted it), `verifier_failed` (the
     re-read could not run), `unverifiable` (the re-read ran but could not open or
     check the cited code), `malformed`, `accepted_by_caller` and
     `over_max_findings` (Grok runtime only: it caps the findings it verifies).
   - **Re-grades.** Each orchestrator change to a lens's severity or confidence, with
     its reason.
   - **Lens status** for every catalog lens, with the words in the table below.
     Promote `SKIPPED:` observations from the architecture agent to `skipped`. A
     `skipped` lens is not the same as a `clean` lens with empty findings.
   - **Architecture tools.** One line that names which external tools ran, from the
     lens's once-per-run note, for example
     `architecture: clean, heuristics only (ruff, radon not found)`.
   - **READ lines.** One per lens, copied from the lens's first observation
     (`READ: <what you read> of <what you were given>`). A READ line that shows a
     partial read blocks the all-clear line and Ready.
   - **Cost**, one line, when the harness reports numbers: each lens's wall time, its
     tokens when known, and the session model. Leave the line out when the harness
     gives no numbers.

   **Lens status.** Each word has one meaning. Set `clean` or `ok` after the
   confidence gate.

   | Status | Meaning | Blocks the all-clear line and Ready |
   |---|---|---|
   | `clean` | Ran. The report shows no finding from this lens. | No |
   | `ok` | Ran. The report shows N findings from this lens, applied fixes included. Coverage writes "ok, N findings". | No. The findings set the verdict. |
   | `failed` | Non-JSON return, missing `$RUN/{lens}.json` (plan set: `$RUN/{lens}-<doc-slug>.json`, where `<doc-slug>` comes from the repo-relative document path and is unique in the set), missing required `scores`, a returned `lens` that differs from the dispatched lens, or a harness error (after the optional one re-dispatch). | Yes |
   | `skipped` | Selected, but it could not analyze. Example: no architecture pack (a `SKIPPED:` observation). | Yes |
   | `not_selected` | Auto-selection, config or a `lenses:<list>` token did not pick it. The Header gives the reason. | No |

   Ready here means Ready (review), Healthy (audit) and Ready to implement (plan).
8. **Verdict** — review: Ready / Ready with fixes / Not ready. audit: top 3 posture
   gaps to fix first. plan: Ready to implement / Revise first, with the blocking gaps,
   and the lens coverage (for example `Ready to implement (3 of 4 lenses; experience
   off by config)`; a lens that did not run counts as not run, even with `prior:`).
   **Never** Ready / all-clear / Ready to implement when a lens status or a partial
   read blocks it (see Lens status).
   **Review verdict rule:** Not ready while a P0 or P1 finding is open. Ready with fixes
   while a P2 finding is open. Otherwise Ready. Open means a Findings row with Status
   `open`; `fixed` and `declined` rows count as closed. A lens status or a partial read
   that blocks Ready (see Lens status) still blocks it.

No time estimates. Measured times in the Cost line are measurements, not estimates. No
praise. Every finding actionable.

## Merge and gate

`fit-review`, `fit-validate-plan` and `fit-audit` merge lens returns with these steps, in
this order. Each step runs in every context unless its mark says otherwise. Read
`${CLAUDE_PLUGIN_ROOT}/references/findings-schema.json` for the field rules.

1. **Validate and repair.** Assign each lens a status (see Lens status under Coverage). Mark the lens
   **failed** on a non-JSON return, a missing `$RUN/{lens}.json` (plan set: a missing
   `$RUN/{lens}-<doc-slug>.json` for any document), a returned `lens`
   that differs from the dispatched lens, or a selected lens that never returned. One re-dispatch is allowed on a non-JSON return; a lens that is
   still non-JSON after that is failed. Repair off-schema findings; do not drop them:
   - Severity `low`, `medium`, `high` or `critical` becomes `P3`, `P2`, `P1` or `P0`.
     An `info` finding moves to observations.
   - A confidence between anchors rounds down to the next anchor, so 55 becomes 50. A
     repair never lifts a finding over the gate.
   - A `fix_class` outside the enum becomes `manual`, never `gated_auto`.
   - A `file` value such as `app/x.rb:35` splits into `file` and `line`.

   Drop a finding only when its title, severity or file is missing or cannot be
   repaired. A dropped finding goes to Rejected with why `malformed`. Log each repair,
   and any other change the orchestrator makes to a lens's severity or confidence, under
   Re-grades with its reason. Never change them silently.
2. **Dedup.** Merge findings in the same file within 3 lines that describe the same
   defect, even when their titles differ. Keep each copy's severity and confidence
   together. Keep the highest-severity copy whose confidence passes the gate. If no copy
   passes, keep the highest-severity copy with its own confidence. Log the choice under
   Re-grades. Show each lens with its own severity and title. Keep `gated_auto` only
   when every copy has it; otherwise use the strictest class of the copies.
3. **Cross-lens agreement.** Note the agreeing lenses. Agreement does not raise
   confidence: one agent can play several lenses, so two lenses on one defect at 50
   stay at 50.
4. **Apply config policy before the confidence gate** *(review and audit; plan skips
   this step)*. Order matters (see `config-resolution.md`):
   1. **`severity_align`** (`mode: curated_gates`): using the workflow list from
      `conventions.auto` discovery, promote findings that match a gate theme under the
      **smell-first** rules (e.g. `callback-hell` + `callback-check.yml` -> at least
      `min_severity`, default P1). Never demote. Record each promotion in Coverage.
      Mark those findings `severity_aligned: true` for the gate exception below.
   2. **`severity_overrides`** (wins over align on conflict): string or
      `{ severity:, because: }`: copy `because` into Coverage. A key that is not a
      principle id or a canonical smell id goes in Coverage as
      `ignored severity_overrides key: <key>`.
   3. Pattern policy: `approved` silences blocked, instead_of and unidentified
      findings on its path. Smell findings still show, and net-new blocked use still
      gets P1. Keep preferred-`instead_of` introductions in **changed** code at P1.
      Audit has no change, so it keeps every blocked / preferred-`instead_of` finding
      outside an `approved` path.
5. **Confidence gate**: suppress findings below the resolved `confidence_gate`
   (default anchor 75), EXCEPT:
   - P0 at confidence 50+, or
   - findings that received a **`severity_align` promotion** at confidence 50+
     (CI-backed floors must not be dropped solely for mid confidence).
   Each suppressed finding goes to Rejected with why `below_confidence_gate`.
6. **Collect tensions**: a finding carrying a `tension` stays in Findings at its
   severity and also appears in the Tensions section.

Applying fixes is not a shared step. Only interactive `fit-review` applies (its Stage 5
step 7). Audit and plan never apply.

## mode:agent (JSON)

When a skill runs `mode:agent`, emit one raw JSON object (no code fence) as the reply
instead of markdown. The reply is the deliverable. Write that same object to a file
only when the caller passes `out:` (then `$REPORT_PATH` is that path, and
`artifact_path` is its absolute path). Without `out:`, write no report file and set
`artifact_path` to `null`. Never write the mode:agent report into the run-scratch dir
(`$RUN`); that dir is deleted when `cleanup_runs` is true. A `mode:agent` run leaves
`git status --porcelain` unchanged (run scratch ignores itself). Each item in
`findings` carries `status` (`open`, `fixed <sha>` or `declined: <reason or link>`);
`mode:agent` callers write their triage into that field. Plan reports add
`plan_sha256`.

The reply stays one raw JSON object, even when a caller asks only for the verdict, the
counts and the path. Those are fields of the object (`verdict`, `finding_counts`,
`artifact_path`). Do not add prose before or after it.

Complete example (a review run without `out:`):

```json
{
  "status": "complete",
  "reason": null,
  "handoff": null,
  "context": "review",
  "verdict": "Not ready",
  "completed_at": "2026-10-09T14:32:05+0200",
  "run_id": "20261009-143005-a1b2c3d4",
  "scope": {
    "mode": "local-aligned",
    "base": "3f2c1a9",
    "branch": "feat/order-totals",
    "head_sha": "9e8d7c6",
    "pr": null
  },
  "intent": "Cache order totals so the order summary page loads faster.",
  "lenses": ["predictability", "simplicity", "convention"],
  "findings": [
    {
      "title": "fetch_total also writes a cache row",
      "principle": "least-astonishment",
      "severity": "P1",
      "confidence": 100,
      "file": "app/models/order.rb",
      "line": 42,
      "fix_class": "manual",
      "suggested_fix": "Rename to fetch_and_cache_total, or move the write to refresh_total_cache!.",
      "lenses": ["predictability"],
      "status": "open"
    },
    {
      "title": "Bare rescue hides cache write errors",
      "principle": "error-handling",
      "severity": "P2",
      "confidence": 75,
      "file": "app/models/order.rb",
      "line": 51,
      "fix_class": "gated_auto",
      "suggested_fix": "Rescue only Redis::BaseError and re-raise everything else.",
      "lenses": ["predictability"],
      "status": "open"
    }
  ],
  "finding_counts": { "P0": 0, "P1": 1, "P2": 1, "P3": 0 },
  "actionable_findings": [
    {
      "title": "Bare rescue hides cache write errors",
      "file": "app/models/order.rb",
      "line": 51,
      "suggested_fix": "Rescue only Redis::BaseError and re-raise everything else.",
      "requires_verification": true
    }
  ],
  "rejected": [
    {
      "title": "TotalsCache wrapper has one caller",
      "file": "app/models/totals_cache.rb",
      "line": 3,
      "lens": "simplicity",
      "severity": "P3",
      "confidence": 50,
      "why": "below_confidence_gate"
    }
  ],
  "tensions": [],
  "posture": null,
  "observations": [],
  "coverage": {
    "config": ".expectation-fit/ (walk-up from repo root)",
    "execution": "subagents",
    "lens_status": {
      "predictability": "ok",
      "simplicity": "clean",
      "convention": "clean",
      "experience": "not_selected",
      "architecture": "not_selected"
    },
    "files_reviewed": 4,
    "untracked": [],
    "regrades": []
  },
  "artifact_path": null,
  "plugin_version": "0.9.0",
  "plugin_root": "~/.claude/plugins/expectation-fit",
  "repo_root": "~/code/shop",
  "branch": "feat/order-totals",
  "reviewed_sha": "9e8d7c6",
  "tree_clean": true,
  "base_sha": "3f2c1a9"
}
```

**mode:agent fields:** `status`, `reason`, `handoff`, `context`, `verdict`, `completed_at`, `run_id`,
`scope.mode`, `scope.base`, `scope.branch`, `scope.head_sha`, `scope.pr`, `intent`,
`lenses`, `findings`, `finding_counts`, `actionable_findings`, `rejected`, `tensions`,
`posture`, `observations`, `coverage.config`, `coverage.execution`, `coverage.lens_status`,
`coverage.files_reviewed`, `coverage.untracked`, `coverage.regrades`,
`artifact_path`, `plugin_version`, `plugin_root`, `repo_root`, `branch`, `reviewed_sha`,
`tree_clean`, `base_sha`, and `status` on each finding. The example above shows each one.

Per-finding keys: each item in `findings` has `title`, `principle`, `severity`,
`confidence`, `file`, `line`, `fix_class`, `suggested_fix`, `lenses` and `status`. Each
item in `actionable_findings` has `title`, `file`, `line`, `suggested_fix` and
`requires_verification`.

Field rules:

- `status` is `complete`, `failed` or `skipped`. `skipped` means the run reviewed
  nothing by design. When it is `failed` or `skipped`, `reason` says why in one
  sentence. Otherwise `reason` is `null`.
- `verdict` uses the verdict words below. It is `null` when `status` is `skipped`.
- `posture` holds the 0-10 dimension scores in `fit-audit` and `fit-validate-plan`, as
  one object keyed by dimension. It is `null` in review.
- `handoff` is `"fit-validate-plan"` when a review run hands the work to that skill.
  Otherwise it is `null`.
- `completed_at` is an ISO 8601 local time with its UTC offset
  (`date +%Y-%m-%dT%H:%M:%S%z`). Report file names keep the local `STAMP`.
- Provenance keys (see Provenance line): `plugin_version`, `plugin_root`, `repo_root`,
  `branch`, `reviewed_sha` and `tree_clean` in every context; `base_sha` in review
  only. Plan adds `plan_sha256`. Show `$HOME` as `~` in both paths.
- `artifact_path` is the absolute path of the `out:` file, or `null` without `out:`.
- Each item in `findings` carries `status`: `open`, `fixed <sha>` or
  `declined: <reason or link>`.
- `scope` by context. Review: `mode`, `base`, `branch`, `head_sha`, and `pr` (number or
  `null`). Plan: `document` (the path, or a list of paths for a
  set). Audit: `target` (the path, glob or subsystem).
- `finding_counts` counts findings per severity after the confidence gate. All four keys
  are always present.
- Each item in `findings` carries `lenses`: every lens that reported it (after dedup).
- `actionable_findings` is the caller's apply list: findings that pass the static
  conditions of the `fit-review` apply gate (Stage 5 step 7 in
  `${CLAUDE_PLUGIN_ROOT}/skills/fit-review/SKILL.md`): `gated_auto`, confidence >= 75, P2
  or P3, a concrete `suggested_fix`, no `tension`, and not a prior declined row.
  `mode:agent` skips the verify-first step, so each item has `requires_verification: true`
  and the caller must verify it before applying. It is empty in audit and plan.
- `rejected` lists every finding that the merge did not report, with `title`, `file`,
  `line`, `lens`, `severity`, `confidence` and `why` (see Rejected under Coverage).
- `coverage.config` is the Config line: the config source that the run used.
- `coverage.execution` is `subagents` or `single-agent`.
- `coverage.lens_status` has one key per catalog lens, with the words from the Lens
  status table.
- `coverage.regrades` lists every re-grade from any merge step (repairs in Merge and
  gate step 1, dedup, `severity_align`, `severity_overrides` and pattern policy), by lens
  and title, with its reason. Drops go to `rejected`.

Verdict words, by context. Use only these words:

| Context | Verdict words |
|---------|---------------|
| review | `Ready`, `Ready with fixes`, `Not ready` |
| plan | `Ready to implement`, `Revise first` |
| audit | `Healthy`, `Gaps to fix first` |

Never use a verdict word that a caller suggests, such as "Ready to merge".
