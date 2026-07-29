---
name: ie-review
description: "Review code changes through the intent-engineering lenses (predictability, convention, simplicity, experience, and architecture on supported frameworks) — surfacing surprise, non-idiomatic patterns, needless complexity, UX gaps, and structural anti-patterns. Default (interactive) mode applies safe, verified fixes and commits on a clean tree (never pushes); mode:agent reports JSON only. Use on a PR, branch, or local changes before merging."
argument-hint: "[mode:agent] [out:<path>] [base:<ref>] [plan:<path>] [blank = current branch, or a PR link/number/branch]"
---

# Intent Engineering — Code Review

Reviews a diff for **surprise**: code that doesn't behave the way a reasonable
developer or user expects, fights convention, adds needless complexity, or skips UX
essentials. Fans out the applicable lenses as parallel sub-agents (the four universal
lenses, plus architecture on a supported framework), merges and confidence-gates their
findings, and writes a report. This is the runtime complement
to the principle docs under `${CLAUDE_PLUGIN_ROOT}/resources/`.

## Argument parsing

Parse `$ARGUMENTS`; strip recognized tokens before treating the remainder as a PR
number/URL or branch.

| Token | Effect |
|-------|--------|
| `mode:agent` | Report-only; emit JSON (report-template "mode:agent"); skip the apply stage. |
| `out:<path>` | Override **published** report path (file or dir). Defaults: scratch `.intense/runs/<run-id>/`, publish `docs/intent-engineering/<stamp>-review[-scope].md`. Outside-repo only when explicitly given. |
| `base:<ref>` | Diff base on the current checkout (skip auto base detection). Do not combine with a PR/branch target. |
| `plan:<path>` | Plan/spec for context (intent + scope alignment). |
| `config:<path>` | Override project config directory (see config-resolution). Else walk-up / `INTENSE_CONFIG_DIR`. |

## Operating principles

- **Apply locally; never push.** In default mode, apply the safe fixes you're
  confident in (Stage 5) and commit them as an isolated `fix(ie-review):` commit when
  the tree was clean; on a dirty tree apply but leave for the user. In `mode:agent`,
  mutate nothing — the caller applies. Never push, open PRs, or file tickets.
- **No blocking prompts.** Infer intent and scope from tokens, git state, and the
  diff. Note uncertainty in Coverage; don't stop to ask.
- **Explicit mutations only.** Never `git checkout`/`switch` or `gh pr checkout`. A PR
  or branch argument selects *scope*, not permission to switch trees.
- **Read the repo's standards.** Convention findings hinge on local `CLAUDE.md`/
  `AGENTS.md` and existing patterns — those override generic ideals.

## Stage 1 — Scope

Compute the diff. Reuse the scope logic familiar from standard code-review skills:

- **`base:<ref>`** — `BASE=$(git merge-base HEAD <ref> 2>/dev/null) || BASE=<ref>`.
- **PR number/URL** — `gh pr view` for metadata; do not checkout. Classify
  `local-aligned` (HEAD == PR head, not cross-repo, head is ancestor of HEAD) vs
  `pr-remote`. In `pr-remote`, lenses inspect via `git show <ref>:<path>` / diff hunks
  only.
- **Branch name** — resolve `origin/<branch>` without checkout; `branch-remote` scope.
- **No argument** — current branch vs its detected base.

Produce: `BASE`, `FILES` (`git diff --name-only $BASE`), `DIFF` (`git diff -U10 $BASE`),
`UNTRACKED` (`git ls-files --others --exclude-standard`). Untracked files are out of
scope; list them in Coverage. If no base resolves, stop — don't fall back to
`git diff HEAD` (it would miss committed work).

Also capture **`TREE_CLEAN`**: `git status --porcelain` empty at this moment (before any
write). Stage 5 uses this flag for the optional commit (do not re-check after apply).

## Stage 2 — Intent

Summarize what the change is trying to do (2-3 lines) from the PR body / commit log
(`git log --oneline $BASE..HEAD`) / `plan:` / conversation. Pass it to every lens;
intent shapes how hard each lens looks, not which lenses run.

## Stage 3 — Select lenses

First **load resolved config** per `${CLAUDE_PLUGIN_ROOT}/references/config-resolution.md`
— discover nearest `.intense/` via **walk-up** (or `config:` / `INTENSE_CONFIG_DIR`),
then deep-merge over `${CLAUDE_PLUGIN_ROOT}/config/defaults/`.
The resolved `lenses:` block is authoritative for selection (`on`/`off`/`auto`); the
resolved `conventions` (including `sources`), `confidence_gate`, `thresholds`, and
pattern policy feed the lenses and synthesis. **Always** put an explicit Config line in
Coverage, e.g. `Config: project:/path/.intense (walked up from <cwd>)` or
`Config: defaults (no .intense/ found, searched from <cwd>)`. Then read
`${CLAUDE_PLUGIN_ROOT}/references/lens-catalog.md` for selection rules and
`${CLAUDE_PLUGIN_ROOT}/references/stack-catalog.md` for stack detection + Arch pack
status. **Do not hardcode stack lists here** — the catalog is the only source of truth.

- **Always-on:** `ie-predictability-reviewer`, `ie-simplicity-reviewer`.
- **`ie-convention-reviewer`:** on for essentially all code review (there is almost
  always a framework, repo standard, or sibling pattern to be consistent with). Detect
  the stack(s) from the catalog's Detection signals column; load matching
  `frameworks/<stack>.md` docs for every stack that has a Convention doc.
- **`ie-experience-reviewer`:** when the diff touches a user-facing surface (UI
  components, frontend files, templates/views/partials, CLI UX) **or** full-stack
  changes that include those paths alongside backend. Skip only for pure
  backend/lib/infra with no template/UI path.
- **`ie-architecture-reviewer`:** when the catalog has **Arch pack ✅** for a detected
  stack **and** the diff touches structural code for that stack (not config/docs/test-only
  with no structural change). Use the catalog Detection signals and pack paths — never a
  closed two-stack list. Pass the resolved `thresholds` + pattern policy + the
  `tools.architecture` preference (`enrich`/`prefer`/`report`/`off`).

Honor the config `lenses:` toggles over these defaults (`off` forces a lens off even if
relevant; `on` forces it on; `auto` = the judgment above).

For the convention and architecture lenses, find standards paths first: Glob
`**/CLAUDE.md` and `**/AGENTS.md` whose directory is an ancestor of a changed file; pass
them in `<standards-paths>`. Also pass the resolved `.intense` conventions/notes.

Announce the lens team with a one-line reason for each conditional lens before
dispatching. This is progress reporting, not a confirmation prompt.

## Stage 4 — Dispatch

Resolve artifact paths per `${CLAUDE_PLUGIN_ROOT}/references/config-resolution.md`
(Artifact paths). Bind skill slots only — do **not** re-author the path bash:

| Slot | Value |
|------|--------|
| `SKILL_SLUG` | `review` |
| `SCOPE_SLUG` | sanitized branch/PR slug, or empty |
| `OUT_ARG` | `out:` value or empty |
| `EXT` | `md` normally; `json` when `mode:agent` |

Then run the **canonical** stamp / `RUN_ID` / `REPORT_PATH` procedure from that doc.
Bind **`run_artifact_dir = $RUN`** (Layer A only).

Spawn each selected lens in parallel using `${CLAUDE_PLUGIN_ROOT}/references/subagent-template.md`
with `Context: review`. **Model policy** (same as the template): pass `model: sonnet` to
convention, experience, and **architecture**; let predictability and simplicity inherit
the session model. Respect the harness active-subagent cap (queue and backfill;
capacity errors are backpressure, not failure). Each lens writes `$RUN/{lens}.json`
(via the Write tool) and returns compact JSON.

## Stage 5 — Merge, gate, act

Read `${CLAUDE_PLUGIN_ROOT}/references/findings-schema.json` for field rules and
`${CLAUDE_PLUGIN_ROOT}/references/report-template.md` for output shape (including
**Lens status**: failed / skipped / clean).

1. **Validate** each return; assign per-lens status (failed / skipped / clean). Drop
   malformed *findings* (record the count) but mark the **lens failed** on non-JSON,
   missing `$RUN/{lens}.json`, or a selected lens that never returned. One re-dispatch
   is allowed on non-JSON; still failed after that.
2. **Dedup** by `normalize(file) + line(+/-3) + normalize(title)`. Merge duplicates;
   keep highest severity + confidence; record which lenses flagged it.
3. **Cross-lens agreement** — 2+ lenses on the same fingerprint: promote one anchor
   step (50->75, 75->100). Note the agreeing lenses.
4. **Confidence gate** — suppress findings below the resolved `confidence_gate`
   (default anchor 75), EXCEPT P0 at 50+ (a critical-but-uncertain surprise must not be
   dropped silently). Record suppressions by anchor.
4b. **Apply config policy** — remap severities per `severity_overrides`; suppress
   architecture findings whose file matches an `approved` path (note in Coverage); keep
   `blocked`-pattern-in-changed-code findings at P1.
5. **Collect tensions** — findings carrying a `tension` go to the Tensions section.
6. **Act (default mode only; skip in `mode:agent`).** Apply only findings that pass
   **all** of: `fix_class: gated_auto` (reclassify over-broad ones to `manual` first;
   see subagent-template `fix_class` rubric), `confidence` ≥ 75, severity ≤ P2, and a
   concrete `suggested_fix`. Apply only when the working tree is what was reviewed
   (`local-aligned`/standalone) — never in `pr-remote`/`branch-remote`. After applying,
   run affected tests/lint; if they fail, revert that fix and report it instead. If
   **`TREE_CLEAN` was true in Stage 1**, commit applied fixes as one
   `fix(ie-review): <summary>` commit; if it was false, apply but leave uncommitted.
   Push back (don't apply) when a lens is wrong; skip taste calls and conflicting
   suggestions but surface what was skipped. Never push.

## Stage 6 — Report

Write the published report to `$REPORT_PATH` (markdown, or JSON in `mode:agent`) per
`${CLAUDE_PLUGIN_ROOT}/references/report-template.md` — including the mode:agent section
there (JSON goes to `$REPORT_PATH`, never into `$RUN`). Include run_id, branch, head_sha,
verdict, completed_at in the Header (and in the JSON object when `mode:agent`). Sections:
Header, Applied (if any), Findings (P0..P3 tables, terse `Issue` cell, keyed detail
lines, `Principle` + `Lens` columns), Tensions, Observations, Coverage (including each
selected lens's failed/skipped/clean status), Verdict (Ready / Ready with fixes / Not
ready). **Do not** use Ready / all-clear when any selected lens **failed**. No time
estimates. Every finding actionable.

Then: if `CLEANUP` is true, run the **guarded** cleanup from
`${CLAUDE_PLUGIN_ROOT}/references/config-resolution.md` (only when
`$RUN` equals `$RUN_DIR/$RUN_ID`). Always tell the user `Report: $REPORT_PATH`.

## Quality gates

Before delivering: every finding names a broken expectation (not just "surprising");
no false positives from skimming (the "bug" isn't handled elsewhere); severity
calibrated (a naming nit is never P0); line numbers verified; repo-local conventions
respected (a consistent local choice isn't a violation); nothing the linter already
catches.

## Fallback

No parallel sub-agents: run lenses sequentially. Concurrency cap: use the queue/
backfill rule. Everything else unchanged.

---

## Reference files (read at runtime)

This skill depends on `${CLAUDE_PLUGIN_ROOT}` resolving to the plugin dir (standard in
Claude Code). Read these contract files before Stage 3 — they are the single source of
truth, shared by every `ie-*` skill:

- `${CLAUDE_PLUGIN_ROOT}/references/config-resolution.md` — load/merge .intense config + artifact paths
- `${CLAUDE_PLUGIN_ROOT}/references/lens-catalog.md` — lenses + selection rules
- `${CLAUDE_PLUGIN_ROOT}/references/stack-catalog.md` — stack detection + Arch pack ✅
- `${CLAUDE_PLUGIN_ROOT}/references/subagent-template.md` — dispatch + confidence + fix_class
- `${CLAUDE_PLUGIN_ROOT}/references/findings-schema.json` — finding contract
- `${CLAUDE_PLUGIN_ROOT}/references/report-template.md` — output shape + lens status

Lens detection heuristics live in `${CLAUDE_PLUGIN_ROOT}/resources/`; the lens agents
read those themselves.
