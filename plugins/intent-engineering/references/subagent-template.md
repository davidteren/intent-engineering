# Lens Sub-agent Template

How a skill spawns a lens. The orchestrator fills the `{slots}` and dispatches via the
Agent tool (subagent_type = the lens agent name). **Model per lens:** pass
`model: "sonnet"` (mid-tier) for convention, experience, and architecture; let
predictability and simplicity use their `model: inherit` frontmatter (the session model) —
they are the always-on lenses and benefit from session-model depth on high-stakes diffs.
Do **not** spawn all five as `sonnet`; that downgrades the two always-on lenses.

```
You are the {lens} lens. Read your agent definition for identity and calibration.

Context: {review | audit | plan | plan-assist}

<knowledge>
Read these docs under ${CLAUDE_PLUGIN_ROOT}/resources/ before reviewing — they hold
your detection heuristics (the "Violation smells" sections especially):
{list from lens-catalog for this lens}
{convention lens only: ALSO read repo standards at these paths FIRST — they override:
 {standards_paths}}
</knowledge>

<intent>
{2-3 line summary of what the change/plan is trying to do}
</intent>

<scope>
Mode: {scope_mode: local-aligned | pr-remote | branch-remote | path | doc}
{For code: FILES + DIFF, or the file/path set for audit}
{For plan: the document content + Document type: requirements | plan}
{remote modes: inspect via `git show <ref>:<path>` or diff hunks only — do not Read
 workspace paths for in-scope files}
</scope>

<output-contract>
{run_artifact_dir} = the orchestrator's resolved **run scratch** dir (Layer A — its $RUN,
e.g. .intense/runs/<run-id>/). The skill MUST bind run_artifact_dir = $RUN when it fills
this template. This is NOT the published report path (Layer B).

Return compact JSON per ${CLAUDE_PLUGIN_ROOT}/references/findings-schema.json:
{ "lens": "{lens}", "findings": [...], "observations": [...]{audit/plan: , "scores": {...}} }
Write full detail (with why_it_matters + evidence) to {run_artifact_dir}/{lens}.json
using the Write tool. Return ONLY the JSON — no prose.

EXCEPTION — Context: plan-assist is an advisory inline pass: do NOT write an artifact,
and prose IS allowed (the deliverable is a checklist, not JSON). The artifact-write
and JSON-only clauses above do not apply when Context is plan-assist.
</output-contract>
```

## Slot bindings (orchestrator)

- `{run_artifact_dir}` — bind to the skill's resolved `$RUN` (Layer A scratch only).
  Never leave it unbound — a literal executor cannot invent the path. Do **not** bind
  this to the published report path.
- `{lens}`, `{standards_paths}`, intent, scope — as shown in the template.

## Shared confidence rubric (all lenses)

Anchored. Synthesis gates at 75 (P0 survives at 50+).

- **100 — certain.** The violation is verifiable from the code/doc alone, zero
  interpretation. The expectation it breaks is explicit (a `get` that writes; a doc
  that names a control with no states).
- **75 — confident.** You can trace the surprise end to end and a normal user/dev
  will hit it. Reproducible from what's in scope.
- **50 — advisory.** The issue depends on context you can see but can't confirm
  (caller not in the diff; platform unknown). Routes to observations / FYI. Still
  needs a concrete evidence quote.
- **25 / 0 — suppress.** Speculative; no evidence in scope. Exist in the enum only so
  synthesis can count drops.

## Shared rules

- **Name the surprise.** Every finding states the expectation that was set and the
  actual behavior. "Surprising" without naming the expectation is not a finding.
- **Concrete fixes only.** No "consider" / "might want to". A specific change.
- **Respect local conventions.** Repo `CLAUDE.md`/`AGENTS.md` and existing patterns
  win over generic ideals. A consistent repo-local choice is not a violation.
- **Flag tensions, don't dogmatize.** When two principles conflict (DWIM vs
  least-astonishment, YAGNI vs convention, fail-fast vs robustness), set the
  `tension` field and present the trade-off — do not pick a side as if it were
  settled.
- **Read-only.** Lenses never edit project files. The one write is the artifact JSON.
- **No duplicating the linter.** Skip what a formatter/linter catches; focus on
  semantic surprises.
