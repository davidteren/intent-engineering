# Scoring Rubric (audit & plan modes)

In `audit` and `plan` contexts each lens returns `scores` (0-10 per dimension it owns),
alongside findings. The orchestrator assembles them into a posture table. Review mode
does not score.

Rate each dimension and state the gap: **"[Dimension]: N/10 — it's an N because
[specific gap]. A 10 would have [what's needed]."** Only produce findings for
dimensions at **7/10 or below**. Skip dimensions that don't apply.

**`scores` JSON keys (canonical — use these exact snake_case strings).** The prose
dimension names below are for the report; the `scores` object must key by these ids so
the orchestrator can assemble the posture table reliably:

| Lens | `scores` keys |
|------|---------------|
| predictability | `name_behavior_fidelity`, `return_contract_consistency`, `failure_transparency`, `representation_fidelity` |
| convention | `framework_idiom`, `repo_consistency`, `configuration_restraint` |
| simplicity | `essential_vs_accidental_complexity`, `abstraction_earns_its_keep`, `dependency_restraint` |
| experience | `information_architecture`, `interaction_state_coverage`, `user_flow_completeness`, `accessibility`, `look_and_feel_consistency` |
| architecture | `responsibility_placement`, `pattern_health`, `pattern_legibility`, `coupling_restraint` |

## Predictability lens dimensions
- **Name/behavior fidelity** — do names (functions, flags, endpoints, controls) match
  what they do? 10 = no name promises something its behavior breaks.
- **Return/contract consistency** — consistent return types and shapes across branches
  and sibling functions. 10 = a caller is never surprised by the shape.
- **Failure transparency** — failures are explicit, never silent. 10 = no swallowed
  errors, no fallback values masking failure.
- **Representation fidelity (WYSIWYG)** — what's shown matches the real result/state.
  10 = preview == output, dry-run == run, UI == server truth.

## Convention lens dimensions
- **Framework idiom** — follows the stack's conventions. 10 = an experienced
  practitioner would write it this way.
- **Repo consistency** — matches existing patterns and repo `CLAUDE.md`/`AGENTS.md`.
  10 = the new code is indistinguishable in style/structure from its neighbors.
- **Configuration restraint** — convention used where available; no needless knobs.
  10 = nothing configured that convention already settles.

## Simplicity lens dimensions
- **Essential vs accidental complexity** — complexity is inherent to the problem, not
  added by the solution. 10 = nothing simpler would work.
- **Abstraction earns its keep** — every layer/indirection/generality has a present
  need (not speculative). 10 = no abstraction with a single use or a hypothetical
  future justification.
- **Dependency restraint** — dependencies justified by real need. 10 = no dep added
  for what a few lines would do.

## Experience lens dimensions
- **Information architecture** — clear hierarchy, navigation model, grouping rationale.
  10 = clear what the user sees first/second/third and how to move.
- **Interaction-state coverage** — every interactive element specifies loading, empty,
  error, success, disabled, focus. 10 = no unspecified state.
- **User-flow completeness** — entry points, happy path, 2-3 edge cases, exits.
  10 = the flow is fully traceable.
- **Accessibility** — keyboard, screen-reader semantics, contrast, target size, scaling.
  10 = POUR met with no obvious gaps.
- **Look-and-feel consistency** — visual + behavioral consistency with the design
  system. 10 = no one-off styles or divergent interaction patterns.

## Architecture lens dimensions (framework-specific; code/audit only)
- **Responsibility placement** — logic lives in the right layer; no fat models/
  controllers, no God objects. 10 = each class has one clear job within thresholds.
- **Pattern health** — recognized design patterns are used well (per the catalog's
  good-use rubric); no misused service objects, no anemic abstractions. 10 = every
  pattern instance matches its rubric.
- **Pattern legibility** — structural units are identifiable patterns (or intentionally
  plain); few unidentified patterns; the team's allow/block policy is honored. 10 = no
  unidentified patterns and no blocked-pattern use.
- **Coupling restraint** — collaborators per class are bounded; no Law-of-Demeter train
  wrecks; callbacks are few and side-effect-light. 10 = low fan-out, no chains.

## Posture table (orchestrator output)

```
| Lens | Dimension | Score | Gap |
|------|-----------|-------|-----|
| Predictability | Failure transparency | 4/10 | 6 swallowed errors in services/ |
```

Overall posture = lowest-scoring dimensions surfaced first. Do not average into a
single vanity number; the gaps are the product.
