# Lens Catalog

The intent-engineering lenses. Each is a reviewer sub-agent that reads the relevant
`${CLAUDE_PLUGIN_ROOT}/resources/` docs and returns findings per the findings schema.
Every skill (`ie-review`, `ie-audit`, `ie-validate-plan`, `ie-plan-assist`) selects from
this same catalog and adapts each lens to its context. Four are universal
(predictability, convention, simplicity, experience); the fifth (architecture) is
framework-specific and code/audit-only.

| Lens (agent) | Principles | Resource docs it reads | Hunts for |
|--------------|-----------|------------------------|-----------|
| `ie-predictability-reviewer` | least-astonishment, DWIM, WYSIWYG | `principles/least-astonishment.md`, `dwim.md`, `wysiwyg.md`, `agnostic/naming.md`, `error-handling.md`, `api-design.md` | Name/behavior mismatch, hidden side effects, surprising return types, inconsistent branch returns, silent failures, controls that don't do what their label implies, preview/state divergence |
| `ie-convention-reviewer` | convention-over-configuration, framework idiom | `principles/convention-over-configuration.md`, the matching `frameworks/<stack>.md`, `agnostic/naming.md`, `defaults-and-configuration.md` | Reinvented conventions, config where convention exists, one-off patterns fighting the repo/framework, non-idiomatic structure/naming. **Reads repo `CLAUDE.md`/`AGENTS.md` FIRST — local conventions override community defaults.** |
| `ie-simplicity-reviewer` | Occam, KISS, YAGNI | `principles/occams-razor.md`, `principles/software-philosophies.md`, `agnostic/defaults-and-configuration.md` | Needless abstraction, premature generality, speculative config, layers that don't earn their keep, simpler equivalent exists. Guards the flip side: don't oversimplify away real requirements. |
| `ie-experience-reviewer` | HIG, look-and-feel, UX | `principles/human-interface-guidelines.md`, `look-and-feel.md`, `ux-design.md`, `agnostic/accessibility.md`, `information-architecture.md` | Missing interaction states, inconsistent look/feel, broken keyboard/focus/back-button, accessibility gaps, weak information architecture, AI-slop design |
| `ie-architecture-reviewer` | structural quality (Occam/SRP applied), design patterns | `frameworks/<stack>-architecture.md`, `patterns/<stack>.yaml`, resolved `.intense/` config | Fat models/routers, God objects/modules, fat controllers, misused service objects, callback hell, business logic in schemas, layer leaks, Law of Demeter; classifies pattern instances, raises unidentified patterns, enforces allow/block/approved policy. **Framework-specific (Rails + Python + Laravel + Express + Phoenix + React today), code/audit only.** Heuristic-first; optional reek/flog/brakeman (Ruby), ruff/radon (Python), phpstan/phpmd (Laravel), or eslint/madge (Express/React), credo/boundary (Phoenix) enrichment. |

## Lens selection (per context)

**`ie-predictability-reviewer` and `ie-simplicity-reviewer` are always-on** — every
context runs them. They apply to any code or plan regardless of stack or surface.

**`ie-convention-reviewer`** runs when the diff/codebase/plan involves a stack with a
`frameworks/*.md` doc, OR the repo has `CLAUDE.md`/`AGENTS.md` conventions, OR similar
code already exists to be consistent with (almost always — default on for code).

**`ie-experience-reviewer`** runs when there is a user-facing surface: UI components,
frontend files, user flows, screens/views, CLI UX, or a plan that describes any of
these. Skip for pure backend/library/infra changes with no user-facing surface.

**`ie-architecture-reviewer`** runs when a supported framework is detected. The supported
stacks, their detection signals, and the rule-pack files each loads are listed in
`${CLAUDE_PLUGIN_ROOT}/references/stack-catalog.md` (the registry) — a stack is
architecture-supported only when its **Arch pack** is ✅ there (Rails, Python, Laravel,
Express, Phoenix, and React today; each has a `frameworks/<stack>-architecture.md` +
`resources/patterns/<stack>.yaml` + `<stack>.*` thresholds). Code/audit contexts only — it inspects structure, not prose. Skip
when no architecture-supported stack is present.

**Config overrides selection.** The `.intense/ways-of-working.yaml` `lenses:` block
(merged over the plugin default per `config-resolution.md`) is authoritative: `on`
forces a lens on, `off` forces it off, `auto` applies the judgment rules above
(experience = user-facing surface present; architecture = supported framework present;
convention = stack/standards/siblings present). Resolve config first, then select.

This is agent judgment, not keyword matching. Announce the selected lenses (with the
one-line reason for each conditional lens) before dispatching.

## Context adaptation

Each lens adapts to the context passed in its prompt (`Context:` slot):

- **`review`** — concrete code diff. Findings cite `file:line`. Confidence anchors as
  in the schema. No `scores`.
- **`audit`** — broad codebase/path/feature. Findings still cite `file:line`; ALSO
  return `scores` (0-10 per dimension) for the posture report. Sampling-aware: note
  what was and wasn't covered.
- **`plan`** — a plan/spec/requirements doc. Findings cite the doc section/line and
  describe the gap a planner/implementer would hit. Return `scores` (dimensional
  rating). Predictability/convention/simplicity assess the *proposed design*;
  experience assesses described UX completeness (states, flows, IA, a11y commitments).
- **`plan-assist`** — advisory only, and **prose, not schema JSON**. Emit a checklist
  of considerations for the work being planned; write no artifact and return no
  findings JSON (the deliverable is the checklist itself). This is the
  `Context: plan-assist` exception in the subagent template — the findings schema /
  `fix_class` vocabulary does not apply here.
