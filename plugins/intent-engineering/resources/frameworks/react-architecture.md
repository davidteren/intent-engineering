# React — Architecture Smells

> one-line essence: structural anti-patterns that make a React app hard to change.

## How the lens uses this doc

Heuristic-first (count + responsibility judgment via Read/Grep/Glob/Bash); optionally enrich
with `eslint` (`react-hooks`, `complexity`, `max-lines`) or `madge` (circular deps) if
installed (never required). Thresholds come from resolved config
(`config/defaults/thresholds.yaml` -> `.intense/thresholds.yaml` override). A threshold is a
SIGNAL to look closer, not an automatic verdict — judge responsibilities.

React is a UI library, not an app framework, so its structural discipline is about **where
responsibilities live inside the component tree**: UI renders from props/state, *logic* lives
in **custom hooks**, *data fetching* lives in a data layer (a query hook / service), and data
flows down by **composition** rather than being threaded through every layer. The failure
mode at scale is the "500-line component that mixes data fetching, business logic, and UI
rendering" — plus its cousins: prop drilling, effects standing in for derived state, and a
Context that has quietly become global state. This pack covers those *structural* smells; it
complements the **convention** lens (React idiom, keys, stale closures) and the **experience**
lens (UX, interaction states, a11y), which own their own concerns. When a repo states its own
structure in `CLAUDE.md`/`AGENTS.md`, that wins.

## Smells (detectable)

**Canonical smell ids** (the stable vocabulary used by the finding `smell` field, the
`severity_overrides` keys in `.intense/ways-of-working.yaml`, and the architecture lens).
Smell ids are **kebab-case**; design-pattern ids (in `patterns/react.yaml`) are
**snake_case** — two adjacent id systems, deliberately distinct casing.

| Smell id | Section |
|----------|---------|
| `god-component` | 1. God component (too large / mixes concerns) |
| `logic-in-component` | 2. Business logic / data fetching in a component |
| `fat-hook` | 3. Fat / god custom hook |
| `prop-drilling` | 4. Prop drilling |
| `effect-overuse` | 5. useEffect overuse (effect where none is needed) |
| `god-context` | 6. God context (global state by accident) |
| `god-module` | 7. God module / barrel-file hub |
| `law-of-demeter` | 8. Law of Demeter violations |

### 1. God component (too large / mixes concerns) — `god-component`
- **Signal:** A component over `react.component.max_loc`, with JSX nested past
  `react.component.max_jsx_depth`, taking more than `react.component.max_props` props, or
  holding more than `react.component.max_hooks` hook calls / `react.component.max_use_state`
  `useState`s. Grep `.jsx`/`.tsx` for the component function and measure. The defining trait
  is *mixed concerns*: one component fetches data, holds business logic, manages lots of
  local state, AND renders a large tree.
- **Why it matters:** A god component can't be understood, tested, or reused in isolation;
  every change risks unrelated parts; many `useState`s + effects create tangled update graphs.
- **Confirm (not just count):** A large but cohesive *presentational* component (a complex
  form layout) is far less alarming than a medium one that mixes fetching + logic + UI. Weight
  *mixed responsibilities* over raw LOC. A composition root / page that wires children is
  expected to be longer.
- **Fix direction:** Extract logic into custom hooks; split the UI into smaller components;
  move data fetching to a query hook. Apply single-responsibility per component.
- **Default severity:** P2 when concerns are mixed (fetch + logic + UI); P3 when only size
  trips and the component is cohesive.

### 2. Business logic / data fetching in a component — `logic-in-component`
- **Signal:** `fetch(`/`axios`/`fetch`-wrapper calls, query building, business rules, or heavy
  data transforms written **inline in a component body** instead of a custom hook or data
  layer. Grep component files for `fetch(`, `axios`, `.then(`, and non-trivial computation in
  the render body (vs in a `useMemo`/hook).
- **Why it matters:** Logic in the render body re-runs every render, can't be reused across
  components, and can't be tested without rendering. Mixing the data layer into the UI couples
  the component to an API shape.
- **Confirm (not just count):** Deriving a value from props for rendering is fine (and often
  belongs *in render*, not an effect — see #5). The smell is *imperative data fetching* and
  *business rules* in the component, not pure presentational computation.
- **Fix direction:** Extract a `useThing()` custom hook (or a query hook with React Query/SWR)
  that owns fetching and exposes data/state; keep the component rendering that data.
- **Default severity:** P2 when fetching/business logic lives in the component; P3 for a heavy
  inline transform that should be a `useMemo`/helper.

### 3. Fat / god custom hook — `fat-hook`
- **Signal:** A custom hook (`useX`) over `react.hook.max_loc`, or returning more than
  `react.hook.max_returns` values, or bundling several unrelated concerns. Grep `hooks/**` and
  `use[A-Z]` definitions.
- **Why it matters:** Custom hooks are React's logic-reuse unit; a god hook hides too much
  behind one call, couples unrelated concerns, and becomes as hard to change as the god
  component it replaced.
- **Confirm (not just count):** A hook returning a cohesive small API (`{ data, error,
  isLoading }`) is healthy even if internally substantial. Flag hooks that return a sprawling
  grab-bag or mix unrelated responsibilities (fetching + form state + routing).
- **Fix direction:** Split into focused hooks composed together; each hook owns one concern.
- **Default severity:** P2 for a god hook mixing concerns; P3 for an oversized but cohesive hook.

### 4. Prop drilling — `prop-drilling`
- **Signal:** A prop passed through intermediate components that don't use it, just to reach a
  deep child — the same prop name reappearing across 3+ component layers, or components taking
  more than `react.component.max_props` props largely to forward them. Trace a prop's
  pass-through depth.
- **Why it matters:** Prop drilling couples every intermediate component to data it doesn't
  care about; a change to the data shape edits a whole chain, and the intermediates can't be
  reused without the pass-through props. Prop drilling is a *coupling* symptom.
- **Confirm (not just count):** One or two levels of explicit props is normal and clearer than
  hidden context. Flag deep chains of pure forwarding. Composition (`children`/slots) is often
  the fix before Context.
- **Fix direction:** Prefer **component composition** (pass JSX as `children`/render props) to
  invert the drilling; for genuinely cross-cutting data use Context (sparingly — see #6) or a
  state library.
- **Default severity:** P3 by default; P2 when the same prop drills through many layers
  (systemic coupling).

### 5. useEffect overuse (effect where none is needed) — `effect-overuse`
- **Signal:** `useEffect` used for things that don't need an effect: (a) computing **derived
  state** from props/state (a `setState` inside an effect that mirrors a prop) — should be
  computed during render or `useMemo`; (b) **transforming data for rendering**; (c) handling
  a **user event** (logic that belongs in the event handler); (d) **resetting/adjusting state
  when a prop changes** (use a `key` or compute during render). Grep for `useEffect` whose body
  is a `setState` derived from its own deps, or effects with no external system. A component
  with more than `react.component.max_hooks` effects is a corroborating signal.
- **Why it matters:** Effects that mirror state cause extra render passes, subtle bugs, and
  stale data; they make the data flow non-obvious. The React docs are explicit: *"You Might
  Not Need an Effect"* — effects are for synchronizing with **external** systems, not for
  reacting to React state.
- **Confirm (not just count):** Effects that talk to a real external system (subscriptions,
  the DOM, a non-React widget, network on mount via a query lib) are legitimate. Flag effects
  whose only job is to derive/copy React state.
- **Fix direction:** Compute derived values during render (or `useMemo`); move event logic into
  handlers; reset state with a `key`; fetch via a query hook. Remove the effect.
- **Default severity:** P2 for a derived-state effect (correctness + extra renders); P3 for a
  transform that would read better as `useMemo`.

### 6. God context (global state by accident) — `god-context`
- **Signal:** A single Context provider over `react.context.max_loc`, or one holding many
  unrelated concerns, or a value object rebuilt every render (causing every consumer to
  re-render). Grep `createContext`/`Provider` and the value passed to it.
- **Why it matters:** A Context that becomes "global state by accident" introduces hidden
  coupling (any consumer depends on the whole value) and expensive re-renders (a new value
  object re-renders every consumer on every provider render).
- **Confirm (not just count):** A focused context (theme, current user, a single feature's
  state) with a memoized value is healthy. Flag the kitchen-sink provider and unmemoized values.
- **Fix direction:** Split into focused contexts by concern; memoize the provider value; for
  large/cross-cutting app state use a dedicated state library rather than one mega-context.
- **Default severity:** P2 when one context bundles many concerns or re-renders broadly; P3 for
  an oversized but single-concern context.

### 7. God module / barrel-file hub — `god-module`
- **Signal:** A module over `react.module.max_loc`, or a barrel (`index.ts` re-exporting more
  than `react.module.max_exports`) that everything imports, or a `utils.ts`/`helpers.ts`
  grab-bag. Barrel files that re-export a whole directory are a known scale problem (circular
  deps, bloated bundles, slow builds).
- **Why it matters:** A hub module couples the codebase (everyone imports it), invites circular
  dependencies, and defeats tree-shaking when it re-exports everything.
- **Confirm (not just count):** A small, intentional barrel for a public package API is fine.
  Flag the everything-barrel and the unrelated-grab-bag util module.
- **Fix direction:** Import from specific modules; split grab-bag utils into intention-named
  modules; keep barrels small and deliberate.
- **Default severity:** P2 when it creates circular deps or broad coupling; P3 for a cohesive
  oversized module.

### 8. Law of Demeter violations (`a.b.c.d` chains) — `law-of-demeter`
- **Signal:** "Train wreck" navigation through props/objects — `props.user.account.plan.name`,
  `data.response.items[0].owner.email` — reaching through several intermediate objects in JSX
  or logic. Grep for deep dotted access chains.
- **Why it matters:** Each extra dot couples the component to the internal shape of every
  intermediate object; a change to any link breaks distant code, and an `undefined` mid-chain
  throws far from its cause (mitigated but not fixed by `?.`).
- **Confirm (not just count):** Fluent/builder chains and array methods are not Demeter
  violations. Flag *navigation* through other objects' internals. Destructuring the needed
  fields at the boundary is the usual fix.
- **Fix direction:** Pass the specific value as a prop, destructure at the data boundary, or
  add a selector that returns exactly what the component needs.
- **Default severity:** P3 — usually localised; escalate to P2 when duplicated widely.

## General metrics

`react.general.max_function_loc` (long function/handler -> extract), `react.general.max_function_params`
(long parameter list -> a props object), and `react.general.max_nesting_depth` (deeply nested
conditionals/ternaries in JSX -> early returns, extracted components) apply to any function.

## Tool enrichment (optional)

These sharpen the heuristics; the lens must degrade gracefully when they are absent. Detect
presence first (`command -v eslint` / check `package.json` / `npx madge`). Never install
anything; never block on them.
- **eslint** (`eslint-plugin-react-hooks`, `complexity`, `max-lines`, `max-depth`) — the
  `exhaustive-deps` and complexity rules corroborate effect-overuse and god-component.
- **madge / dependency-cruiser** — circular-dependency and import-graph detection; corroborate
  god-module / barrel-file hubs.

When a tool is present, treat its output as *corroborating evidence* that raises confidence —
not as the source of truth. When absent, fall back to Read/Grep/Glob/Bash heuristics and say so.

## Relationship

[[../principles/occams-razor]], [[react]] (conventions), [[typescript]] (when typed),
patterns catalog (resources/patterns/react.yaml). UX/interaction-state/a11y concerns belong to
the experience lens, not here.

## Sources
- React docs — You Might Not Need an Effect (derived state, transforms, events don't need effects) — https://react.dev/learn/you-might-not-need-an-effect
- React docs — Reusing Logic with Custom Hooks — https://react.dev/learn/reusing-logic-with-custom-hooks
- React docs — Passing Data Deeply with Context (and when not to) — https://react.dev/learn/passing-data-deeply-with-context
- Modularizing React Applications with Established UI Patterns — Martin Fowler / Juntao Qiu — https://martinfowler.com/articles/modularizing-react-apps.html
- Container/Presentational Pattern (separating logic from view) — https://www.patterns.dev/react/presentational-container-pattern/
- Prop Drilling — Kent C. Dodds — https://kentcdodds.com/blog/prop-drilling
