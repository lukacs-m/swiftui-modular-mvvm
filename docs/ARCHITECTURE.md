# Architecture

In-depth documentation of how this project is structured and why. For a quick
start, see `README.md`. For agent-oriented rules, see `AGENTS.md`.

## Overview

This is a modular MVVM iOS app. The defining characteristic: the app target holds
nothing but `@main`, and every piece of logic and UI lives in one of six
independent Swift packages, each representing a single architectural layer. The
packages depend on each other in one direction only, which makes the boundaries
real (enforced by the compiler) rather than conventional.

```
App (@main only)
 │  links Presentation + DI
 ▼
Presentation ─────────► DI ──────► Data ──────► Domain ──────► Model ──────► Common
(Views, ViewModels)  (composition  (impls,      (use cases,   (entities)   (utilities,
                      root, DI)     DTOs)         protocols)                  logging)
```

Dependencies always point right (down the stack). A higher layer may use a lower
one; a lower layer knows nothing about anything above it.

## The layers

### Common
Shared utilities with no domain or presentation knowledge. `Log` exposes native
`os.Logger` categories, preserving per-field privacy. `ViewState` lives in Presentation.
Depends on nothing internal.

### Model
Domain entities as plain `Sendable` value types (structs/enums). No logic, no
behavior — just data. Depends only on Common.

### Domain
The heart of the app's business rules, and crucially the place that defines
*abstractions*:
- **Repository protocols** — e.g. `any ArticleRepository` — describe what data
  operations exist, without saying how they're implemented.
- **Use cases** — callable structs (`callAsFunction`) that orchestrate repositories
  and apply business logic (sorting, filtering, validation, policy).
- **`DomainError`** — the error vocabulary the rest of the app speaks. Lower-level
  failures are mapped to this at the Data boundary.

Domain is pure Swift. It does not import Factory, URLSession, SwiftUI, or any
persistence framework, and it is actor-agnostic (not pinned to the main actor).

### Data
The concrete implementations of Domain's protocols. This is the only layer that
knows about transport and persistence — URLSession, decoding, DTOs and their
mappers, databases. It maps low-level errors (`URLError`, decoding failures) into
`DomainError` so those details never leak upward. Like Domain, it has no Factory
dependency and is actor-agnostic.

### DI (composition root)
The single place where abstractions are bound to implementations. DI imports the lower layers and the Factory framework, and declares the `Container` registrations
that connect, say, `any ArticleRepository` to `SampleArticleRepository`. It exposes
those bindings as `Container` keyPaths that the Presentation layer injects against.

Registrations live in `Sources/DI/Registrations/`, **one file per feature**, so the
wiring stays navigable as the app grows. DI re-exports FactoryKit
(`@_exported import FactoryKit`), so any module that imports DI also gets
`Container` and `@Injected` without importing Factory directly.

### Presentation
SwiftUI Views and their `@Observable` ViewModels. ViewModels inject Domain use
cases (via the DI keyPaths) and expose screen state as a `ViewState`. Views are
"dumb": they render state and forward user intent, with no business logic in
`body`. This package is **MainActor-isolated by default**, which fits a UI layer —
you write straightforward main-thread code and only step off it deliberately.

Presentation imports Domain and DI, but must not import Data. It still builds
Data transitively through DI and uses Factory APIs through the DI re-export.
`make check-architecture` enforces forbidden imports and package dependency direction
in CI; the composition pattern does not make Presentation independent of Factory.

## Why a separate DI package?

An earlier design kept registrations inside Data. That forced Presentation to link
Data (a boundary leak) and made the `Container` keyPaths invisible where they were
used. Pulling composition into its own package fixes both problems:

- Domain and Data stay completely free of any DI framework.
- Presentation depends only on DI for keyPaths — never on concrete implementations.
- All wiring lives in one place that splits cleanly into per-feature files.

This is the classic composition-root pattern: exactly one component knows how the
whole object graph is assembled, and it sits at the top.

## Local storage

On-device persistence uses **SQLiteData**
([pointfreeco/sqlite-data](https://github.com/pointfreeco/sqlite-data)), not
SwiftData. It is a thin, fast layer over SQLite (GRDB underneath) that keeps queries
explicit: filtering, sorting, joining and aggregating happen in SQL rather than by
materialising an object graph in memory. That suits this architecture better than
SwiftData, whose `@Model` types are non-`Sendable` reference types tied to a live
`ModelContext` — an awkward fit for a `Sendable`, actor-agnostic Data layer, and
hard to test without standing up a container. SQLiteData also gives explicit
migrations and optional CloudKit sync (`SyncEngine`) without changing the storage
model.

Where it lives: the dependency belongs to **Data only**. Domain keeps declaring
repository protocols in terms of `Model` entities and never learns that SQLite
exists. `@Table` types are persistence records — the storage-side twin of a DTO —
and are mapped to `Model` entities at the Data boundary, exactly as `ArticleDTO` is
for the network path, with SQLite failures mapped into `DomainError`. The database
handle and its migrations are created in Data and bound in DI as a `.singleton`
Factory, so the app target stays `@main`-only.

SQLiteData's `@FetchAll` / `@FetchOne` property wrappers are deliberately *not* used
in Presentation: they would wire a view straight to the database and bypass Domain.
Views render a ViewModel's `ViewState`; the repository does the querying.

## Concurrency model

The project adopts Swift 6.2+ "approachable concurrency" with per-layer default
isolation:

- **Presentation** sets `.defaultIsolation(MainActor.self)` — UI code is on the main
  actor by default. To run work off the main actor, mark a function `@concurrent`.
- **Common, Model, Domain, Data, DI** are actor-agnostic (no default isolation).
  With `NonisolatedNonsendingByDefault`, their async methods inherit the caller actor.
  Mapping and sorting reached from a ViewModel can therefore execute on MainActor.
  Use a targeted `@concurrent` function for substantial CPU work, or a persistence
  actor that owns mutable state; do not add actor hops just for the small demo.
- **App target** mirrors a fresh Xcode 26 project: MainActor default isolation +
  approachable concurrency, set in `project.yml`.

All packages compile in Swift 6 language mode with strict concurrency. Entities are
`Sendable`; repository protocols are `Sendable`.

## The `public import` model

Every package enables the `InternalImportsByDefault` upcoming feature: a plain
`import Foo` is `internal`, and a module must be imported with `public import Foo`
if any of its types appear in the importing file's *public* API. This keeps each
module's public surface honest about its true dependencies.

In practice this means, for example, `Model/Article.swift` writes
`public import Foundation` because its public properties are `UUID` and `Date`, and
`Presentation`'s ViewModel writes `public import Observation` because the
`@Observable` macro generates a public conformance. The rule and a full set of
worked examples are in `AGENTS.md`.

## Tooling

- **XcodeGen** generates `MyApp.xcodeproj` from `project.yml`; the project file is
  not committed. Edit the YAML, run `make generate`.
- **Makefile** wraps every task (`make help` lists them): setup, generate, build,
  test, lint, format, rename, and new-project.
- **SwiftFormat** (`.swiftformat`) and **SwiftLint** (`.swiftlint.yml`) enforce
  style; both skip `Tests/` and `Package.swift`.
- **CI** (`.github/workflows/ci.yml`) runs format-check, lint, generate, test, and
  build on every push/PR.
- The toolchain is pinned to Swift 6.3.1 (`.swift-version`).

## The reference feature

A complete `Article` slice ships as a worked example spanning all layers:

| Layer | File(s) |
|---|---|
| Model | `Article.swift` |
| Domain | `ArticleRepository.swift`, `DomainError.swift`, `FetchArticlesUseCase.swift` |
| Data | `ArticleDTO.swift`, `SampleArticleRepository.swift` (stubbed transport) |
| DI | `Registrations/ArticleRegistrations.swift` |
| Presentation | `ViewState.swift`, `ArticleListViewModel.swift`, `ArticleListView.swift` |
| Tests | Domain sorting/error tests, Data mapping/cancellation tests, Presentation state/lifecycle tests |

Use it as the pattern to copy. To remove it and start clean, run `make new-project`.
Step-by-step instructions for adding your own feature are in `README.md`
("Adding a new feature") and `AGENTS.md` ("Implementing a feature").

## Error and screen contracts

Repository mapping is all-or-nothing for the sample: invalid UUIDs or dates throw
`DomainError.invalidData`. Cancellation is rethrown separately, including cancelled
URL requests; it is not a network/unknown operational failure. `DomainError.swift`
survives removal of the Article example.

Presentation owns `ViewState`, single-flight loading, and the localized user-facing
error messages. Initial loads and retries show loading; refresh preserves content.
Cancellation restores the previous state, and refresh failures use a separate inline
error so loaded content remains accessible. Interface strings resolve from the
Presentation resource bundle. Previews render state directly without shared DI overrides.

The root app lockfile and DI/Presentation package lockfiles are retained outside
build artifacts. Generation restores the app lockfile; normal build/test commands
require the pins. See README for dependency updates and bootstrap regression checks.
