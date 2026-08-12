# Grok workflows (optional runtime)

These files are a Grok runtime for intent-engineering. They are not part of the
Claude Code plugin package. The installable plugin stays under
`plugins/intent-engineering/`.

## ie-review

A config agent resolves `.intense` (or plugin defaults) and selects lenses.
Selected lenses run together using the shared subagent template slots. Then
one skeptic per finding. A finding is kept only with evidence and after the
confidence gate. Merge is read-only. A publisher writes
`docs/intent-engineering/<stamp>-review.md` only. Product code is not edited.

From a Grok session in this repo:

```
/workflow ie-review {"target":"origin/main...HEAD"}
```

Useful args:

| Field | Role |
|---|---|
| `target` | Required. Diff, branch, or path to review. |
| `plugin_root` | Plugin dir. Default: `plugins/intent-engineering`. From another repo, pass the absolute path. |
| `out` | Published report path. Default: `docs/intent-engineering/<hash>-review.md`. |
| `stamp` | Used only when `out` is omitted: `docs/intent-engineering/<stamp>-review.md`. |
| `base` | Optional git ref. Lenses are told to run `git diff` against it. |
| `config` | Optional `.intense` directory. Same idea as the skill `config:` token. |

At most 16 findings go to verify. They are sorted by severity, then confidence,
before the cap. Drops are logged and listed in Coverage.

Watch the run in `/workflows`. This dashboard lists runs, not saved files.

Interactive apply stays in the `/ie-review` skill. This workflow writes the
published report only. It does not change product code.
