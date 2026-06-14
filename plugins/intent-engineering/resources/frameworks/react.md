# React — Conventions
> UI as a function of state: small composable components, data flows down, behaviour follows the user — surprises live in effects, keys, and stale closures.

## Idiomatic structure
- **Components are PascalCase** (`UserCard`, `OrderList`) — both the function/identifier and, by most conventions, the file (`UserCard.tsx`). React requires capitalised names to distinguish components from DOM tags (`<userCard>` would render an unknown HTML element). Lowercase tags are reserved for host elements.
- **Hooks are camelCase prefixed with `use`** (`useAuth`, `useCartTotal`). The `use` prefix is not cosmetic: the linter (`eslint-plugin-react-hooks`) relies on it to enforce the Rules of Hooks. A plain function that calls hooks must be renamed to `use*` or it is misclassified.
- **Non-component helpers are camelCase** (`formatPrice`, `parseQuery`) and live in `utils`/`lib`, not in component files.
- **Colocation over global buckets.** Keep a component, its styles, its test, and its local hooks together (`UserCard/` with `UserCard.tsx`, `UserCard.test.tsx`, `useUserCard.ts`). Promote to a shared folder only when a second consumer appears. Feature-based folders (`features/checkout/`) scale better than type-based (`components/`, `hooks/`, `containers/` everywhere).
- **One primary component per file**, exported as the default or a named export matching the filename. Small private subcomponents may share the file.
- **`index.ts` barrels** are convenient for public surfaces but avoid deep barrels that obscure where things live and create circular imports.

## Core conventions (what a React dev expects)

### Components (function components, props, composition)
- **Function components are the default.** Class components are legacy; new code uses functions + hooks. Lifecycle logic lives in hooks, not `componentDidMount`.
- **Props are read-only.** A component must never mutate its props. Treat the props object as immutable input (like function arguments).
- **Composition over inheritance.** React has no component inheritance model. Share UI by composing components and passing `children`/render props/slots, not by subclassing.
- **Keep components pure during render.** Rendering must be a pure function of props + state: same inputs → same JSX, no side effects, no I/O, no mutation of external variables. Side effects belong in event handlers or effects.
- **Prefer many small components** with clear single responsibilities over one component doing fetching, transforming, and rendering.

### Hooks (Rules of Hooks)
The two rules, enforced by `eslint-plugin-react-hooks`:
1. **Only call hooks at the top level** of a component or custom hook — never inside conditions, loops, nested functions, `try/catch/finally`, or after an early `return`. React identifies hooks by call order across renders; conditional calls corrupt that order.
2. **Only call hooks from React functions** — function components or other `use*` hooks. Not from plain JS functions, event handlers, or class components.
- **Dependency arrays must be complete and honest.** List every reactive value (props, state, derived values, functions) the effect/memo/callback reads. Do not omit deps to "run once" — that produces stale closures. Restructure instead (move the function inside, use a ref, or `useReducer`).
- **Custom hooks extract reusable stateful logic.** When two components share non-trivial state behaviour, lift it into a `use*` hook. Custom hooks share *logic*, not *state* — each call gets its own independent state.

### State & data flow
- **Lift state to the lowest common ancestor** of all components that read or write it; pass it down as props and pass setters down as callbacks (inverse data flow). Data flows one way: down.
- **Keep state minimal — do not store derivable values.** If something can be computed from existing props/state, compute it during render. Don't mirror props into state, and don't keep a `count` alongside the array it counts.
- **Controlled inputs** drive form values from state (`value` + `onChange`); **uncontrolled inputs** read from the DOM via a ref/`defaultValue`. Pick one per field and don't switch at runtime.
- **Never mutate state directly.** Create new objects/arrays (`setItems([...items, x])`), because React compares by reference to decide whether to re-render.
- **`useState` for local; lift, context, or a store for shared.** Reach for Context / a state library (Redux Toolkit, Zustand, Jotai) only when prop-drilling genuinely hurts — not by default.

### Keys, lists, effects
- **Keys must be stable, unique identities** tied to the data (an `id`), not the array index. Keys tell React which item is which across renders; an index reassigns identity when the list reorders/filters, corrupting state and inputs.
- **Effects synchronize with external systems** (network, DOM, subscriptions, timers) — not for deriving render data. If no external system is involved, you probably don't need an effect.
- **Clean up effects** (return a cleanup function) for subscriptions, timers, and listeners to avoid leaks and double-fires.

## Convention violation smells (detectable — feed the convention lens)
- **Hook called conditionally / in a loop / after an early return** — e.g. `if (open) useEffect(...)`. Breaks Rule 1.
- **Hook called from a non-`use` function or an event handler** — breaks Rule 2; also a name smell if a helper calls `useState`.
- **Missing/incomplete dependency array** — `useEffect(fn, [])` that reads `props.userId`; deps disabled with an eslint-disable comment.
- **Array index as `key`** in a list that can reorder, filter, or insert — `items.map((x, i) => <Row key={i} />)`.
- **Direct state mutation** — `state.list.push(x)` / `obj.field = v` then `setState(obj)`; sort/splice on a state array in place.
- **State that mirrors props** — `const [v, setV] = useState(props.value)` with an effect syncing them; should be derived or reset via `key`.
- **Derived value stored in state + synced by effect** — `useEffect(() => setFullName(a + ' ' + b), [a, b])`; should be computed in render (or `useMemo` if expensive).
- **Business/fetch logic inline in a component** that should be a custom hook or service — large `useEffect` bodies doing transformation + state juggling.
- **Uncontrolled → controlled switch** — a field whose `value` starts `undefined` then becomes a string (React warns at runtime).
- **Lowercase component name** used as a JSX tag, or a component returning multiple roots without a fragment.

## Least-astonishment / experience traps specific to React
- **Effect runs more often than expected** — missing/extra deps, or an object/array/function recreated every render passed as a dep, causing an infinite loop or repeated fetches.
- **Stale closure** — a callback or effect captures an old prop/state value because it was excluded from deps; the user sees outdated data or a "one click behind" bug.
- **I/O on render** — fetching, mutating refs, or logging to a server in the render body. Render must be pure; side effects move to handlers/effects. Surprising double-execution in Strict Mode exposes these.
- **Missing loading / error / empty states** — rendering `data.map(...)` while `data` is still `undefined` (crash), or showing a blank screen instead of a spinner/error/"no results".
- **State reset surprise** — a component keeps stale state when it should reset on identity change (fix with a `key`), or resets unexpectedly because a parent remounts it.
- **Non-accessible custom controls** — a clickable `<div>` with no `role`, `tabIndex`, keyboard handler, or focus management; a modal that doesn't trap focus or restore it on close.
- **Silent destructive actions** — irreversible delete with no confirmation, or optimistic UI that doesn't roll back on failure.
- **Layout flash from effect-driven state** — reading layout in `useEffect` (after paint) instead of `useLayoutEffect`, causing a visible jump.

## Idiomatic vs non-idiomatic examples

**1. Derived value — don't store it in state**
```jsx
// ❌ extra render pass + a value that can drift out of sync
const [fullName, setFullName] = useState('');
useEffect(() => { setFullName(first + ' ' + last); }, [first, last]);

// ✅ compute during render
const fullName = first + ' ' + last;
```

**2. Keys — stable identity, not index**
```jsx
// ❌ index reassigns identity when the list reorders/filters → wrong row state
{todos.map((t, i) => <Todo key={i} todo={t} />)}

// ✅ stable id from the data
{todos.map((t) => <Todo key={t.id} todo={t} />)}
```

**3. Hooks at the top level, not conditionally**
```jsx
// ❌ breaks the Rules of Hooks — call order changes between renders
function Profile({ userId }) {
  if (!userId) return <Login />;
  const [user, setUser] = useState(null); // never reached on first render
}

// ✅ hooks first, branch after
function Profile({ userId }) {
  const [user, setUser] = useState(null);
  if (!userId) return <Login />;
  return <Card user={user} />;
}
```

## Sources
- Rules of Hooks — https://react.dev/reference/rules/rules-of-hooks
- Thinking in React — https://react.dev/learn/thinking-in-react
- You Might Not Need an Effect — https://react.dev/learn/you-might-not-need-an-effect
- Keeping Components Pure — https://react.dev/learn/keeping-components-pure
- Rendering Lists (keys) — https://react.dev/learn/rendering-lists
- Sharing State Between Components — https://react.dev/learn/sharing-state-between-components
- Reusing Logic with Custom Hooks — https://react.dev/learn/reusing-logic-with-custom-hooks
- Controlled vs Uncontrolled Components — https://www.freecodecamp.org/news/what-are-controlled-and-uncontrolled-components-in-react/
- Index as a key is an anti-pattern — https://medium.com/@robinpokorny/index-as-a-key-is-an-anti-pattern-e0349aece318
