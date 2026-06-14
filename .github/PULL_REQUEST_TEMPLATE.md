<!-- Open with a short, jargon-free What / Why / How a non-technical reader could follow.
     Put deeper technical notes, code references, and reviewer notes below this block. -->

## What / Why / How

**What:** <!-- in plain terms, what a user or developer experiences or needs -->

**Why:** <!-- why it matters / why now -->

**How:** <!-- the approach, plainly — no method names or internal symbols -->

---

## Details

<!-- Technical walkthrough, key files, trade-offs, reviewer notes. Delete if trivial. -->

## Checklist

- [ ] `ruby scripts/check-contracts.rb` passes locally (also runs in CI on this PR).
- [ ] If I touched `agents/`: `git ls-files plugins/intent-engineering/agents/` still lists **5** (the gitignore trap).
- [ ] If I added/renamed a **lens**: wired into `findings-schema.json` enum, `lens-catalog.md`, `scoring-rubric.md`, and the README.
- [ ] If I added a **resource doc** (principle/framework/agnostic): it has a detection ("smells") section + a `## Sources` section (≥2 links), and is cited in `principle-index.md`/`lens-catalog.md`.
- [ ] If I added a **pattern** or **threshold**: ids match across the catalog, `thresholds.yaml`, and `rails-architecture.md`.
- [ ] `CHANGELOG.md` updated if the change is user-facing.
- [ ] No secrets; run reports / scratch stay under `wip/` (gitignored).

<!-- See AGENTS.md for the full contributor guide and the load-bearing rules. -->
