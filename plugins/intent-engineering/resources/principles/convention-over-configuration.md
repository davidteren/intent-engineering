# Convention over Configuration (CoC)
> Follow the framework's agreed-upon defaults and get correct behavior for free; only write configuration for the parts that are genuinely unusual.

## What it is
Convention over Configuration (also called "coding by convention") is a software design approach that reduces the number of decisions a developer has to make by establishing sensible, predictable defaults. The developer only specifies the aspects of the application that are *unconventional*. When the desired behavior matches the tool's convention, the system simply works — no configuration required.

The term was popularized by **David Heinemeier Hansson (DHH)** to describe the philosophy of **Ruby on Rails** (extracted from Basecamp and open-sourced in 2004). The idea predates Rails — it builds on long-standing notions of default values and the [[least-astonishment|principle of least astonishment]], and is visible in the JavaBeans specification's goal to "provide default behaviour for 'normal' objects, but allow objects to override" — but Rails is where it became a named, load-bearing design pillar.

Other frameworks/tools that explicitly adopt CoC:
- **Apache Maven** — a standard project directory layout (`src/main/java`, `src/test/java`, `target/`, `pom.xml`) so that anyone who knows one Maven project immediately understands another.
- **Ember.js** — naming and file-location conventions wire routes, templates, and models together automatically.
- **Spring Boot / Spring** — auto-configuration and sensible starters over verbose XML.
- **Hibernate** — maps a `Person` class to a `people`/`person` table by default; annotations are needed only to deviate.

**The deal:** follow the convention and the framework gives you behavior for nothing. Deviate only when you have a real reason — and pay the configuration cost explicitly, in the one place the framework expects it.

Plain-language version: a Rails class `Sales` maps to a database table `sales` with no config at all. You write configuration only when you *can't* (or shouldn't) follow that pattern.

## Core tenets
- **Sensible defaults over ceremony.** The framework decides the boring stuff once so each developer doesn't re-decide it on every project.
- **Specify only the exceptions.** Configuration exists for the unconventional; the conventional path stays silent.
- **Conventions compound.** One naming rule (`Person` → `people`) lets the framework infer associations, foreign keys, routes, and more — abstractions cascade off a single agreed pattern.
- **Predictability is a feature.** A reader familiar with the convention can find and understand any project that follows it without a tour.
- **Low barrier to entry.** A beginner can benefit from conventions "in ignorance" — productive before understanding *why* the structure is shaped that way.
- **Deviation is allowed but visible.** You can override, but overrides are explicit and localized, not scattered.

## Why it matters
- **Less decision fatigue.** "Who cares what format your database primary keys are described by?" — decisions made once, framework-wide, free attention for the parts of the app that are actually unique.
- **Faster onboarding and review.** Conventional layout means a new contributor (or an automated reviewer) recognizes structure instantly; surprises stand out because the baseline is shared.
- **Smaller surface area.** No sprawling XML/config files describing things the framework could have inferred. Less config = fewer places for drift and bugs.
- **Consistency at scale.** Across many modules or many repos, convention keeps everything shaped the same way — the "site-wide look-and-feel" Maven describes.
- **Cheaper change.** When everything conventional looks the same, mass refactors and tooling (generators, linters, codemods) become possible.

## Violation smells (detectable signals)
These are the observable signals an automated convention reviewer should flag.

### Code
- **Boilerplate config for something the framework already conventions.** e.g. an explicit `self.table_name = "users"` on a `User` model, a hand-written route the resourceful router would have generated, an explicit foreign-key/association option that matches the default anyway.
- **Non-standard file/directory layout fighting the framework.** Sources outside `src/main/java` in a Maven project; Rails models/controllers/views placed off the conventional `app/` paths; test files not where the test runner expects them.
- **Reinvented naming for a thing the framework already names.** Custom singular/plural inflection, bespoke primary-key naming, a hand-rolled "find by id" when the ORM provides one, renaming a lifecycle hook the framework defines.
- **One-off pattern when the repo already has an established one.** A new feature using a different HTTP-client wrapper, error-handling shape, serializer, or directory idiom than the rest of the codebase.
- **Configuration that merely restates the default.** Settings explicitly set to the value they already have — noise that implies intent where there is none and will silently rot when the default changes.
- **Wrapper/indirection layer around a convention** that adds nothing but a second way to do the same thing.

### Project / repo
- **Inconsistent patterns across similar modules.** Two services that do the same kind of job structured in two different ways; one module uses the repo's standard generator output, the neighbor hand-rolls it.
- **A new module that ignores the repo's existing idiom.** New code that doesn't match the established directory structure, naming scheme, or layering the rest of the repo follows.
- **Convention drift over time.** Newer code diverging from the documented or de-facto standard with no recorded decision.
- **Per-module config files re-deriving what a shared/root config already establishes.**

### Planning / specs
- **A plan that proposes a bespoke structure where a conventional one already exists.** "We'll invent our own folder layout / naming scheme / config format" when the framework or repo already prescribes one.
- **Specs that re-specify default behavior** as if it were custom work (estimating effort to build what the framework gives for free).
- **No justification for deviation.** A plan that departs from the established idiom without naming *why* the convention doesn't fit.

## Good vs bad examples

**1. Rails table mapping (deviation that restates the default)**

```ruby
# BAD — configuring what convention already gives you
class User < ApplicationRecord
  self.table_name = "users"        # this IS the convention; pure noise
  self.primary_key = "id"          # already the default
end

# GOOD — say nothing; the convention maps User -> users, pk :id
class User < ApplicationRecord
end
```

**2. Rails routing (hand-rolled vs resourceful)**

```ruby
# BAD — seven manual routes for standard CRUD
get    "/articles",          to: "articles#index"
get    "/articles/new",      to: "articles#new"
post   "/articles",          to: "articles#create"
get    "/articles/:id",      to: "articles#show"
get    "/articles/:id/edit", to: "articles#edit"
patch  "/articles/:id",      to: "articles#update"
delete "/articles/:id",      to: "articles#destroy"

# GOOD — one conventional line generates all seven
resources :articles
```

**3. Maven layout (fighting the framework vs conforming)**

```xml
<!-- BAD — overriding the standard layout for no real reason -->
<build>
  <sourceDirectory>code/java</sourceDirectory>
  <testSourceDirectory>tests</testSourceDirectory>
</build>
```
```
GOOD — put sources where Maven expects them; no <build> overrides needed:
  src/main/java        application sources
  src/test/java        test sources
  src/main/resources   resources
  target/              build output
```

## How to apply

### In code review
- Ask: *does the framework or repo already have a convention for this?* If yes, the conventional form is the default expectation; flag the deviation and ask for the reason.
- Treat config that restates a default as removable noise.
- Treat a new file/dir/name that doesn't match the surrounding idiom as a smell until justified.
- Prefer the change that a reader already familiar with the framework would expect ([[least-astonishment]]).
- Don't demand convention where none exists — distinguish "violates an established convention" from "personal style preference."

### When introducing a NEW convention (and when deviation IS justified)
- A new convention is warranted when the same decision recurs across modules and there's no framework default. Document it once, apply it everywhere, and prefer the simplest rule that covers the cases ([[occams-razor]]).
- **Deviation from an existing convention is justified when** the conventional path genuinely cannot express the requirement, the default carries a real cost (performance, security, correctness) for this case, or an external system dictates a different shape. "Most applications worth building have some elements that are unique" — the skill is telling unavoidable uniqueness from unnecessary customization.
- When you do deviate: make it explicit, localize it, and name the reason in the code/PR so the surprise is surfaced, not hidden.

### In planning / plan validation
- Reject plans that budget effort to rebuild behavior the framework provides for free.
- Reject bespoke structures/naming/config formats where a conventional one already exists, unless the plan states why the convention doesn't fit.
- Require new modules in a plan to declare that they follow the repo's existing idiom (layout, naming, layering) — or to justify the departure.

## Relationship to other principles
- [[least-astonishment]] — CoC is one of the strongest ways to *be* unsurprising: conventional code behaves the way a reader already expects.
- [[occams-razor]] — conventions remove configuration entropy; the simplest expression is usually the conventional one, with no extra moving parts.
- [[dwim]] — "do what I mean": conventions let the framework infer intent from a name or location instead of demanding explicit instruction.
- [[software-philosophies]] — CoC sits alongside DRY and least-astonishment as a pillar of opinionated framework design; it also stands in tension with "explicit is better than implicit," which is the boundary to watch.

## Sources
- Convention over configuration — Wikipedia — https://en.wikipedia.org/wiki/Convention_over_configuration
- The Ruby on Rails Doctrine (DHH) — https://rubyonrails.org/doctrine
- Introduction to the Standard Directory Layout — Apache Maven — https://maven.apache.org/guides/introduction/introduction-to-the-standard-directory-layout.html
- Introducing Apache Maven (convention over configuration) — Sonatype — https://www.sonatype.com/maven-complete-reference/introducing-apache-maven
- The History of Ruby on Rails: Code, Convention, and a Little Rebellion — Codeminer42 — https://blog.codeminer42.com/the-history-of-ruby-on-rails-code-convention-and-a-little-rebellion/
