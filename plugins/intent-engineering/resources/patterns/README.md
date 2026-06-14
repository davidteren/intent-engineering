# Pattern Catalogs

Stack-scoped catalogs of design patterns, expressed as data, that the
architecture-reviewer lens uses to **recognize** pattern instances in a
codebase, **classify** them, and **judge** whether each instance is used well.
Each file is one stack: `rails.yaml` here; add `<stack>.yaml` (same schema) for
others.

The catalog is descriptive, not prescriptive. It does not decide *which*
patterns a team is allowed to use — that policy lives in
`.intense/patterns.yaml` (see below). The catalog only supplies the knowledge
needed to identify a pattern and assess its use.

## Entry schema

Top-level keys: `version` (integer), `stack` (string), `patterns` (list).
Each entry in `patterns`:

| Field | Required | Meaning |
|---|---|---|
| `id` | yes | snake_case stable key. The contract with `.intense/patterns.yaml` allow / block / approved lists. Never rename casually. |
| `name` | yes | Human-readable display name used in findings. |
| `intent` | yes | One sentence: the pattern's purpose. Note here when it is easily confused with another pattern and how to tell them apart. |
| `recognition` | yes | Heuristics the lens matches against. **Any-of**: any single signal can match; more matching signals raise confidence (gem/include strong, path/suffix weak). |
| `recognition.gems` | no | Gem(s) whose presence signals the pattern. Omit if none. |
| `recognition.includes` | no | Modules included or base classes subclassed. |
| `recognition.paths` | no | Typical directory globs where instances live. |
| `recognition.name_suffix` | no | Filename / class-name suffixes (e.g. `Service`, `Policy`). Omit (`[]`) if none. |
| `recognition.methods` | no | Characteristic public methods. |
| `good_use` | yes | Rubric of what GOOD use looks like. The lens checks instances against these. |
| `misuse` | yes | Detectable misuse signals; each maps to a potential finding. |

## How the lens uses a catalog

1. **Recognize** — for each structural unit (class/module) in a
   pattern-bearing location, match against every entry's `recognition` block.
   Signals are **any-of**: a unit matches an entry if *any* signal hits, not all.
   Strength order: a `gems`/`includes` match is strong; `paths`/`name_suffix`
   alone is weak. Multiple matching signals increase confidence; the best-scoring
   entry wins. When a unit matches by `paths`/`name_suffix` but its public methods
   contradict the entry's `methods`, classify it AND flag the mismatch (right
   folder, wrong pattern).
2. **Classify** — tag the unit with the winning entry's `id` and `name`.
3. **Check** — evaluate the instance against that entry's `good_use` rubric and
   `misuse` signals. A matched `misuse` signal becomes a finding; `good_use`
   gaps inform severity.
4. **Unknown** — a unit in a pattern-bearing location that matches **no** entry
   is reported per `unknown_pattern` in `.intense/patterns.yaml` (advisory by
   default), so a human can classify it or extend the catalog.

## Relationship to `.intense/patterns.yaml`

The project policy file references catalog entries **by `id`**:

- `allowed: [interactor, form_object, ...]` — patterns the team uses on
  purpose. Recognized instances are still checked for good use; they are never
  flagged merely for existing.
- `blocked: [service_object]` — patterns disallowed for new use. A blocked `id`
  appearing in changed code raises a high-priority finding; pre-existing uses
  are advisory.
- `approved: [{ path: ..., reason: ... }]` — grandfathered instances/paths
  whose findings are suppressed and noted in Coverage.

Because these lists key off `id`, the ids in a catalog are an API: keep them
stable and snake_case, and make sure any id used in policy exists in the
matching stack catalog. The global defaults live in
`config/defaults/patterns.yaml`.

## Adding a new stack catalog

1. Create `resources/patterns/<stack>.yaml` with `version: 1`,
   `stack: <stack>`, and a `patterns:` list using the schema above.
2. Make `recognition` signatures concrete and as non-overlapping as possible;
   where two patterns are easily confused, say so in `intent` and rely on a
   distinguishing signal (a gem, a base class, a directory) to separate them.
3. Keep entries tight — `good_use` and `misuse` are rubrics, not essays.
4. Validate: the file must be valid YAML with two-space indentation and no
   tabs.

## Sources

- Interactor gem — recognition signatures (`include Interactor`, `call`,
  `context`, organizers): https://github.com/collectiveidea/interactor
- Pundit — `ApplicationPolicy`, `app/policies`, `*_policy.rb`, action
  predicates, inner `Scope`: https://github.com/varvet/pundit
- Active Job Basics (Rails Guides) — `ApplicationJob`, `perform`,
  `perform_later`, serializable arguments:
  https://guides.rubyonrails.org/active_job_basics.html
