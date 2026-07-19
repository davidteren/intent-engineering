# CLAUDE.md

Project guidance for Claude Code (and any AI agent) working in this repository lives in
**[AGENTS.md](AGENTS.md)** — read it first.

It covers: what this repo is, the load-bearing rules (the `agents/` gitignore trap,
plugin self-containment, `${CLAUDE_PLUGIN_ROOT}` paths, read-only/never-push, two-layer
artifacts + `.intense/` conventions), the repo map, how a run works, the five lenses and their
contract, the shared contract layer, the config system, the knowledge base, how to
extend the plugin, and the quality bar.

Quick pointers:
- `PLAN.md` — design and phase detail.
- `STATUS.md` — current-state snapshot · `CHANGELOG.md` — dated change history.
- `plugins/intent-engineering/README.md` — end-user usage of the plugin.
