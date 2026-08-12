# Grok workflows (optional runtime)

These files are a Grok runtime for intent-engineering. They are not part of the
Claude Code plugin package. The installable plugin stays under
`plugins/intent-engineering/`.

## ie-review

Report-only review. Five lenses run together, then one skeptic per finding.
A finding is kept only when the skeptic returns evidence. Nothing is applied
to the tree.

From a Grok session in this repo:

```
/workflow ie-review {"target":"origin/main...HEAD"}
```

Useful args:

| Field | Role |
|---|---|
| `target` | Required. Diff, branch, or path to review. |
| `plugin_root` | Plugin dir. Default: `plugins/intent-engineering`. From another repo, pass the absolute path. |
| `out` | Published report path. Default: `docs/intent-engineering/workflow-ie-review.md`. |
| `stamp` | Used only when `out` is omitted: `docs/intent-engineering/<stamp>-ie-review.md`. |
| `base` | Optional git ref. Lenses are told to run `git diff` against it. |

Watch the run in `/workflows`. This dashboard lists runs, not saved files.

Interactive apply stays in the `/ie-review` skill. This workflow does not write
product code.
