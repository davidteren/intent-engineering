# Express / Node — Conventions
> Write code a Node service developer would recognise: layered, async-correct, and surprising no one.

Express is **unopinionated** — it imposes almost no structure, so conventions come from the
community's hard-won project-structure practice rather than the framework. The defaults below
are what an experienced Node developer assumes; fighting them produces the classic
"everything in one route file" service that nobody can change safely. When the service is
TypeScript, the [[typescript]] conventions also apply. A repo's `CLAUDE.md`/`AGENTS.md` wins
over these community defaults.

## Structure & layering (the big one)

- **3-layer architecture.** Keep three responsibilities separate: **route handlers /
  controllers** (HTTP transport), a **service layer** (business logic, HTTP-agnostic), and a
  **data-access layer** (repositories / ORM models). Logic flows down; nothing lower reaches
  up into HTTP.
- **No business logic in controllers.** A route handler parses the request, calls one
  service, and sends the response. Business logic in the handler becomes untestable spaghetti
  (you end up mocking `req`/`res`).
- **No `req`/`res` in the service layer**, and no HTTP status codes/headers returned from it
  — services take plain inputs and return domain values so they're reusable from a worker or
  CLI.
- **No SQL / ORM queries in controllers** — persistence lives in the data-access layer.
- **Separate the Express `app` from the `server`.** Build and export the `app` (middleware +
  routes) separately from `app.listen(...)`, so tests can import the app without binding a
  port. Split startup into small **loaders**.
- **One router per resource**, mounted with `app.use('/resource', router)`.

## Idiomatic Node / Express (what a practitioner expects)

- **`async`/`await` over callbacks.** Avoid the callback "pyramid of doom"; use promises and
  `async`/`await`. Never mix a callback and a returned promise in the same function.
- **Forward errors, don't swallow them.** In an async handler, `try/catch` and call
  `next(err)` (or wrap with `express-async-errors`/an `asyncHandler`). Express 4 does **not**
  catch async errors automatically.
- **One centralized error-handling middleware** (`(err, req, res, next)`), registered last,
  turns errors into responses. Distinguish *operational* errors (expected — bad input, 404)
  from *programmer* errors (bugs).
- **Config from the environment, via one config module.** Read `process.env` once (with
  `dotenv`) into a typed config object; the rest of the code imports `config`, never
  `process.env` directly (12-factor).
- **No logic in route-definition files beyond wiring** — point routes at controllers.
- **Use a real logger** (pino/winston), not `console.log`, in application code.
- **Validate input at the boundary** with a schema (Joi/Zod/express-validator) as middleware,
  not ad-hoc `if (!req.body.x)` checks scattered through handlers.
- **Dependency injection / explicit wiring** over reaching for singletons inside functions —
  it keeps units testable.
- **Don't block the event loop** — no synchronous CPU-heavy work or sync FS calls on the
  request path; offload to a worker/queue.

## Convention violation smells (detectable — feed the convention lens)

- Business logic, multi-step orchestration, or external calls **inside a route handler /
  controller** (belongs in a service).
- **ORM/DB queries** (`Model.find`, `sequelize`, `prisma.`, `knex`, raw SQL) **in a
  controller/route** instead of a service/repository.
- `req`/`res`/`next` referenced **in a service** module (layer leak).
- **`async` handler with an unguarded `await`** — no `try/catch`, no async wrapper (unhandled
  rejection).
- **Empty `catch {}` / `.catch(() => {})`** swallowing errors; logging-and-continuing on a
  real failure.
- **`process.env.X` reads scattered** across modules instead of one config module.
- **`console.log`** in application code instead of a logger.
- **Callback nesting** (pyramid of doom) where `async`/`await` reads cleaner.
- **`app.listen` mixed into the app-definition module** (no app/server separation).
- Inline `if (!req.body.field) return res.status(400)` validation instead of a schema.
- A single giant `index.js`/`routes.js` holding routes + logic + DB access (no layering).

## Least-astonishment traps specific to Node / Express

- **Express 4 doesn't catch async errors.** A rejected promise in an `async` handler won't
  reach your error middleware unless you `next(err)` or wrap the handler — it becomes an
  unhandled rejection instead. (Express 5 awaits handler promises; know which you're on.)
- **Code after `res.json()` keeps running.** Sending a response doesn't end the function;
  "optimizing" by responding early and continuing background work hides logic and races.
- **Middleware order is execution order.** `app.use` registration order decides what runs
  first; an auth or body-parser middleware registered after the route doesn't apply.
- **`process.env` values are always strings.** `process.env.PORT` is `"3000"`, not `3000`;
  `process.env.FLAG === 'true'` not a boolean — coerce in the config module.
- **A middleware that forgets `next()`** hangs the request silently — no error, just a
  timeout.
- **Unhandled promise rejections** can crash the process (and do, by default, in modern
  Node) — handle or attach `process.on('unhandledRejection', ...)`.

## Sources
- Bulletproof node.js project architecture (3-layer, service layer, config, loaders) — https://www.softwareontheroad.com/ideal-nodejs-project-structure/
- Node.js Best Practices (goldbergyoni) — project structure, error handling, code style — https://github.com/goldbergyoni/nodebestpractices
- Express docs — Error Handling (centralized handler, async errors) — https://expressjs.com/en/guide/error-handling.html
- Express docs — Production Best Practices: Performance and Reliability — https://expressjs.com/en/advanced/best-practice-performance.html
- The Twelve-Factor App — Config — https://12factor.net/config
