---
name: fit-review
description: "Review code changes through the expectation-fit lenses (predictability, convention, simplicity, experience, and architecture on supported frameworks) — surfacing surprise, non-idiomatic patterns, needless complexity, UX gaps, and structural anti-patterns. Default (interactive) mode applies safe, verified fixes and commits on a clean tree (never pushes); mode:agent reports JSON only. Use on a PR, branch, or local changes before merging."
argument-hint: "[mode:agent] [out:<path>] [lenses:<list>] [base:<ref>] [prior:<report-path>] [plan:<path>] [blank = current branch, or a PR link/number/branch]"
---

# Expectation Fit — Code Review

Reviews a diff for **surprise**: code that doesn't behave the way a reasonable
developer or user expects, fights convention, adds needless complexity, or skips UX
essentials. Fans out the applicable lenses as parallel sub-agents (the four universal
lenses, plus architecture on a supported framework), merges and confidence-gates their
findings, and writes a report. This is the runtime complement
to the principle docs under `${CLAUDE_PLUGIN_ROOT}/resources/`.

Grok users: this skill is the Claude orchestrator. There is also the optional Grok
workflow in the source repository (not shipped with the plugin): a subset, with the
report in scratch and no apply.

## Argument parsing

Parse `$ARGUMENTS`; strip recognized tokens before treating the remainder as a PR
number/URL or branch.

`out:`, `prior:` and `lenses:` are shared tokens, defined once in
`${CLAUDE_PLUGIN_ROOT}/references/config-resolution.md` (Shared tokens). Their rows below
list only this skill's difference.

| Token | Effect |
|-------|--------|
| `mode:agent` | Report-only; emit JSON (report-template "mode:agent"); skip the apply stage. Writes a report file only with `out:`. |
| `out:<path>` | Shared token. Outside-repo only when explicitly given. |
| `base:<ref>` | Diff base on the current checkout (skip auto base detection). With a PR or branch target, `base:` sets the diff base and the target supplies only the intent. Coverage records the base, the PR and the HEAD SHA. To re-review after fix commits, pass the head_sha of the last report (local checkout only). |
| `prior:<report-path>` | Shared token. Never changes the diff range. |
| `plan:<path>` | Plan/spec for context (intent + scope alignment). Its decision lines go verbatim, with their ids, to every lens in `<known-context>` (Stage 2). |
| `config:<path>` | Override project config directory (see config-resolution). Else walk-up / `EXPECTATION_FIT_CONFIG_DIR`. |
| `lenses:<list>` | Shared token. |

## Operating principles

- **Apply locally; never push.** In default mode, apply the safe fixes you're
  confident in (Stage 5) and commit them as an isolated `fix(fit-review):` commit when
  the tree was clean; on a dirty tree apply but leave for the user. In `mode:agent`,
  change no product code and write no report file unless `out:` names one; run scratch
  ignores itself, so `git status` stays unchanged. The caller applies. Never push, open
  PRs, or file tickets.
- **No blocking prompts.** Infer intent and scope from tokens, git state, and the
  diff. Note uncertainty in Coverage; don't stop to ask.
- **Explicit mutations only.** Never `git checkout`/`switch` or `gh pr checkout`. A PR
  or branch argument selects *scope*, not permission to switch trees.
- **Caller constraints limit what the run fixes, never what it reports.** A finding that
  a caller constraint covers ("do not change X") stays in Findings at its severity and
  counts toward the verdict. Do not apply it: its Status stays `open` and its Issue ends
  with "(not applied: blocked by caller constraint)". Use Rejected with why
  `accepted_by_caller` only when the caller explicitly accepts the defect.
- **Read the repo's standards.** Convention findings hinge on local `CLAUDE.md`/
  `AGENTS.md` and existing patterns — those override generic ideals.

## Stage 1 — Scope

First **load resolved config** per `${CLAUDE_PLUGIN_ROOT}/references/config-resolution.md`
(walk-up / `config:` / `EXPECTATION_FIT_CONFIG_DIR`, then merge over
`${CLAUDE_PLUGIN_ROOT}/config/defaults/`). The resolved artifact folders feed the scope
exclusions below.

Compute the diff. Reuse the scope logic familiar from standard code-review skills:

- **`base:<ref>`** — `BASE=$(git merge-base HEAD <ref> 2>/dev/null) || BASE=<ref>`. The
  diff is the current checkout against `BASE`. A PR or branch target given with `base:`
  supplies only the intent (Stage 2). When `<ref>` is a SHA, first check
  `git merge-base --is-ancestor <ref> HEAD`. If the check fails (for example after a
  rebase), review the whole branch against its detected base and say so in Coverage.
- **PR number/URL** — `gh pr view` for metadata; do not checkout. Classify
  `local-aligned` (HEAD == PR head, not cross-repo, head is ancestor of HEAD) vs
  `pr-remote`. In `pr-remote`, lenses inspect via `git show <ref>:<path>` / diff hunks
  only.
- **Branch name** — resolve `origin/<branch>` without checkout; `branch-remote` scope.
  When `<branch>` is the current branch and `origin/<branch>` is an ancestor of HEAD
  (`git merge-base --is-ancestor origin/<branch> HEAD`), classify as `local-aligned`.
- **No argument** — current branch vs its detected base.

**Pin the reviewed commit** before any lens runs: `REVIEWED_SHA` is HEAD in
`local-aligned` and standalone scopes, the PR head SHA in `pr-remote`, and
`origin/<branch>` in `branch-remote`. `BASE_SHA=$(git rev-parse --short $BASE)`. Print
the report-template Provenance line (with `; base <base_sha>`) as the first output; the
run id joins it once Stage 4 makes one.

Build `EXCLUDES` per config-resolution (Scope exclusions), so earlier reports and run
scratch stay out of scope. Produce: `BASE`, `HEAD_REF` (the head the lenses read: the
working tree in `local-aligned`/standalone scope, `$REVIEWED_SHA` in `pr-remote` and
`branch-remote`), `FILES` (`git diff --name-only $BASE -- "${EXCLUDES[@]}"`, or
`git diff --name-only $BASE $REVIEWED_SHA -- "${EXCLUDES[@]}"` in remote scopes, so the
working tree never leaks into scope), `DIFF` (the same range with `-U10`), and
`UNTRACKED` (`git ls-files --others --exclude-standard`). Untracked files are out of
scope; list them in Coverage. If no base resolves, stop — don't fall back to
`git diff HEAD` (it would miss committed work).

**Empty diff.** If `FILES` is empty, dispatch no lens. Still load config and resolve the
report path (Stages 3 and 4). Write the normal Stage 6 report (JSON in `mode:agent`)
with no lenses, every catalog lens `not_selected` (reason: nothing to review), and this
Findings line:
`Nothing to review: no tracked changes between <base> and <head>; <N> untracked files not reviewed.`
Set the verdict to Ready only when `UNTRACKED` is also empty. When `UNTRACKED` is not
empty, give no Ready verdict: use Not ready. In `mode:agent`, reply with `status`
`failed` and `reason` "No tracked changes; <N> untracked files not reviewed". Then
stop. This stop comes before lens selection, so a lens set
to `on` does not run.

**Plan-only diff.** Hand off when no changed file is code and at least one is a plan,
spec or requirements doc. Such a doc has implementation units (U1, U2), R/A/F ids, or
actors and flows (see fit-validate-plan Stage 1). Files that steer agents count as code
here: SKILL.md, agent, command and rule files, AGENTS.md and CLAUDE.md. When unsure,
take the normal path. Hand off only in `local-aligned` and standalone scopes, where the
working tree is the reviewed tree. To hand off, say: "No code in this diff; running
fit-validate-plan instead." Run `fit-validate-plan` once on all changed docs, with the
same `mode:agent`, `out:`, `config:` and `lenses:` tokens. Its report and verdict are the
result of this run. Write no review report. In `mode:agent`, the reply keeps the plan
verdict words (Ready to implement / Revise first) and sets `handoff` to
`"fit-validate-plan"`. In `pr-remote` and `branch-remote`
scopes, do not hand off, because fit-validate-plan reads the working tree, not
`$REVIEWED_SHA`. Instead stop and say: "No code in this diff. Check out <branch> and run
fit-validate-plan on: <docs>." Write no review report. In `mode:agent`, reply with
`status` `skipped`, that message as `reason`, and `handoff` set to `"fit-validate-plan"`.

Also capture **`TREE_CLEAN`**: `git status --porcelain` empty at this moment (before any
write). Stage 5 uses this flag for the optional commit (do not re-check after apply).

## Stage 2 — Intent

Summarize what the change is trying to do (2-3 lines) from the PR body / commit log
(`git log --oneline $BASE..HEAD`) / `plan:` / conversation. Pass it to every lens;
intent shapes how hard each lens looks, not which lenses run.

With `plan:`, also quote the plan's decision lines verbatim, with their ids, into the
`<known-context>` block for every lens. R, A and KTD items and "Locked decisions"
sections are examples, not a required format. Without `plan:`, do not look for a plan
in the PR body or commit log: a stale plan would hide real findings. Coverage says
`Plan: <path>` or `Plan: none`.

If the diff changes only docs, a CHANGELOG or a version number, add this line to the
intent: "Check each changed claim against the code and the other docs: versions, status
lines and links. Also read the docs outside the diff that state the same fact." Lens
selection does not change.

## Stage 3 — Select lenses

Use the config resolved in Stage 1. The resolved `lenses:` block is authoritative for selection (`on`/`off`/`auto`); the
resolved `conventions` (including `sources` + **`auto`** discovery), `severity_align`,
`confidence_gate`, `thresholds`, and pattern policy feed the lenses and synthesis.
**Always** put an explicit Config line in Coverage, plus auto-source counts when
`conventions.auto.mode` is not `off`. Then read
`${CLAUDE_PLUGIN_ROOT}/references/lens-catalog.md` for selection rules and
`${CLAUDE_PLUGIN_ROOT}/references/stack-catalog.md` for stack detection + Arch pack
status. **Do not hardcode stack lists here** — the catalog is the only source of truth.

- **Always-on:** `fit-predictability-reviewer`, `fit-simplicity-reviewer`.
- **`fit-convention-reviewer`:** on for essentially all code review (there is almost
  always a framework, repo standard, or sibling pattern to be consistent with). Detect
  the stack(s) from the catalog's Detection signals column; load matching
  `frameworks/<stack>.md` docs for every stack that has a Convention doc.
- **`fit-experience-reviewer`:** when the scope touches a surface in the
  `lens-catalog.md` list.
- **`fit-architecture-reviewer`:** when the catalog has **Arch pack ✅** for a detected
  stack **and** the diff touches structural code for that stack (not config/docs/test-only
  with no structural change). Use the catalog Detection signals and pack paths — never a
  closed two-stack list. Pass the resolved `thresholds` + pattern policy + the
  `tools.architecture` preference (`enrich`/`prefer`/`report`/`off`).

Honor the config `lenses:` toggles over these defaults (`off` forces a lens off even if
relevant; `on` forces it on; `auto` = the judgment above). A `lenses:<list>` token wins
over both: run exactly the listed lenses.

Find standards paths first: Glob `**/CLAUDE.md` and `**/AGENTS.md` whose directory is an
ancestor of a changed file. Pass them in `<standards-paths>`, with the resolved
`conventions.notes`, to every selected lens. Keep `conventions.sources` and
`conventions.auto` with the convention lens only, because auto discovery can expand to
many files.

Before dispatching, announce every catalog lens with its selection and a one-line
reason, for example `experience: not_selected, no user-facing paths in scope`. This is
progress reporting, not a confirmation prompt.

## Stage 4 — Dispatch

Resolve artifact paths per `${CLAUDE_PLUGIN_ROOT}/references/config-resolution.md`
(Artifact paths). Bind skill slots only — do **not** re-author the path bash:

| Slot | Value |
|------|--------|
| `SKILL_SLUG` | `review` |
| `SCOPE` | raw branch or PR (the canonical block makes the slug), or empty |
| `OUT_ARG` | `out:` value or empty |
| `EXT` | `md` normally; `json` when `mode:agent` |

Then run the **canonical** stamp / `RUN_ID` / `REPORT_PATH` procedure from that doc.
Bind **`run_artifact_dir = $RUN`** (Layer A only), `plugin_root = $PLUGIN_ROOT`, and
`reviewed_sha = $REVIEWED_SHA`. Bind `repo_root` to `git rev-parse --show-toplevel`,
`base` to `BASE` from Stage 1, and `plan_path` to the `plan:` path when one is given.

Write the Stage 1 `DIFF` to `$RUN/diff.patch`. Pass each lens that path, its line count
and `git diff --stat $BASE`, not the diff inline. A large diff then never gets cut off
in the lens prompt.

Spawn each selected lens in parallel using `${CLAUDE_PLUGIN_ROOT}/references/subagent-template.md`
with `Context: review`. **Model policy** (same as the template): pass `model: sonnet` to
convention, experience, and **architecture**; let predictability and simplicity inherit
the session model. Respect the harness active-subagent cap (queue and backfill;
capacity errors are backpressure, not failure). Each lens writes `$RUN/{lens}.json`
(via the Write tool) and returns compact JSON.

## Stage 5 — Merge, gate, act

Read `${CLAUDE_PLUGIN_ROOT}/references/findings-schema.json` for field rules and
`${CLAUDE_PLUGIN_ROOT}/references/report-template.md` for output shape (including
**Lens status**).

Run steps 1 to 6 of **Merge and gate** in
`${CLAUDE_PLUGIN_ROOT}/references/report-template.md` (validate and repair, dedup,
agreement, config policy, confidence gate, tensions). In step 1, **verify lines**
before dedup: grep for the first line of each evidence quote (`grep -n -F`, or on
`git show $REVIEWED_SHA:<path>` in remote scopes) and set `line` from the hit. With no
hit, keep the finding and list its line as unverified in Coverage. Then:

7. **Act (default mode only; skip in `mode:agent`).** Apply only findings that pass
   **all** of: `fix_class: gated_auto` (reclassify over-broad ones to `manual` first;
   see subagent-template `fix_class` rubric), `confidence` ≥ 75, severity P2 or P3, a
   concrete `suggested_fix`, carries no `tension`, and does not name a prior declined #N
   or match a prior declined row by the dedup key (Merge and gate step 2). Apply only
   when the working tree is what was reviewed (`local-aligned`/standalone), never in
   `pr-remote`/`branch-remote`, and only while HEAD still equals `REVIEWED_SHA`. If HEAD
   moved, skip apply and print `Reviewed <sha>; HEAD moved to <sha>`.

   **Verify first:** one read-only sub-agent re-reads the cited lines of every finding
   that passes this gate, with this prompt: "Adversarially verify this finding against
   the target the lenses used. Set real=true only with concrete evidence you inspected
   yourself. If you cannot open the file, the claim is wrong, or the evidence is thin,
   set real=false." Apply only confirmed findings. A refuted finding goes to Rejected
   with why `not_real`. In the Fallback, the orchestrator re-reads the lines itself and
   Coverage says so.

   **Check for copies:** before a fix that replaces text, search the repo for a key
   phrase of the old text. Also check every copy that a lens named in a finding or an
   observation. If all copies sit in the touched file and take the same edit, fix them
   all in one commit. Otherwise do not apply the fix: reclassify it to manual and list
   each copy in it. Historical text, such as CHANGELOG entries and dated reports, does
   not count as a copy.

   After applying, run affected tests/lint; if they fail, revert that fix and report it
   instead. If **`TREE_CLEAN` was true in Stage 1**, commit applied fixes as one
   `fix(fit-review): <summary>` commit and record its real SHA
   (`git rev-parse --short HEAD`) for Applied; if it was false, apply but leave
   uncommitted. Set each finding's Status at run time: `fixed <sha>` for applied ones,
   `declined: <reason>` only for an explicit owner or caller decision, else `open`. A
   skipped taste call or conflicting suggestion stays `open`, and its Issue ends with
   "(not applied: taste call)". A finding the run believes is wrong goes to Rejected
   with why `not_real`.
   The `fix(fit-review)` commit holds only fixes that pass this gate. A caller that fixes
   other findings commits those fixes separately, after this skill reports.

   Push back (don't apply) when a lens is wrong; skip taste calls and conflicting
   suggestions but surface what was skipped. Never push. Observations are never
   applied. They stay in the Observations section.

## Stage 6 — Report

Write the report to `$REPORT_PATH` (markdown) per
`${CLAUDE_PLUGIN_ROOT}/references/report-template.md`. In `mode:agent`, reply with the
JSON per the mode:agent section there and write it to `$REPORT_PATH` only when `out:`
was passed (never into `$RUN`). Sections: Header (per report-template, with the
Provenance line, run_id, branch, head_sha, verdict and completed_at), Applied (if any),
Findings (P0..P3 tables, terse `Issue` cell, keyed detail lines, `Principle` + `Lens`
columns), Tensions, Observations, Coverage (the status of every catalog lens per the
report-template Lens status table, READ lines, Cost), Verdict (Ready / Ready with fixes /
Not ready, per the report-template verdict rule). **Do not** use Ready / all-clear when
a lens status or a partial read blocks it. No time estimates. Every finding actionable.
Stop re-running at Ready. Log P3 items without another round.

**mode:agent fields:** see the mode:agent section of
`${CLAUDE_PLUGIN_ROOT}/references/report-template.md`. Its field list and example are the
single source.

Then: if `CLEANUP` is true, run the **guarded** cleanup from
`${CLAUDE_PLUGIN_ROOT}/references/config-resolution.md` (only when
`$RUN` equals `$RUN_DIR/$RUN_ID`). Always print the `Report:` line from that doc
(absolute path).

## Quality gates

Before delivering: every finding names a broken expectation (not just "surprising");
no false positives from skimming (the "bug" isn't handled elsewhere); severity
calibrated (a naming nit is never P0); line numbers verified; repo-local conventions
respected (a consistent local choice isn't a violation); nothing the linter already
catches.

## Fallback

No sub-agents: follow "When you cannot spawn agents" in
`${CLAUDE_PLUGIN_ROOT}/references/subagent-template.md`. Concurrency cap: use the queue/
backfill rule. Everything else unchanged.

---

## Reference files (read at runtime)

This skill depends on `${CLAUDE_PLUGIN_ROOT}` resolving to the plugin dir (standard in
Claude Code). Read these contract files before Stage 1 — they are the single source of
truth, shared by every `fit-*` skill:

- `${CLAUDE_PLUGIN_ROOT}/references/config-resolution.md` — load/merge .expectation-fit config + artifact paths
- `${CLAUDE_PLUGIN_ROOT}/references/lens-catalog.md` — lenses + selection rules
- `${CLAUDE_PLUGIN_ROOT}/references/stack-catalog.md` — stack detection + Arch pack ✅
- `${CLAUDE_PLUGIN_ROOT}/references/subagent-template.md` — dispatch + confidence + fix_class
- `${CLAUDE_PLUGIN_ROOT}/references/findings-schema.json` — finding contract
- `${CLAUDE_PLUGIN_ROOT}/references/report-template.md` — output shape + lens status

Lens detection heuristics live in `${CLAUDE_PLUGIN_ROOT}/resources/`; the lens agents
read those themselves.

**Plugin root.** `PLUGIN_ROOT` is the absolute path two folders above this file's
folder. Bind it as `{plugin_root}` in every lens prompt (subagent-template, Slot
bindings), so no lens prompt carries a literal plugin-root variable.
