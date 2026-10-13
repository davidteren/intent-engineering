# intent-engineering has moved

This project is now **Expectation Fit**. It lives in a new repo:

**https://github.com/davidteren/expectation-fit**

Site: https://davidteren.github.io/expectation-fit/

## Why

The name "intent engineering" is already in use for a different approach to agentic
software development. Version 0.9.0 renamed the plugin to expectation-fit, and the
`/ie-*` commands became `/fit-*`.

## Switch your install

Run these in Claude Code:

```
/plugin marketplace remove intent-engineering-marketplace
/plugin marketplace remove expectation-fit-marketplace
/plugin marketplace add https://github.com/davidteren/expectation-fit
/plugin install expectation-fit@expectation-fit-marketplace
/reload-plugins
```

One of the two `remove` lines fails if you never added that marketplace. That is fine.

The full upgrade guide, with the old and new command names, is in the
[plugin README](https://github.com/davidteren/expectation-fit/blob/main/plugins/expectation-fit/README.md#upgrading-from-intent-engineering).

## What stays here

- The full history up to v0.9.0. The new repo has the same history and tags.
- Issues #1 to #62 and pull requests up to #64. Issue #63 moved to the new repo as
  [#1](https://github.com/davidteren/expectation-fit/issues/1).

File new issues in the new repo.
