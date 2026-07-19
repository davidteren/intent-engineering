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
| Ways of working | `.intense/ways-of-working.yaml` | lens toggles, **external-tool preference**, severity overrides, local conventions, confidence gate, **artifact paths** (run scratch + published report) |
| Pattern policy | `.intense/patterns.yaml` | allowed / blocked / pre-approved design patterns, unknown-pattern handling |
| Thresholds | `.intense/thresholds.yaml` | architecture metric limits (fat model/controller, God object, service object, …) |
| All | all three | full config set |

Recommend **All** for a first run.

### 2b. Opt in/out of lenses + external tools (when scaffolding ways-of-working)

If `ways-of-working.yaml` is being scaffolded **and** the menu is interactive (AskUserQuestion
available), present short opt-in questions and write the answers into the file (Step 3),
so the team configures which modules run at init rather than editing YAML afterward:

1. **Which lenses run?** Default `predictability`, `convention`, `simplicity` on;
   `experience`, `architecture` auto. Let the user turn any **off** (e.g. a team that relies
   solely on its own pipeline might set `architecture: off`). Write to `lenses.*`.
2. **External-tool preference** (only meaningful if the architecture lens is on). "If your repo
   already runs a static-analysis tool (reek/rubocop, ruff, phpstan, eslint, credo…), how
   should the architecture lens treat it?" → `enrich` (default — heuristics + tool),
   `prefer` (run the tool, suppress overlapping heuristics — no duplication), `report`
   (tool findings only), `off` (ignore tools). Write to `tools.architecture`.
3. **Where do reports go?** Confirm or override defaults: run scratch → `.intense/runs/`
   (deleted after publish when `cleanup_runs: true`); published report →
   `docs/intent-engineering/<stamp>-<skill>[-scope].md`. Write overrides into `artifacts.*`.
   Always restate the defaults in the Step 5 summary even when the user accepts them.

Non-interactive / `$ARGUMENTS`-driven runs: skip the prompts and scaffold the documented
defaults verbatim (the file's comments explain every option for later editing).

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

### 4. Gitignore for run scratch (optional; re-offered until the path is ignored)

Resolve the **active** run-scratch path first (same rules as
`${CLAUDE_PLUGIN_ROOT}/references/config-resolution.md`):

- If project `.intense/ways-of-working.yaml` has `artifacts.run_dir` → use that.
- Else if it has top-level `report_dir:` and **no** `artifacts:` block (**legacy
  single-bucket**) → scratch is under `report_dir/<run-id>/`. Offer to ignore
  `report_dir/` only when that path is clearly ephemeral (e.g. still
  `wip/intent-engineering`); if `report_dir` looks like a docs/publish path, **skip**
  the gitignore offer and explain that legacy mode keeps scratch next to published
  reports without auto-cleanup.
- Else → default `.intense/runs/`.

After scaffolding ways-of-working (or on any init that mentions artifacts), if the
project `.gitignore` does **not** already ignore the resolved scratch root, **offer**
to append it (example for the default):

```
# Intent Engineering — ephemeral lens run scratch (published reports live under docs/)
.intense/runs/
```

This is **not** remembered across declines — if the line is still missing, the offer
reappears on the next `/ie-init`. That is intentional (least surprise: no hidden
"don't ask again" flag). Never force; never add `.intense/` itself (config YAML must
stay committable). Do not invent a `wip/` ignore for the plugin default — `wip/` is no
longer the plugin report home.

### 5. Report

List what was created vs skipped. Then tell the user:

- The files are **meant to be committed** (they're project config, not artifacts) — do
  NOT add `.intense/` to `.gitignore` (only `.intense/runs/` if they accepted Step 4).
- Published reports land under `docs/intent-engineering/` by default (committable if
  the team wants a history); run scratch is cleaned up after each successful publish.
- Edit config to taste; every `ie-*` run in this repo now merges it over the plugin
  defaults (project wins; lists replace unless `extends: true`).
- Suggest the natural next step: run `/ie-audit` to see the current posture under the
  new config.

This skill only writes under `.intense/` (and optionally one `.gitignore` append the
user accepted). It never commits or pushes.

---

## Reference files (read at runtime)

- `${CLAUDE_PLUGIN_ROOT}/references/config-resolution.md` — how the scaffolded files are
  merged and consumed
- `${CLAUDE_PLUGIN_ROOT}/config/defaults/` — the source templates
