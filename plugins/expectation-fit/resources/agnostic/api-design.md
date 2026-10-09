# API & Interface Design
> one-line essence: the interface is a contract; surprises in it are the most expensive kind

## What this is for
A cross-cutting reference for an automated reviewer evaluating the *contract
surface* of code — public function/method/module signatures and HTTP/REST
endpoints. This is where least-astonishment matters most: an interface is a
promise made to callers you will never meet, and once published, every surprise
in it is paid for repeatedly by every consumer, forever. Feeds the
**predictability** and **convention** lenses.

The interface is what a caller must understand to use the thing. Bloch's framing
holds: a public API is "one of a company's greatest assets" and "a public API,
like diamonds, is forever" — you get exactly one chance to get it right, and
mistakes can hurt callers for as long as the API exists. Ousterhout's framing is
complementary: the *cost* of a module to the rest of the system is its
interface, not its implementation. Cheap interface, expensive (capable)
implementation = a deep module.

## Principles
- **Consistency** — the same concept has the same shape everywhere. Same word
  for the same thing, same parameter order across a family of calls, same
  pluralization, same error shape. Consistency lets a caller generalize from one
  call to the next; inconsistency forces them to relearn each one.
- **Least astonishment** — behavior matches the signature, verb, and name. A
  method does the least surprising thing given its name. `get`/`fetch`/`find`
  read and don't mutate; `is`/`has` return booleans without side effects; a verb
  that says "create" doesn't also delete.
- **Deep modules, simple interfaces (Ousterhout)** — maximize capability behind
  a minimal surface. A *shallow* module (large interface relative to the
  functionality it provides) doesn't hide complexity, it just relabels it and
  passes it to the caller. Prefer one powerful, well-named entry point over many
  thin pass-through methods.
- **Hard to misuse (Bloch)** — make the easy path the correct path. Prefer types
  that make illegal states unrepresentable over runtime validation; minimize
  accessibility (expose only what callers need); make the common case require no
  configuration. "If your users have to read the documentation to use the API,
  the API is not as good as it could be."
- **Predictable errors** — failures are explicit, typed/coded consistently, and
  reported the same way across the surface. No silent failure, no "returns null
  sometimes, throws other times" for the same kind of error.
- **Idempotency where expected** — operations that callers will reasonably
  retry must be safe to retry. This maps directly onto HTTP verb semantics.
- **HTTP verb semantics** — GET is safe (no observable side effects) and
  idempotent; HEAD/OPTIONS safe; PUT and DELETE idempotent; POST is neither.
  PATCH is not guaranteed idempotent. Honor these — clients, proxies, and caches
  rely on them.
- **Uniform interface / nouns not verbs** — REST resources are things (nouns)
  acted on by the standard verb set; the action lives in the HTTP method, not
  the URL.

## Detectable smells (feed the lenses)

### Code APIs (predictability)
- **Inconsistent return types across similar functions** — `getUser` returns an
  object, `getOrder` returns null-or-object, `getItem` throws. Same family,
  three contracts.
- **Boolean trap parameters** — `createWidget(true, false, true)` at the call
  site is unreadable; the caller cannot tell what the flags mean without opening
  the definition. Smell: ≥2 boolean params, or any positional boolean on a
  public call.
- **Output parameter + return value** — function both mutates an argument and
  returns a value; caller can't tell which carries the result.
- **Hidden side effects** — a `get`/`read`/`is`/`calculate` that also writes,
  caches destructively, mutates input, or performs I/O. Name implies pure;
  behavior is not.
- **Signature implies one thing, does another** — `parse()` that also persists;
  `validate()` that mutates; a getter that lazily creates.
- **Inconsistent parameter order across a family** — `move(src, dst)` but
  `copy(dst, src)`; `(id, opts)` here and `(opts, id)` there.
- **Leaky/shallow interface** — caller must pass implementation details (a DB
  handle, an internal flag, a pre-computed value the module could derive itself),
  or call methods in a required-but-undocumented order (temporal coupling).
- **Over-exposed surface** — internal helpers, fields, and types left public;
  pass-through wrappers that add nothing.

### HTTP/REST (convention + predictability)
- **GET that mutates** — `GET /orders/42/cancel`, `GET /users?delete=1`. A safe
  verb performing an unsafe action; breaks caches, prefetchers, and crawlers.
- **Non-idiomatic status codes** — `200 OK` with `{"error": ...}` in the body;
  `200` for a failed create; `404` where `403` is meant; `500` for a validation
  error (should be `400`/`422`). Always-200 APIs.
- **Inconsistent resource naming / pluralization** — `/users` and `/order`
  (mixed plurality); `/getUserList` (verb in path); `camelCase` here,
  `snake_case` there; `/user_profile` vs `/userProfile` across endpoints.
- **Verb in URL where a resource fits** — `/createUser`, `/api/deleteOrder`,
  `/fetchInvoices`. The verb belongs in the method (`POST /users`,
  `DELETE /orders/{id}`).
- **Non-idempotent PUT/DELETE** — `DELETE` that errors `404` on a second call
  instead of being safely repeatable; `PUT` that appends instead of replacing.
- **Breaking changes without versioning** — removing/renaming a field, changing
  a type, tightening validation, or changing a status code on an unversioned,
  already-published endpoint.
- **Action-in-method mismatch** — `POST` used to fetch, `GET` with a request
  body that the server depends on.

### Consistency (cross-cutting)
- **The odd-one-out** — most endpoints/functions in a module follow a pattern,
  and a new one quietly doesn't (different error envelope, different pagination
  param, different auth header, different casing). The newest code is the usual
  offender. This is the highest-signal smell for the convention lens: it's
  detectable purely by comparison against siblings, no external knowledge needed.

## Good vs bad examples

**1. Boolean trap → named options (code)**
```
// bad — unreadable at the call site
createUser("ada", true, false, true);

// good — self-documenting; hard to mis-order
createUser("ada", { admin: true, sendEmail: false, verified: true });
```

**2. Verb-in-URL + GET-mutates → RESTful (HTTP)**
```
# bad
GET  /api/getUser?id=42
GET  /api/user/42/deactivate

# good — noun resources, verb in the method, plural & consistent
GET    /api/users/42
POST   /api/users/42/deactivations     # or PATCH /users/42 {active:false}
```

**3. Inconsistent error contract → uniform (code or HTTP)**
```
// bad — same family, three contracts
getUser(id)   -> User | null
getOrder(id)  -> throws NotFound
getItem(id)   -> { ok: false }

// good — one contract for the whole family
getUser(id)   -> Result<User, NotFound>
getOrder(id)  -> Result<Order, NotFound>
getItem(id)   -> Result<Item, NotFound>
```

## How to apply (review checklist)
- [ ] Does the **name** match the behavior? (read-verbs don't write;
      boolean-verbs have no side effects)
- [ ] Are **return types and error reporting consistent** across the family this
      call belongs to?
- [ ] Any **boolean-trap** or output-parameter signatures on the public surface?
- [ ] Is **parameter order** consistent with sibling calls?
- [ ] Is the **interface as small as it can be** for the capability provided
      (deep, not shallow)? Any internals leaking into the signature?
- [ ] HTTP: is the **verb honest**? (GET safe; PUT/DELETE idempotent; POST for
      non-idempotent creation)
- [ ] HTTP: are **status codes idiomatic** for success, client error, server
      error? No `200`-with-error-body.
- [ ] HTTP: **nouns not verbs**, consistent **plurality** and **casing** across
      every endpoint?
- [ ] Is this change a **breaking change** to a published contract? If so, is it
      versioned or additive-only?
- [ ] **Odd-one-out check**: compare against neighboring endpoints/functions —
      does this one follow the established pattern?

## Relationship
[[../principles/least-astonishment]] — the parent principle; an API is just the
contract surface where it's enforced most strictly.
[[../principles/convention-over-configuration]] — consistent, conventional
shapes mean callers need to configure and learn less.
[[../principles/wysiwyg]] — the signature/verb/name should *be* what the call
does; no gap between what you see and what you get.
See also: framework conventions and REST style guides for the project's
established patterns — match them rather than inventing a one-off.

## Sources
- How to Design a Good API and Why it Matters — Joshua Bloch — https://research.google.com/pubs/archive/32713.pdf
- A Philosophy of Software Design (deep modules / shallow interfaces) — John Ousterhout — https://web.stanford.edu/~ouster/cgi-bin/book.php
- Modules Should Be Deep — https://softengbook.org/articles/deep-modules
- APIs and the Principle of Least Surprise — DZone — https://dzone.com/articles/apis-and-the-principle-of-least-surprise
- Best practices for RESTful web API design — Microsoft Learn — https://learn.microsoft.com/en-us/azure/architecture/best-practices/api-design
- REST API URI Naming Conventions and Best Practices — restfulapi.net — https://restfulapi.net/resource-naming/
- The Ultimate Guide to REST API Naming Convention — Moesif — https://www.moesif.com/blog/technical/api-development/The-Ultimate-Guide-to-REST-API-Naming-Convention/
- API Naming Conventions — api.gov.au — https://api.gov.au/sections/naming-conventions.html
- HTTP method definitions (safe/idempotent semantics) — MDN — https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods
