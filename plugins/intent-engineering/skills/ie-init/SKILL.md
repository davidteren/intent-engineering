---
name: ie-init
description: "Scaffold Intent Engineering project config into a repo's .intense/ directory — ways-of-working, pattern policy (allow/block/approved), and architecture thresholds — so the team can tune the lenses and commit the settings. Stack-aware menu; idempotent (never clobbers existing config without confirmation). Use to set up or extend a project's .intense/ config."
argument-hint: "[all | ways | patterns | thresholds] (blank = menu)"
---

# Intent Engineering — Init project config

Copies starter config templates from the plugin defaults into the project's `.intense/`
directory so a team can declare its "ways of working" (lens toggles, conventions),
design-pattern policy (allow / block / pre-approved), and architecture thresholds — then
commit them. Once present, `.intense/` supersedes the plugin defaults
(`config-resolution.md`) for every `ie-*` run in that repo.

## Interactive tool

If presenting the menu interactively in Claude Code, **pre-load `AskUserQuestion`**
(deferred tool): call `ToolSearch` with `select:AskUserQuestion` once before the menu.
If the harness has no blocking-question tool (ToolSearch returns nothing / call fails),
fall back to a numbered list and wait for the user's reply — never silently pick.

## Procedure

### 1. Resolve target + detect stack

- Target dir is `.intense/` at the repo root (current working directory's repo).
- Detect the stack to pre-select relevant templates and pre-fill comments:
  - **Rails:** `Gemfile` with `rails`, or `config/application.rb`, or `app/models`.
  - (Other stacks: thresholds/patterns templates are Rails-oriented today; still offer
    `ways-of-working.yaml`, which is stack-agnostic, and note that pattern/threshold
    packs for this stack aren't available yet.)

### 2. Choose what to scaffold

Parse `$ARGUMENTS`: `all`, `ways`, `patterns`, `thresholds` select directly. Blank →
present the menu (multi-select):

| Option | File created | What it controls |
|--------|--------------|------------------|
| Ways of working | `.intense/ways-of-working.yaml` | lens toggles, severity overrides, local conventions, confidence gate, report dir |
| Pattern policy | `.intense/patterns.yaml` | allowed / blocked / pre-approved design patterns, unknown-pattern handling |
| Thresholds | `.intense/thresholds.yaml` | architecture metric limits (fat model/controller, God object, service object, …) |
| All | all three | full config set |

Recommend **All** for a first run.

### 3. Copy templates (idempotent)

Source templates are `${CLAUDE_PLUGIN_ROOT}/config/defaults/<file>`. For each selected
file:

```bash
mkdir -p .intense
SRC="${CLAUDE_PLUGIN_ROOT}/config/defaults/<file>"
DST=".intense/<file>"
if [ -e "$DST" ]; then echo "EXISTS: $DST"; else cp "$SRC" "$DST" && echo "CREATED: $DST"; fi
```

- **Never overwrite an existing `.intense/<file>`** without explicit confirmation — a
  surprising clobber of committed team config is the failure mode to avoid (least
  astonishment / no data loss). If a target exists, report it and ask whether to
  overwrite, diff, or skip; default to **skip**.
- The copied files keep their explanatory comments so the team can edit in place.

### 4. Report

List what was created vs skipped. Then tell the user:

- The files are **meant to be committed** (they're project config, not artifacts) — do
  NOT add `.intense/` to `.gitignore`.
- Edit them to taste; every `ie-*` run in this repo now merges them over the plugin
  defaults (project wins; lists replace unless `extends: true`).
- Suggest the natural next step: run `/ie-audit` to see the current posture under the
  new config.

This skill only writes under `.intense/`. It never edits other project files, commits,
or pushes.

---

## Reference files (read at runtime)

- `${CLAUDE_PLUGIN_ROOT}/references/config-resolution.md` — how the scaffolded files are
  merged and consumed
- `${CLAUDE_PLUGIN_ROOT}/config/defaults/` — the source templates
