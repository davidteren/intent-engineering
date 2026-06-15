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
- **Read `${CLAUDE_PLUGIN_ROOT}/references/stack-catalog.md` — the registry is the source
  of truth for detection and which pack a stack carries.** Match the repo against its
  `Detection signals` column to identify the stack(s). Do not hardcode detection here; the
  catalog owns it, so a newly-added stack works without editing this skill.
- Note each detected stack's **Arch pack** status and **Threshold ns** from the catalog:
  - **Arch pack ✅** (today: `rails`, `python`) — the stack has a `<stack>.*` threshold
    namespace and a pattern catalog. Scaffold *that stack's* namespace (Step 3), not the
    whole multi-stack file.
  - **Arch pack ⬜** (convention-only: `ruby`, `typescript`, `react`, `swift-ios`) — no
    threshold/pattern pack yet. Offer `ways-of-working.yaml` (stack-agnostic) and say the
    architecture pack for this stack isn't available.
  - **Unknown / no match** — offer `ways-of-working.yaml` only; note no pack was detected.

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

### 3. Copy templates (idempotent, stack-aware)

Source templates are `${CLAUDE_PLUGIN_ROOT}/config/defaults/<file>`. Write to
`.intense/<file>`. **Never overwrite an existing `.intense/<file>`** without explicit
confirmation — a surprising clobber of committed team config is the failure mode to avoid
(least astonishment / no data loss). If a target exists, report it and ask whether to
overwrite, diff, or skip; default to **skip**.

- **`ways-of-working.yaml`** — stack-agnostic: copy verbatim.
  ```bash
  mkdir -p .intense
  SRC="${CLAUDE_PLUGIN_ROOT}/config/defaults/ways-of-working.yaml"; DST=".intense/ways-of-working.yaml"
  if [ -e "$DST" ]; then echo "EXISTS: $DST"; else cp "$SRC" "$DST" && echo "CREATED: $DST"; fi
  ```

- **`thresholds.yaml`** — **scaffold only the detected stack's namespace**, so the team
  tunes their stack, not a multi-stack file. The shipped default carries every stack's
  namespace (`rails.*`, `python.*`, …) for merge purposes; `.intense/thresholds.yaml` only
  needs the one the repo uses (config-resolution deep-merges a partial file over defaults).
  Emit the file header comment + the `<stack>:` block for the detected stack (`STACK`):
  ```bash
  SRC="${CLAUDE_PLUGIN_ROOT}/config/defaults/thresholds.yaml"; DST=".intense/thresholds.yaml"; STACK="python"  # detected
  if [ -e "$DST" ]; then echo "EXISTS: $DST"; else
    awk -v s="$STACK" '
      /^[a-z]/ && $0 !~ "^"s":" {inblk=0}        # any other top-level key ends the block
      /^#/ && !seenkey {print}                    # keep the leading header comments
      $0 ~ "^"s":" {inblk=1; seenkey=1}
      inblk {print}
    ' "$SRC" > "$DST" && echo "CREATED: $DST ($STACK namespace only)"
  fi
  ```
  For an **Arch pack ⬜** / unknown stack, skip `thresholds.yaml` and tell the user no
  architecture pack exists for the stack yet.

- **`patterns.yaml`** — copy the default policy, but it must reference **the detected
  stack's** catalog ids (`patterns/<stack>.yaml`), not another stack's. If the detected
  stack's catalog differs from the default file's seeded ids, replace the `allowed:` seed
  with that stack's pattern ids (read them from
  `${CLAUDE_PLUGIN_ROOT}/resources/patterns/<stack>.yaml`) and leave `blocked:`/`approved:`
  empty for the team to fill. Note the stack in the file's top comment.

The copied/emitted files keep their explanatory comments so the team can edit in place.

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
