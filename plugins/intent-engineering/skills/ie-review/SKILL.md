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
| `out:<path>` | Override report dir. Default `wip/intent-engineering/<run-id>/` in the repo. Outside-repo only when explicitly given. |
| `base:<ref>` | Diff base on the current checkout (skip auto base detection). Do not combine with a PR/branch target. |
| `plan:<path>` | Plan/spec for context (intent + scope alignment). |

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

## Stage 2 — Intent

Summarize what the change is trying to do (2-3 lines) from the PR body / commit log
(`git log --oneline $BASE..HEAD`) / `plan:` / conversation. Pass it to every lens;
intent shapes how hard each lens looks, not which lenses run.

## Stage 3 — Select lenses

First **load resolved config** per `${CLAUDE_PLUGIN_ROOT}/references/config-resolution.md`
— merge project `.intense/*.yaml` (repo root) over `${CLAUDE_PLUGIN_ROOT}/config/defaults/`.
The resolved `lenses:` block is authoritative for selection (`on`/`off`/`auto`); the
resolved `conventions`, `confidence_gate`, `thresholds`, and pattern policy feed the
lenses and synthesis. Note the config source in Coverage. Then read
`${CLAUDE_PLUGIN_ROOT}/references/lens-catalog.md` for selection rules.

- **Always-on:** `ie-predictability-reviewer`, `ie-simplicity-reviewer`.
- **`ie-convention-reviewer`:** on for essentially all code review (there is almost
  always a framework, repo standard, or sibling pattern to be consistent with). Detect
  the stack(s) from file extensions/paths to pick the `frameworks/<stack>.md` doc(s).
- **`ie-experience-reviewer`:** only when the diff touches a user-facing surface (UI
  components, frontend files, templates/views, CLI UX). Skip for pure backend/lib/infra.
- **`ie-architecture-reviewer`:** when a supported framework is detected and the diff
  touches structural code. **Rails:** a `Gemfile`/`config/application.rb` + changes to
  `app/models`, `app/controllers`, `app/services`, `app/interactors`, or similar.
  **Python:** a `pyproject.toml`/`setup.py`/`setup.cfg` + changes to `.py` sources
  (routers, services, models/schemas, dependencies, app factory). Skip when no supported
  framework, or the diff is config/docs/test-only with no structural change. Pass it the
  resolved `thresholds` + pattern policy + the `tools.architecture` preference
  (`enrich`/`prefer`/`report`/`off`).

Honor the config `lenses:` toggles over these defaults (`off` forces a lens off even if
relevant; `on` forces it on; `auto` = the judgment above).

For the convention and architecture lenses, find standards paths first: Glob
`**/CLAUDE.md` and `**/AGENTS.md` whose directory is an ancestor of a changed file; pass
them in `<standards-paths>`. Also pass the resolved `.intense` conventions/notes.

Announce the lens team with a one-line reason for each conditional lens before
dispatching. This is progress reporting, not a confirmation prompt.

## Stage 4 — Dispatch

Generate a run id and artifact dir:

```bash
RUN_ID=$(date +%Y%m%d-%H%M%S)-$(head -c4 /dev/urandom | od -An -tx1 | tr -d ' ')
# OUT precedence: out: arg > resolved ways-of-working.report_dir > built-in default.
# Bind these two from earlier stages so the precedence below is executable:
OUT_ARG="<the out: value parsed in Argument parsing, or empty>"
REPORT_DIR="<resolved ways-of-working.report_dir from the Stage 3 config, or empty>"
OUT="${OUT_ARG:-${REPORT_DIR:-wip/intent-engineering}/$RUN_ID}"
mkdir -p "$OUT"
```

Spawn each selected lens in parallel using `${CLAUDE_PLUGIN_ROOT}/references/subagent-template.md`
with `Context: review`. **Bind `run_artifact_dir = $OUT`** when filling the template
(the template's `{run_artifact_dir}` is this skill's `$OUT`). Pass model `sonnet` to
convention and experience; let predictability and simplicity inherit the session model
(highest-stakes reasoning). Respect the harness active-subagent cap (queue and backfill;
capacity errors are backpressure, not failure). Each lens writes `$OUT/{lens}.json`
(via the Write tool) and returns compact JSON.

## Stage 5 — Merge, gate, act

Read `${CLAUDE_PLUGIN_ROOT}/references/findings-schema.json` for field rules and
`report-template.md` for output shape.

1. **Validate** each return; drop malformed findings (record the count).
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
6. **Act (default mode only; skip in `mode:agent`).** Apply the fixes that are clear,
   reversible improvements with a concrete `suggested_fix` (`fix_class: gated_auto`).
   Apply only when the working tree is what was reviewed (`local-aligned`/standalone) —
   never in `pr-remote`/`branch-remote`. After applying, run affected tests/lint; if
   they fail, revert that fix and report it instead. If the tree was clean before the
   review, commit applied fixes as one `fix(ie-review): <summary>` commit; if dirty,
   apply but leave uncommitted. Push back (don't apply) when a lens is wrong; skip
   taste calls and conflicting suggestions but surface what was skipped. Never push.

## Stage 6 — Report

Write `$OUT/report.md` (or `$OUT/report.json` in `mode:agent`) per the report template, and
`$OUT/metadata.json` (run_id, branch, head_sha, verdict, completed_at). Sections:
Header, Applied (if any), Findings (P0..P3 tables, terse `Issue` cell, keyed detail
lines, `Principle` + `Lens` columns), Tensions, Observations, Coverage, Verdict
(Ready / Ready with fixes / Not ready). No time estimates. Every finding actionable.

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

- `${CLAUDE_PLUGIN_ROOT}/references/config-resolution.md` — load/merge .intense config
- `${CLAUDE_PLUGIN_ROOT}/references/lens-catalog.md` — lenses + selection rules
- `${CLAUDE_PLUGIN_ROOT}/references/subagent-template.md` — dispatch + confidence rubric
- `${CLAUDE_PLUGIN_ROOT}/references/findings-schema.json` — finding contract
- `${CLAUDE_PLUGIN_ROOT}/references/report-template.md` — output shape

Lens detection heuristics live in `${CLAUDE_PLUGIN_ROOT}/resources/`; the lens agents
read those themselves.
