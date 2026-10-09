# Grok workflows (optional runtime)

These files are a Grok runtime for expectation-fit. They are not part of the
Claude Code plugin package. The installable plugin stays under
`plugins/expectation-fit/`.

## fit-review

A config agent resolves `.expectation-fit` (or plugin defaults) and selects lenses.
Selected lenses run together using the shared subagent template slots. Then
one skeptic per finding. A finding is kept only with evidence and after the
confidence gate. Merge is read-only. Any report the merge step produces is stored
as run scratch (`<hash>-report.md`) and never discarded. If the merge output drops
a confirmed finding, the verdict flips to Not ready and the stored report gets an
authoritative override banner at the top. If the merge step returns no report at
all, the run reports Not ready with no scratch file. This workflow does not write
into the git tree. Product code is not edited.

From a Grok session in this repo:

```
/workflow fit-review {"target":"HEAD","base":"<merge-base commit SHA>"}
```

Get the SHA with `git merge-base origin/main HEAD`. The workflow reviews the
checked-out tree. Agents have no shell: they read the working tree with read_file
and grep.

Other repos use a copy at `~/.grok/workflows/fit-review.rhai`. Copy this file
there after each pull, or those runs keep the old behavior.

Useful args:

| Field | Role |
|---|---|
| `target` | Required. A ref, range, or path. Prompts carry it only as a JSON-encoded label (data, not instructions). A target that is not a path and contains a space pauses the run. A target that is not a path must be `HEAD` or end in `..HEAD`, because the workflow reads the checked-out tree; any other ref pauses the run. An empty diff since `base` also pauses the run. Put caller notes elsewhere. |
| `plugin_root` | Plugin dir. Default: `plugins/expectation-fit`. From another repo, pass the absolute path. |
| `out` | Ignored for tree writes. The report is always run scratch. |
| `stamp` | Optional label recorded in Coverage. Does not name a repo file. |
| `base` | A commit SHA, such as the output of `git merge-base origin/main HEAD`. Required when the target is not a path. A ref name such as `origin/main`, or a missing base, pauses the run before any agent starts with "Pass base as a commit SHA." The script builds the diff (`git_diff_since`) and sets the scope mode itself. No agent prompt contains the base. A file, `./` / `../` path, or a last-segment alphabetic extension (`docs/index.html`, `README.md`) is a path target and gets no diff. Directory paths should end with `/`. |
| `config` | Optional `.expectation-fit` directory. Same idea as the skill `config:` token. |

The confidence gate runs before verify. A below-gate finding gets no skeptic, and
Coverage lists it as `below_confidence_gate`. Then at most 16 findings go to
verify. They are sorted by severity, then confidence, before the cap. Drops are
logged and listed in Coverage. The run logs the total verify tokens once.

Each skeptic returns `confirmed`, `not_real`, or `unverifiable`. Only a confirmed
finding with evidence stays, and it carries the skeptic's reason and evidence
(`verifier_reason`, `verifier_evidence`). Any `unverifiable` or `verifier_failed`
row sets Not ready, with the observation "N findings could not be verified". A lens
that cannot read the target starts an observation with `failed:` and gets status
`failed`. The merge agent does not open product code, and it renders the all-clear
line only when the verdict is Ready.

Watch the run in `/workflows`. This dashboard lists runs, not saved files.

Interactive apply stays in the `/fit-review` skill. This workflow does not
write product code or docs files. Read the report from `/workflows` scratch.

## Limits (first cut)

This is a Grok runtime, not a second copy of the Claude skill.

- Config is resolved by a read-only agent, then applied as booleans, a
  confidence gate, optional file-substring severity overrides, and
  policy notes in Coverage. It does **not** apply smell-first
  `severity_align`, principle overrides, pattern policy, or architecture
  thresholds the way `/fit-review` does. Treat this as a subset.
- The lens list in the script is a snapshot of `lens-catalog.md`.
- The JSON schema in the script is a snapshot of `findings-schema.json`.
- The report lives in run scratch. There is no `docs/` write and no
  `.expectation-fit/runs/` lifecycle.
