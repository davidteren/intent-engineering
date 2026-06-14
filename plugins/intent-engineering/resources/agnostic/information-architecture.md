# Information Architecture (IA)
> one-line essence: organize so users find what they need without surprise

## What it is
Information architecture is the practice of structuring, organizing, and labeling content so users can find what they need and understand where they are (NN/g). It is the *blueprint* underneath the visible interface: the skeleton of categories, hierarchy, labels, and links that navigation and search then expose. IA and navigation are not the same thing — IA is the underlying structure (how content is grouped and related); navigation is one visible rendering of that structure (NN/g, "The Difference Between IA and Navigation"). A product can have good-looking navigation sitting on top of incoherent IA, and it will still feel like a maze.

Rosenfeld & Morville's *Information Architecture for the World Wide Web* defines four interacting components: **organization systems** (how content is grouped — sequential, hierarchical/tree, or matrix), **labeling systems** (the words used for categories and links), **navigation systems** (how users move through the structure), and **search systems** (how users query it directly). Dan Brown's eight IA principles (Objects, Choices, Disclosure, Exemplars, Front Doors, Multiple Classification, Focused Navigation, Growth) extend this into practical rules of thumb.

For a reviewer, IA is the structural layer of the **experience lens**: even a feature that is visually polished and functionally correct can fail because a user cannot find it, cannot tell what is important, or cannot get back.

## Principles
- **Clear content hierarchy (first / second / third).** What does the user see first, second, third? Priority should be expressed structurally and visually — one primary path, supporting items below it — not a flat field of equals. (NN/g flat-vs-deep hierarchy; Brown's Principle of Choices.)
- **Recognizable navigation model.** Users should recognize the structure on arrival: global nav for site-wide sections, local nav for siblings, utility nav for account/settings, breadcrumbs for "you are here." Choose an organization model deliberately — sequential (guided steps), hierarchical (broad→specific tree), or matrix (user picks their own path).
- **Grouping with rationale.** Categories should reflect users' mental models (validated by card sorting), not the org chart or the database schema. Each grouping should have a reason a user would recognize. Allow polyhierarchy (cross-listing one item in more than one category) when a thing genuinely belongs in two places.
- **Consistent labels (one vocabulary).** One concept = one word, used the same way everywhere. Labels should carry strong *information scent* — they should accurately predict what the user finds on the other side of the click (NN/g, "Information Scent"). Avoid vague labels like "Learn More."
- **Progressive disclosure.** Reveal detail in layers. Show a preview/summary first; let users drill in for more (Brown's Principle of Disclosure). Don't dump every option on the first screen.
- **Findability and discoverability.** *Findability* = users can locate something they know exists. *Discoverability* = users can stumble onto things they didn't know to look for (NN/g). Good IA supports both: clear paths plus visible entry points. Every page is a potential "front door" (most visitors do not enter via the homepage), so each screen must signal where the user is and what they can do next.

## Detectable smells (feed the experience lens)

### Hierarchy & priority
- No clear primary action — the screen offers many equal-weight buttons and the user can't tell what to do first.
- A dashboard of identical cards rendered at identical size/weight regardless of importance or frequency of use; everything competes, nothing leads.
- Flat structure where grouping is needed: a long undifferentiated list (20+ items) with no sections, or a deep funnel where a flat list would be faster.
- Visual weight contradicts importance — the rare destructive action is as prominent as the common primary one.

### Navigation
- Dead-ends: a screen with no clear way back, no breadcrumb, no obvious next step (violates "Front Doors"; users get stranded).
- Inconsistent nav across screens — the menu changes shape, position, or contents between sections so the user loses orientation.
- Critical actions hidden behind a hamburger or an overflow menu on desktop, where space exists to show them (NN/g: hidden nav hurts discoverability and engagement).
- Reliance on search to compensate for structure ("just let them search") instead of a real navigation model.
- No "you are here" signal — no active state, no breadcrumb, no section heading; the user can't tell their location in the structure.

### Labels & grouping
- Ambiguous or low-scent labels ("Learn More," "Click here," "Manage") that don't predict the destination.
- Mixed vocabulary for the same concept ("Sign in" vs "Log in" vs "Account access"; "Cancel" vs "Discard" vs "Close" used interchangeably).
- Arbitrary grouping that mirrors the team/database rather than user tasks; an "Other"/"Misc" bucket that absorbs anything inconvenient.
- Over-categorization: so many nested sub-categories that the path to any item is long and guessy.
- A single item that logically belongs in two categories is forced into one, so half the users never find it (missing polyhierarchy).

### Planning / specs (high value — plan validation)
- Plan names screens or features but never states the **IA**: what is shown first vs. later, how items are grouped, and which navigation model connects them.
- Screens listed as a flat inventory with no hierarchy or relationships ("we'll have a Settings page, a Reports page, a Profile page") and no statement of how the user moves between them.
- "Structure TBD," "nav to be decided later," or labels left as placeholders — structural decisions deferred past the point where they should anchor the design.
- No statement of the primary user task per screen, so priority/hierarchy cannot be assessed.
- New feature bolted onto an existing product with no answer to "where does this live in the current IA, and what does adding it do to the existing grouping?" (ignores Brown's Principle of Growth).

## Good vs bad examples

**Hierarchy.** *Bad:* a settings page lists 18 toggles in one ungrouped column. *Good:* the same toggles grouped under "Account," "Notifications," "Privacy," "Billing," with the most-changed group first — the user scans group headers, not 18 rows.

**Labels.** *Bad:* a row of links all reading "Learn More," so the label predicts nothing. *Good:* "See pricing," "Read the API docs," "Compare plans" — each label carries scent about its destination.

**Navigation / front doors.** *Bad:* a user lands on a deep product page from search and sees no breadcrumb, no category context, and no global nav — a dead-end. *Good:* the same page shows `Home › Tools › Reports › Monthly Summary`, a persistent global nav, and a clear primary action, so any page works as an entry point.

## How to apply

### In UX review
- Ask "what does the user see first, second, third?" on each key screen. If you can't answer, hierarchy is unclear.
- Trace the back-path and the next-step from every screen — flag any dead-end.
- List every label for a given concept across the product; flag synonyms and low-scent verbs.
- Check that the navigation model is the same shape on every screen and that "you are here" is always answerable.
- Where an item could belong in two categories, confirm it's reachable from both.

### In plan validation (dimensional rating)
Rate the plan's IA on three axes, not pass/fail:
- **Hierarchy clear?** Does the plan state, per screen, the primary task and what is shown first vs. progressively disclosed? (Low: flat feature list. High: explicit priority order.)
- **Navigation model defined?** Does it name the model (sequential / hierarchical / matrix) and how users move between named screens and get back? (Low: "structure TBD." High: a sitemap or flow.)
- **Grouping justified?** Is each grouping tied to a user mental model or task (ideally card-sort/tree-test evidence) rather than the org chart or schema? Does it account for growth and items that belong in two places?
A plan that names screens but answers "no" to all three has specified a feature set, not an information architecture — call that out as a structural gap before build.

## Relationship
[[../principles/ux-design]], [[../principles/human-interface-guidelines]], [[../principles/look-and-feel]]

## Sources
- What is Information Architecture (IA)? — Interaction Design Foundation — https://ixdf.org/literature/topics/information-architecture
- What is Navigation in UX Design? — Interaction Design Foundation — https://ixdf.org/literature/topics/navigation
- Information Architecture: Study Guide — Nielsen Norman Group — https://www.nngroup.com/articles/ia-study-guide/
- The Difference Between Information Architecture (IA) and Navigation — Nielsen Norman Group — https://www.nngroup.com/articles/ia-vs-navigation/
- Information Scent: How Users Decide Where to Go Next — Nielsen Norman Group — https://www.nngroup.com/articles/information-scent/
- Flat vs. Deep Website Hierarchies — Nielsen Norman Group — https://www.nngroup.com/articles/flat-vs-deep-hierarchy/
- Polyhierarchies Improve Findability for Ambiguous IA Categories — Nielsen Norman Group — https://www.nngroup.com/articles/polyhierarchy/
- A Guide to Information Architecture UX (Rosenfeld & Morville's 4 components; Dan Brown's 8 principles) — Baymard Institute — https://baymard.com/learn/information-architecture-ux
