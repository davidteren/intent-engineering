# Principle Index

Map of every principle the plugin enforces to its source doc and owning lens. Lenses
read the source docs for detection heuristics; this index is the quick lookup.

| Principle | Source doc | Lens |
|-----------|-----------|------|
| Principle of Least Astonishment | `resources/principles/least-astonishment.md` | predictability |
| DWIM (Do What I Mean) | `resources/principles/dwim.md` | predictability |
| WYSIWYG | `resources/principles/wysiwyg.md` | predictability |
| Convention over Configuration | `resources/principles/convention-over-configuration.md` | convention |
| Occam's Razor (+ KISS, YAGNI) | `resources/principles/occams-razor.md` | simplicity |
| Human Interface Guidelines | `resources/principles/human-interface-guidelines.md` | experience |
| Look and Feel | `resources/principles/look-and-feel.md` | experience |
| User Experience Design | `resources/principles/ux-design.md` | experience |
| (philosophy landscape + tensions) | `resources/principles/software-philosophies.md` | all |

## Cross-cutting (agnostic)

| Topic | Source doc | Lens |
|-------|-----------|------|
| Naming | `resources/agnostic/naming.md` | predictability + convention |
| Defaults & Configuration | `resources/agnostic/defaults-and-configuration.md` | convention + simplicity |
| Error Handling | `resources/agnostic/error-handling.md` | predictability |
| API & Interface Design | `resources/agnostic/api-design.md` | predictability + convention |
| Accessibility | `resources/agnostic/accessibility.md` | experience |
| Information Architecture | `resources/agnostic/information-architecture.md` | experience |

## Framework conventions

| Stack | Source doc |
|-------|-----------|
| Ruby on Rails | `resources/frameworks/rails.md` |
| Ruby (language) | `resources/frameworks/ruby.md` |
| React | `resources/frameworks/react.md` |
| TypeScript | `resources/frameworks/typescript.md` |
| Python | `resources/frameworks/python.md` |
| Laravel (PHP) | `resources/frameworks/laravel.md` |
| Swift / iOS | `resources/frameworks/swift-ios.md` |

## Architecture (the 5th lens)

| Topic | Source doc | Lens |
|-------|-----------|------|
| Rails architecture smells | `resources/frameworks/rails-architecture.md` | architecture |
| Rails design-pattern catalog | `resources/patterns/rails.yaml` (+ `resources/patterns/README.md`) | architecture |
| Python architecture smells (FastAPI-first) | `resources/frameworks/python-architecture.md` | architecture |
| Python design-pattern catalog | `resources/patterns/python.yaml` | architecture |
| Laravel architecture smells | `resources/frameworks/laravel-architecture.md` | architecture |
| Laravel design-pattern catalog | `resources/patterns/laravel.yaml` | architecture |

## Config

| What | Source |
|------|--------|
| Resolution + merge rules | `references/config-resolution.md` |
| Global defaults | `config/defaults/{ways-of-working,patterns,thresholds}.yaml` |
| Project override | `.intense/*.yaml` at the repo root (scaffold with `/ie-init`) |

All plugin paths are relative to `${CLAUDE_PLUGIN_ROOT}/`.
