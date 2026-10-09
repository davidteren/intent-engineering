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
[ -z "$(git status --porcelain)" ] && TREE_CLEAN=true || TREE_CLEAN=false
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
   **Provenance line** (above), `completed_at`, and the lens team with the one-line
   reason for each conditional lens. Audit adds the stack and the sampling note. Plan
   adds the document path and type, `plan_sha256` (hash of the plan file at run time),
   and on a re-check `supersedes: <prior report>` and the round number. Skills point
   here; they do not list Header fields of their own.
2. **Applied** *(fit-review interactive only, when fixes were applied)* — `# | File |
   Fix | Lens`, then validation outcome + commit status. Name the fix commit by its real
   SHA from `git rev-parse --short HEAD` after the commit, never a placeholder. Applied
   findings appear here, not in the severity tables.
3. **Findings** — pipe tables grouped P0..P3, terse `Issue` cell, keyed detail lines.
   Omit empty severities. **All-clear is allowed only when every *selected* lens is
   `clean` (not failed, not skipped-as-selected).** If severities are empty and all
   selected lenses are clean, do NOT drop the section — render:
   `No findings — all selected lenses returned clean (N lenses, M files reviewed).`
   and set Verdict to Ready / Healthy. If any selected lens **failed**, do **not** use
   that all-clear line; state which lenses failed and set Verdict accordingly (review:
   Not ready or Ready with fixes; plan: Revise first). (In `mode:agent`, empty
   `findings` with a clean verdict is valid only when lens statuses are all clean.)
4. **Posture** *(audit & plan only)* — the scoring table from `scoring-rubric.md`,
   lowest scores first (from clean lenses only).
5. **Tensions** — any findings carrying a `tension`: name the two principles in
   conflict and the trade-off, so the user decides rather than the tool dictating.
6. **Observations** — soft notes / residual risks unioned across lenses.
7. **Coverage** — what was reviewed, what was skipped (untracked, sampling bounds,
   remote-mode limits), confidence suppressions by anchor, finding lines that could
   not be verified (see `subagent-template.md`, output contract), and **per-lens status**:
   - **failed** — non-JSON return, missing `$RUN/{lens}.json`, missing required
     `scores` in audit/plan, or harness error after optional one re-dispatch.
   - **skipped** — not selected, or architecture pack absent (catalog ⬜ / no pack);
     promote `SKIPPED:` observations from the architecture agent here. Not the same
     as clean empty findings.
   - **clean** — valid return, analyzed, zero findings remaining after the confidence
     gate (or findings present and listed).
8. **Verdict** — review: Ready / Ready with fixes / Not ready. audit: top 3 posture
   gaps to fix first. plan: Ready to implement / Revise first, with the blocking gaps,
   and the lens coverage (for example `Ready to implement (3 of 4 lenses; experience
   off by config)`; a lens that did not run counts as not run, even with `prior:`).
   **Never** Ready / all-clear / Ready to implement when any selected lens **failed**.
   **Review verdict rule:** Not ready while a P0 or P1 finding is open. Ready with fixes
   while a P2 finding is open. Otherwise Ready. Open means a Findings row with Status
   `open`; `fixed` and `declined` rows count as closed. A failed selected lens still
   blocks Ready.

No time estimates. No praise. Every finding actionable.

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

```json
{
  "status": "complete",
  "context": "review | audit | plan | plan-assist",
  "verdict": "...",
  "scope": { "...": "..." },
  "intent": "...",
  "lenses": ["predictability", "simplicity"],
  "findings": [],
  "actionable_findings": [],
  "tensions": [],
  "posture": null,
  "observations": [],
  "coverage": {},
  "artifact_path": null,
  "run_id": "<run-id>",
  "plugin_version": "<version>",
  "plugin_root": "~/<plugin root>",
  "repo_root": "~/<repo root>",
  "branch": "<branch>",
  "reviewed_sha": "<sha>",
  "tree_clean": true,
  "base_sha": "<fit-review only>",
  "completed_at": "2026-10-09T14:05:00+0200"
}
```
