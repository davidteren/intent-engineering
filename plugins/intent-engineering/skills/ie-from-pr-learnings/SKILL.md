---
name: ie-from-pr-learnings
description: "Turn PR review comments, a triage markdown export, or open PR URLs into Intent Engineering config improvements — conventions.notes/sources, severity_overrides, optional pattern policy, and a short findings brief. Use when the user points at a PR, a PR stack triage doc, or wants to mine review learnings into .intense/."
argument-hint: "[path/to/triage.md | pr:<url-or-number> | stack] [out:<dir>]"
---

# Intent Engineering — From PR learnings

Mines **review learnings** (PR threads, triage tables, or human-written guardrail lists)
into **project `.intense/` config** so later `/ie-review` and `/ie-audit` runs enforce
what humans already fought for in review.

This skill **writes only under `.intense/`** (and optional report under the resolved
`artifacts.report_dir`). It never pushes, never opens PRs, and never clobbers existing
YAML without confirmation.

## When to use

- User has a triage doc (e.g. `PR-COMMENTS-TRIAGE-*.md` with G1…Gn guardrails).
- User points at one or more GitHub PRs after review.
- User wants workspace-level config for a multi-repo stack (BE + FE) via walk-up.

## Argument parsing

| Token | Effect |
|-------|--------|
| path ending in `.md` | Treat as triage / learnings document (primary). |
| `pr:<url\|number>` | Fetch review threads with `gh` (read-only). Repeatable. |
| `stack` / blank with multi-repo cwd | Prefer nearest `.intense/` walk-up; detect BE/FE siblings. |
| `config:<path>` | Override project config dir (same rules as config-resolution). |
| `out:<dir>` | Write the summary report under this dir (default: resolved `artifacts.report_dir`). |

## Procedure

### 1. Resolve project base + existing config

Per `${CLAUDE_PLUGIN_ROOT}/references/config-resolution.md`:

1. Discover `PROJECT_INTENSE` (walk-up / `config:` / `INTENSE_CONFIG_DIR`).
2. If none, create `.intense/` at the **workspace root** (for multi-repo stacks, the
   parent that contains backend/frontend-style siblings, not deep inside one app)
   after confirming with the user.
3. Load existing `ways-of-working.yaml` / `patterns.yaml` / `thresholds.yaml` if present.
4. Always record **Config source** for the report.

### 2. Collect learnings

**From a triage markdown** (preferred when available):

- Extract tables of guardrails (IDs like `G1`…, priority P0–P3, state).
- Prefer rows marked **P0/P1** and cross-stack guardrails.
- Capture “Wontfix + rationale” as **advisory notes** (do not invent severity P0).

**From `pr:` URLs:**

```bash
# For each PR: list unresolved + resolved review comments (titles + bodies)
gh api graphql …  # reviewThreads on the PR
# Or: gh api repos/{owner}/{repo}/pulls/{n}/comments
```

Cluster into themes: API versioning, security (tokens/query), FE client contract,
migrations, i18n, CSS tokens, tests serial, naming.

**From repo AGENTS.md / CLAUDE.md:**

- Always merge into `conventions.sources` paths (do not paste whole files into notes).

### 3. Map learnings → config fields

| Learning shape | Config target |
|----------------|---------------|
| Recurring house rule | `conventions.notes` one short line (G-id prefix if present) |
| Existing doc path | `conventions.sources` glob/path (relative to project base) |
| “CI/review blocks this” | `severity_overrides` with `{ severity, because }` |
| Pattern ban | `patterns.blocked` only if id exists in stack pattern catalog |
| Size complaints / fat modules | Suggest `thresholds` change; prefer `/ie-init calibrate` for numbers |

**Authority:** do not invent notes that contradict AGENTS.md; put AGENTS paths in
`sources` first. Notes win only when the team explicitly wants a stronger local rule.

### 4. Propose YAML patch (never silent clobber)

1. Show a **diff-style** summary: new notes, new sources, severity rows, threshold ideas.
2. Ask: **merge** (default) / **replace notes** (only with explicit confirm; overwrites
   `conventions.notes` with the proposed set) / **skip**. Never silent clobber.
3. On merge:
   - Append unique `notes` lines (skip exact duplicates).
   - Append unique `sources` paths that exist on disk.
   - Merge `severity_overrides` keys (show conflict if key already set differently).
4. On replace notes (user must restate overwrite intent): replace `conventions.notes`
   only; still merge sources/severities unless also confirmed.
5. Optionally write `docs/intent-engineering/<stamp>-from-pr-learnings.md` under the
   project (or `out:`) summarizing G-ids and source PRs for humans.
6. Never commit or push.

### 5. Optional calibrate handoff

If the triage or audit mentions fat models/controllers/stores **and** an Arch pack ✅
stack is present, recommend:

```
/ie-init calibrate p90
```

Do not re-implement full calibration here; link to `ie-init` Stage 2c.

### 6. Report

Write a short markdown report:

| Section | Content |
|---------|---------|
| Header | project base, Config path, sources used (triage path / PR list) |
| Guardrails ingested | table G-id / note / severity |
| Config changes | paths written |
| Suggested next | `/ie-review` on open PR, `/ie-audit` on feature path |
| Gaps | learnings that need product/security (do not auto-encode) |

## Quality bar

- Every `notes` line is **one enforceable sentence** (no essay).
- No secrets, tokens, or customer data from PR bodies.
- Client project names may stay if the triage already uses them; do not invent new ones.
- Idempotent: re-running the same triage should not duplicate notes.

## Reference files

- `${CLAUDE_PLUGIN_ROOT}/references/config-resolution.md` — walk-up, authority, sources base
- `${CLAUDE_PLUGIN_ROOT}/config/defaults/ways-of-working.yaml` — field shapes
- `${CLAUDE_PLUGIN_ROOT}/skills/ie-init/SKILL.md` — calibrate
- `${CLAUDE_PLUGIN_ROOT}/skills/ie-audit/SKILL.md` — posture after config lands
