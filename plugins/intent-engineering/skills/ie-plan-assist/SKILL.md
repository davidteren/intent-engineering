---
name: ie-plan-assist
description: "Inject intent-engineering principles into the planning phase — surface the least-astonishment, convention, simplicity, and UX considerations relevant to the work being planned, as a tailored advisory checklist. Lightweight and non-blocking; use while drafting a plan or thinking through an approach, before a full plan doc exists. For validating a finished plan, use ie-validate-plan instead."
argument-hint: "[a short description of what's being planned, or blank to use the current conversation/plan context]"
---

# Intent Engineering — Planning Assist

A fast, advisory pass that brings the principles to the table *while* you plan, so the
design starts intuitive instead of being corrected later. It does not fan out a heavy
review or score anything — it emits a tailored checklist of the considerations that
matter for *this* work, drawn from the principle docs.

## When to use

- Drafting an approach or a plan, before a finished plan doc exists.
- Deciding between designs and wanting the principle trade-offs surfaced.
- As a planning-phase companion (a planning workflow can call this to enrich a draft).

For a finished plan/spec doc, use `ie-validate-plan`. For code, use `ie-review`.

## How it works

This skill runs **inline** (no sub-agents by default — it's meant to be quick and
conversational). Steps:

1. **Establish the subject.** Use the argument, or the current plan draft /
   conversation, to state in one line what's being planned and identify the
   surface(s): backend logic, public API/interface, framework/stack, user-facing UI,
   data/config.

2. **Select the relevant principles.** Read only the docs that apply (from
   `${CLAUDE_PLUGIN_ROOT}/resources/` — see `references/principle-index.md`):
   - Always: `principles/least-astonishment.md`, `principles/occams-razor.md`.
   - API/interface or naming decisions: `agnostic/api-design.md`, `agnostic/naming.md`,
     `agnostic/error-handling.md`, `principles/dwim.md`.
   - Framework/stack chosen: the matching `frameworks/<stack>.md` +
     `principles/convention-over-configuration.md` + `agnostic/defaults-and-configuration.md`.
   - User-facing surface: `principles/human-interface-guidelines.md`,
     `principles/ux-design.md`, `principles/look-and-feel.md`,
     `agnostic/accessibility.md`, `agnostic/information-architecture.md`.

3. **Emit a tailored checklist**, grouped by lens, of the concrete decisions to get
   right up front. Each item is a question or guard specific to the subject — not a
   generic principle restatement. Examples:
   - *Predictability:* "Name the new endpoint after what it does — will `GET
     /accounts/:id/summary` ever mutate? If caching, make the write explicit."
   - *Convention:* "This is Rails — model the cancellation as a RESTful sub-resource
     (`DELETE`/nested resource), not a custom `cancel` action, unless the repo already
     does custom actions."
   - *Simplicity:* "You're adding a strategy interface for one payment provider —
     defer it until the second provider is real (YAGNI)."
   - *Experience:* "List the states for the new filter: loading, empty, error, no-match
     — and the keyboard path. Decide them now, not in code review."

4. **Surface tensions, don't resolve them.** Where principles conflict for this work
   (DWIM forgiving-input vs least-astonishment; convention's structure vs YAGNI), name
   the trade-off and let the planner choose. Read
   `${CLAUDE_PLUGIN_ROOT}/resources/principles/software-philosophies.md` "Tensions".

5. **Optional deepening.** If the user asks for more rigor on a specific surface, offer
   to spawn the matching lens (`ie-*-reviewer`) in `Context: plan-assist` against the
   draft for a focused advisory pass. Only on request — the default is the inline
   checklist. That spawn uses the **plan-assist exception** in the subagent template:
   the lens writes **no artifact** and returns an advisory note (prose allowed), not
   JSON — so this skill still writes nothing to disk and the "no sub-agents by default"
   promise holds (a sub-agent runs only on explicit request, and even then produces no
   file).

## Output

A short markdown checklist grouped by lens (Predictability / Convention / Simplicity /
Experience — include only the lenses that apply), plus a Tensions note if any. Every
item is specific to the subject and phrased as a decision to make now. Advisory only —
nothing blocks, nothing is written to disk unless the user asks to save it.

Keep it tight: the value is a focused list of the right questions, not an essay.

---

## Reference files (read at runtime)

Depends on `${CLAUDE_PLUGIN_ROOT}` resolving (standard in Claude Code):

- `${CLAUDE_PLUGIN_ROOT}/references/principle-index.md` — principle → doc → lens map
- `${CLAUDE_PLUGIN_ROOT}/references/lens-catalog.md`

Principle docs to read selectively live under `${CLAUDE_PLUGIN_ROOT}/resources/`.
