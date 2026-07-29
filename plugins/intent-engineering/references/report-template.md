# Report Template

Canonical shape for the synthesized **published** report and the in-chat summary.
ASCII-safe (pipe tables, `->` not arrows, no box-drawing) so it degrades gracefully
across terminals.

**Two layers** (see `config-resolution.md` → Artifact paths):

| Layer | Default path | Contents |
|-------|--------------|----------|
| A — run scratch | `.intense/runs/<run-id>/` | per-lens `{lens}.json` while the run is open |
| B — published | `docs/intent-engineering/<stamp>-<skill>[-scope].md` | this report (or `.json` in `mode:agent`) |

Override Layer B with `out:<path>`. After a successful publish, Layer A is deleted when
`artifacts.cleanup_runs` is true (default). Include `run_id` in the Header so the run
is still identifiable after cleanup.

## Findings table (review & audit)

Group by severity. The `Issue` cell is one terse clause (the scannable index). Depth
goes in the keyed detail line, not the cell.

```
### P0 -- Critical surprise
| # | File | Issue | Principle | Lens | Conf |
|---|------|-------|-----------|------|------|
| 1 | `app/models/order.rb:42` | `fetch_total` also writes a cache row | least-astonishment | predictability | 100 |

- **#1** -- `fetch_total` is named as a pure read but persists a cache row as a side
  effect; a caller reading the name will not expect a write (and will be surprised in
  a transaction/read-replica context). Fix: rename to `fetch_and_cache_total`, or move
  the write to an explicit `refresh_total_cache!`.
```

Five columns. Keyed `- **#N** --` detail line for findings whose one-liner isn't
self-sufficient (usually P0/P1). Same table shape for every severity — never render
one severity as field-blocks and another as a table. Numbering is stable and
monotonic across the whole report.

## Report sections (in order)

1. **Header** — scope, intent, context (review/audit/plan), lens team with the
   one-line reason for each conditional lens.
2. **Applied** *(ie-review interactive only, when fixes were applied)* — `# | File |
   Fix | Lens`, then validation outcome + commit status. Applied findings appear here,
   not in the severity tables.
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
   remote-mode limits), confidence suppressions by anchor, and **per-lens status**:
   - **failed** — non-JSON return, missing `$RUN/{lens}.json`, missing required
     `scores` in audit/plan, or harness error after optional one re-dispatch.
   - **skipped** — not selected, or architecture pack absent (catalog ⬜ / no pack);
     promote `SKIPPED:` observations from the architecture agent here. Not the same
     as clean empty findings.
   - **clean** — valid return, analyzed, zero findings remaining after the confidence
     gate (or findings present and listed).
8. **Verdict** — review: Ready / Ready with fixes / Not ready. audit: top 3 posture
   gaps to fix first. plan: Ready to implement / Revise first, with the blocking gaps.
   **Never** Ready / all-clear / Ready to implement when any selected lens **failed**.

No time estimates. No praise. Every finding actionable.

## mode:agent (JSON)

When a skill runs `mode:agent`, emit one raw JSON object (no code fence) as the reply
instead of markdown, AND write that same object to the **published** path `$REPORT_PATH`
(Layer B — typically `docs/intent-engineering/<stamp>-<skill>[-scope].json`). Do **not**
write the mode:agent report into the run-scratch dir (`$RUN`); that dir is deleted when
`cleanup_runs` is true. Set `artifact_path` in the JSON to the same published path:

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
  "artifact_path": "docs/intent-engineering/<stamp>-<skill>[-scope].json",
  "run_id": "<run-id>"
}
```
