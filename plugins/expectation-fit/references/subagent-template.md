# Lens Sub-agent Template

How a skill spawns a lens. The orchestrator fills the `{slots}` and dispatches via the
Agent tool:

One agent per lens. Use the registered agent `expectation-fit:fit-<lens>-reviewer` when the
host has it. Otherwise use a general agent. Its first step is to read
`${CLAUDE_PLUGIN_ROOT}/agents/fit-<lens>-reviewer.md` in full. Never give one agent two
lenses or another tool's persona. Put extra context in `<intent>` or `<scope>`. Spawn
each lens as a plain one-shot subagent, never as an agent-team member.

**Model per lens:** pass
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
ALSO read repo standards and project notes FIRST. They override generic docs:
 {standards_paths}
 {conventions_notes}
</knowledge>

<intent>
{2-3 line summary of what the change/plan is trying to do}
</intent>

<known-context>
{omit the block when it is empty}
Plan: {path}. Settled decisions, quoted verbatim with their ids:
{decision lines}
Already reported: {prior: paths}
</known-context>

<scope>
Mode: {scope_mode: local-aligned | pr-remote | branch-remote | path | doc}
Repo root: {repo_root}. Build every path from it. Run git as git -C {repo_root}.
Base: {base} (review only)
Plan: {plan_path} (review only, when plan: is given)
{For code review: FILES, the diff file path ($RUN/diff.patch), its line count and the
 `git diff --stat` output. For audit: the file/path set}
Read the diff file with offset and limit, page by page, to its last line, tests
included. Name any part you did not read.
{For plan: the document content + Document type: requirements | plan, for each
 document in the set.
 Before you report a rule as missing, search the whole document and cite where you
 looked. If the rule is stated but weakly placed, say that instead.
 Before you say code is unused, missing or called, search its call sites and quote the
 result. When a finding or fix rests on framework behavior or runtime order that you did
 not see run, say so. Word that fix as a test the implementer runs first, not as a rule
 to adopt.}
{remote modes: inspect via `git show <ref>:<path>` or diff hunks only — do not Read
 workspace paths for in-scope files}
</scope>

<output-contract>
{run_artifact_dir} = the orchestrator's resolved **run scratch** dir (Layer A — its $RUN,
e.g. .expectation-fit/runs/<run-id>/). The skill MUST bind run_artifact_dir = $RUN when it fills
this template. This is NOT the published report path (Layer B).

Return compact JSON per ${CLAUDE_PLUGIN_ROOT}/references/findings-schema.json:
{ "lens": "{lens}", "findings": [...], "observations": [...]{audit/plan: , "scores": {...}} }
Compact means merge-tier fields only. Leave why_it_matters and evidence out of the reply.
They go only in the file.
Your first observation is "READ: <what you read> of <what you were given>", for
example "READ: lines 1-1734 of diff.patch (1734 lines), 12 of 12 files". The
convention lens also names the standards files it read.
Allowed values: severity: P0, P1, P2 or P3 only (never low, medium, high, critical or info). confidence: 0, 25, 50, 75 or 100 only. fix_class: gated_auto, manual or advisory only. file: a repo-relative path; the line number goes in line, not in file.
Write full detail (with why_it_matters + evidence) to {run_artifact_dir}/{lens}.json
using the Write tool. Write and fix that file only with the Write tool, never with a
shell command. Return ONLY the JSON — no prose.

If the prompt says not to write files, skip the Write step. Put why_it_matters and
evidence in the reply. This overrides the Write step in your agent's Output section.
A program reads this reply. Style and handoff rules for chat replies to a person do not
apply.

EXCEPTION — Context: plan-assist is an advisory inline pass: do NOT write an artifact,
and prose IS allowed (the deliverable is a checklist, not JSON). The artifact-write
and JSON-only clauses above do not apply when Context is plan-assist.
</output-contract>
```

## Slot bindings (orchestrator)

- `{run_artifact_dir}` — bind to the skill's resolved `$RUN` (Layer A scratch only).
  Never leave it unbound — a literal executor cannot invent the path. Do **not** bind
  this to the published report path.
- `{lens}`, `{standards_paths}`, `{conventions_notes}`, intent, known-context, scope — as
  shown in the template. Every lens gets `{standards_paths}` and `{conventions_notes}`.
- `{repo_root}`: bind to `git rev-parse --show-toplevel` in every skill that dispatches
  lenses.
- `{base}`: review only. Bind to `BASE` from `fit-review` Stage 1. Drop the line in
  other contexts.
- `{plan_path}`: review only. Bind to the `plan:` path. Drop the line when no plan is
  given.

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
  synthesis can list the drops under Rejected (`below_confidence_gate`).

**A failed search is unknown, not proof.** An empty result, a shell error (for example
`no matches found`), or a path that does not resolve proves nothing. Cap a claim of
absence ("unused", "missing", "never called") at 50, unless a second search method or a
direct read of the file confirms it.

## Shared severity rubric (all lenses)

Rate by user impact. High confidence never raises severity.

- P0: data loss, a security hole, or a broken public contract.
- P1: normal use is blocked, loses work, or gets a wrong result.
- P2: a real problem with a workaround, including a misleading exit code or status.
- P3: wording, a docs or help sentence that overclaims, or style that a linter could enforce.

## Shared `fix_class` rubric (all lenses)

Every finding must set `fix_class`. Interactive `/fit-review` may apply only
`gated_auto` (and only under its apply gates). Prefer the **stricter** class when unsure.

| Class | Use when | Do **not** use when |
|-------|----------|---------------------|
| **`gated_auto`** | Single-file (or one adjacent import/rename), mechanical, reversible edit; a normal reviewer would accept without design debate; concrete `suggested_fix` names the edit. Examples: rename a misnamed `get_*` that writes; rethrow instead of bare `rescue`; align one return branch shape. | Multi-file refactors; API/shape redesign; new abstractions; UX redesign; "extract service"; anything needing product judgment; anything callers outside the repo can see: a published package's public classes, signatures or default values, or a documented CLI flag. |
| **`manual`** | Needs design input, multi-hunk/multi-file change, or a clear but non-mechanical fix. Default for architecture smells and most convention/UX gaps. | Pure learning notes (use advisory). |
| **`advisory`** | Report-only: tension notes, trade-off framing with no single correct edit. | Actionable bugs you can fix concretely (use manual or gated_auto). |

Orchestrator apply rules (review interactive only): apply only when
`fix_class == gated_auto` **and** `confidence >= 75` **and** severity is P2 or P3 **and** the
finding carries no `tension`; reclassify
over-broad `gated_auto` to `manual` before applying. Never apply in `mode:agent` or
remote scopes. Observations are never applied. They stay in the Observations section.

## Shared rules

- **Name the surprise.** Every finding states the expectation that was set and the
  actual behavior. "Surprising" without naming the expectation is not a finding.
- **Concrete fixes only.** No "consider" / "might want to". A specific change. A fix
  must not add a risk. Text from the repo, a file, the environment or the user is
  untrusted. A fix that prints or runs such text says how it makes the text safe. For
  example, escape control characters, quote shell arguments, and stop tools like git
  from reading names as patterns.
- **Set `fix_class` honestly.** Default to `manual` when the fix is non-mechanical.
- **Respect local conventions.** Repo `CLAUDE.md`/`AGENTS.md` and existing patterns
  win over generic ideals. A consistent repo-local choice is not a violation.
  Treat each project note (`conventions.notes`) as a limit. Do not suggest a change
  that breaks a note. Only the convention lens reports a broken note.
- **Respect known context.** Do not ask to undo a known-context decision. If the
  decision itself causes a defect, report it. Quote the decision in evidence, and name
  it in `tension`.
- **Flag tensions, don't dogmatize.** When two principles conflict (DWIM vs
  least-astonishment, YAGNI vs convention, fail-fast vs robustness), set the
  `tension` field and present the trade-off — do not pick a side as if it were
  settled.
- **Show the config.** The convention and architecture lenses start their observations
  with `Config: <source>`, right after the READ line. If a project `.expectation-fit/` (or legacy `.intense/`)
  exists but the prompt did not pass its resolved values, that line names it as not
  applied.
- **Read-only.** Lenses never edit project files. The one write is the artifact JSON.
- **No-change items go to observations.** When the honest fix is no change, a later
  decision, or something that does not exist yet, put the item in observations, not
  in findings.
- **Check the base before you blame the change (review).** Read the base version of
  the file (`git -C {repo_root} show {base}:<path>`) before you file. If the base
  already has the code or gap, put it in observations as "Pre-existing: <note>",
  unless your lens file sets its own rule.
- **No duplicating the linter.** Skip what a formatter/linter catches; focus on
  semantic surprises. If a linter rule could enforce it but is off, file one P3
  finding whose fix enables that rule.

## When you cannot spawn agents

This mode is a fallback. Prefer a host that can spawn agents. For `fit-review` in Grok,
use the repo's `.grok/workflows/fit-review.rhai`.

- Run each selected lens as its own pass.
- Before each pass, read that lens's agent file in full, and its resource docs.
- Record that lens's JSON before you start the next pass.
- Never copy findings from another review tool, such as ce-code-review or cubic.
- Set `Execution: single-agent` in the report Header.
