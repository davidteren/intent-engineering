# Lens Catalog

The expectation-fit lenses. Each is a reviewer sub-agent that reads the relevant
`${CLAUDE_PLUGIN_ROOT}/resources/` docs and returns findings per the findings schema.
Every skill (`fit-review`, `fit-audit`, `fit-validate-plan`, `fit-plan-assist`) selects from
this same catalog and adapts each lens to its context. Four are universal
(predictability, convention, simplicity, experience); the fifth (architecture) is
framework-specific and code/audit-only.

| Lens (agent) | Principles | Resource docs it reads | Hunts for |
|--------------|-----------|------------------------|-----------|
| `fit-predictability-reviewer` | least-astonishment, DWIM, WYSIWYG | `principles/least-astonishment.md`, `principles/dwim.md`, `principles/wysiwyg.md`, `agnostic/naming.md`, `agnostic/error-handling.md`, `agnostic/api-design.md`, `agnostic/defaults-and-configuration.md` ("Surprising defaults" section only) | Name/behavior mismatch, hidden side effects, surprising return types, inconsistent branch returns, silent failures, controls that don't do what their label implies, preview/state divergence |
| `fit-convention-reviewer` | convention-over-configuration, framework idiom | `principles/convention-over-configuration.md`, the matching `frameworks/<stack>.md`, `agnostic/naming.md`, `agnostic/defaults-and-configuration.md` | Reinvented conventions, config where convention exists, one-off patterns fighting the repo/framework, non-idiomatic structure/naming. **Reads repo `CLAUDE.md`/`AGENTS.md` FIRST — local conventions override community defaults.** |
| `fit-simplicity-reviewer` | Occam, KISS, YAGNI | `principles/occams-razor.md`, `principles/software-philosophies.md`, `agnostic/defaults-and-configuration.md` | Needless abstraction, premature generality, speculative config, layers that don't earn their keep, simpler equivalent exists. Guards the flip side: don't oversimplify away real requirements. |
| `fit-experience-reviewer` | HIG, look-and-feel, UX | `principles/human-interface-guidelines.md`, `principles/look-and-feel.md`, `principles/ux-design.md`, `agnostic/accessibility.md`, `agnostic/information-architecture.md`, `agnostic/ux-interaction-smells.md` | Missing interaction states, non-semantic/unlabelled controls, form/destructive feedback gaps, inconsistent look/feel, broken keyboard/focus/back-button, accessibility gaps, weak IA, AI-slop design; CLI and developer output (error and recovery messages, exit codes, stdout/stderr; see the "CLI and developer output" section of `ux-interaction-smells.md`) |
| `fit-architecture-reviewer` | structural quality (Occam/SRP applied), design patterns | `frameworks/<stack>-architecture.md`, `patterns/<stack>.yaml`, resolved `.expectation-fit/` config | Fat models/routers, God objects/modules, fat controllers, misused service objects, callback hell, business logic in schemas, layer leaks, Law of Demeter; classifies pattern instances, raises unidentified patterns, enforces allow/block/approved policy. **Framework-specific (Rails + Python + Laravel + Express + Phoenix + React today), code/audit only.** Heuristic-first; optional reek/flog (Ruby), ruff/radon (Python), phpstan/phpmd (Laravel), or eslint/madge (Express/React), credo/boundary (Phoenix) enrichment. |

## Lens selection (per context)

**`fit-predictability-reviewer` and `fit-simplicity-reviewer` are always-on** — every
context runs them. They apply to any code or plan regardless of stack or surface.

**`fit-convention-reviewer`** runs when the diff/codebase/plan involves a stack with a
`frameworks/*.md` doc, OR the repo has `CLAUDE.md`/`AGENTS.md` conventions, OR similar
code already exists to be consistent with (almost always — default on for code).

**`fit-experience-reviewer`** runs when there is a user-facing surface: UI components,
frontend files, user flows, screens/views, CLI UX, or a plan that describes any of
these. In review/audit, treat a surface as present whenever the diff or scope touches a
template, view, partial, component, or client controller **for the detected stack** —
e.g. `app/views/**` + `*.erb` and `app/components/**` (Rails), `templates/**/*.html` /
Jinja (Python: Django/Flask), `views/**/*.ejs` / `*.pug` / `*.hbs` (Express),
`resources/views/**/*.blade.php` (Laravel), `lib/*_web/**` with `*.heex` / function
components (Phoenix), `*.jsx` / `*.tsx` / `*.vue` and component dirs (React / JS / Vue),
`app/javascript/controllers/**` (Stimulus), plus CLI help, output, error and recovery
messages, exit codes and the stdout/stderr split, and changed steps in a README, guide or
upgrade page — **even in an
otherwise backend-heavy change**; a mixed backend+frontend diff must not skip the lens.
The list is illustrative, not exhaustive: any file that renders or drives UI for the
stack counts. A library or gem counts when it ships any of these. Skip only when nothing
in scope changes output, messages or steps that a person or a calling script relies on.
Drift between a doc's claims and the code stays with predictability. Experience judges
whether a person can follow the steps.

**`fit-architecture-reviewer`** runs when a supported framework is detected. The supported
stacks, their detection signals, and the rule-pack files each loads are listed in
`${CLAUDE_PLUGIN_ROOT}/references/stack-catalog.md` (the registry) — a stack is
architecture-supported only when its **Arch pack** is ✅ there (Rails, Python, Laravel,
Express, Phoenix, and React today; each has a `frameworks/<stack>-architecture.md` +
`resources/patterns/<stack>.yaml` + `<stack>.*` thresholds). Code/audit contexts only — it inspects structure, not prose. Skip
when no architecture-supported stack is present.

**Config overrides selection.** The `.expectation-fit/ways-of-working.yaml` `lenses:` block
(merged over the plugin default per `config-resolution.md`) is authoritative: `on`
forces a lens on, `off` forces it off (turn an agent off entirely), `auto` applies the
judgment rules above (experience = user-facing surface present, including a
template/view/component/client-controller path for the stack in scope; architecture = supported
framework present; convention = stack/standards/siblings present). The `tools.architecture`
preference (`enrich`/`prefer`/`report`/`off`) further controls whether the architecture lens
defers to an installed external static-analysis tool instead of duplicating it. Resolve config
first, then select.

This is agent judgment, not keyword matching. Before dispatching, announce every catalog
lens with its selection and a one-line reason, for example
`experience: not_selected, no user-facing paths in scope`.

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
