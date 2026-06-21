# MyApp

A SwiftUI app built on a strict, layered MVVM architecture. The app target is
intentionally minimal — **all logic and UI live in separate local Swift packages**,
one per architectural layer.

> **Documentation:** [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the deep
> dive, [`AGENTS.md`](AGENTS.md) / [`CLAUDE.md`](CLAUDE.md) for AI-agent
> instructions. This README is the practical quick start.

## Using this template

This repo is a GitHub **template repository**. To start a new app from it:

**1. Create your repo from the template.** Click **“Use this template” → Create a
new repository** on GitHub (or `gh repo create my-app --template <owner>/<this-repo>`).
You get a fresh repo with this structure and clean history — no fork relationship.
Then clone it and `cd` in.

**2. Strip the example and name your project.**

```
make new-project NAME=AcmeApp
```

The template ships with a complete example feature (`Article`) so the patterns are
visible end to end. `new-project` removes that example from all six packages,
renames the app shell to `AcmeApp` (bundle id, `@main` struct, project name, paths),
and regenerates the Xcode project — leaving you a clean, compiling skeleton.
`NAME` must be a valid Swift identifier (letters, numbers, underscores). Omit
`NAME=` if you only want to strip the example without renaming.

**3. Install the Xcode file templates.**

```
make install-templates
```

This adds the View/ViewModel and UseCase templates to Xcode’s **New File…** dialog
(under “MVVM Scaffold”), so you can generate scaffold-conforming code as you build.
Restart Xcode if it was open. See [`Templates/README.md`](Templates/README.md).

**4. Open and build.**

```
make open      # generates and opens AcmeApp.xcodeproj
make test      # run the package test suites
```

That’s the whole flow: **Use this template → `make new-project NAME=…` →
`make install-templates` → `make open`.** From here, add features layer by layer
(see *Adding a new feature* below) using the Xcode templates for the boilerplate.

> Prefer to keep the example feature while you learn the structure? Skip step 2,
> run `make setup` to generate the project, and explore the `Article` slice first.
> Run `make new-project` later when you’re ready to start clean.

## Architecture

```
┌─────────────────────────────────────────────┐
│  App target (MyApp.swift)                     │  @main only — no logic, no views
│  import Presentation                           │
└───────────────────────┬───────────────────────┘
                        │ links Presentation + DI
        ┌───────────────┴───────────────┐
        ▼                               ▼
┌──────────────────┐          ┌──────────────────────┐
│  Presentation     │          │  DI (composition root)│
│  Views + ViewModels│───────▶ │  Container registrations│
└─────────┬─────────┘          └──────────┬───────────┘
          │                               │ imports every layer
          │                    ┌──────────┴──────────┐
          │                    ▼                     ▼
          │            ┌──────────────┐      ┌──────────────┐
          │            │  Data         │      │  Domain       │
          │            │  Repo impls    │─────▶│  Use cases    │
          │            └──────────────┘      │  + protocols   │
          └──────────────────────────────────▶└───────┬───────┘
                                                      ▼
                                  ┌──────────────────────────────────┐
                                  │  Model    Value-type entities      │
                                  └─────────────────┬─────────────────┘
                                                    ▼
                                  ┌──────────────────────────────────┐
                                  │  Common   Utilities, ViewState     │
                                  └──────────────────────────────────┘
```

Each layer is its own SPM package under `Packages/`, with its own `Package.swift`.
Higher layers depend on lower ones through local path references
(`.package(path: "../Domain")`). Dependencies point downward only.

### The packages

- **Common** (`Packages/Common`) — shared utilities, `ViewState`, logging. No internal dependencies.
- **Model** (`Packages/Model`) — domain entities as plain structs/enums. → Common.
- **Domain** (`Packages/Domain`) — business logic, use cases, and repository *protocols* (abstractions). → Model, Common. Pure Swift — does **not** depend on Factory, networking, persistence, or UI.
- **Data** (`Packages/Data`) — concrete implementations of Domain protocols, DTOs, mappers. → Domain, Model, Common. The only layer that knows about transport/persistence. Does **not** depend on Factory.
- **DI** (`Packages/DI`) — the **composition root**. The only package that imports Factory for registration. It imports every layer, binds Domain protocols to Data implementations, and exposes the `Container` keyPaths that ViewModels inject against. Registrations live under `Sources/DI/Registrations/`, one file per feature, so the wiring scales. → Common, Model, Domain, Data, FactoryKit.
- **Presentation** (`Packages/Presentation`) — `@MainActor @Observable` ViewModels and SwiftUI Views. ViewModels inject Domain protocols via the keyPaths from DI. → Domain, Model, Common, DI. Never imports Data directly.

The dependency direction is always: View → ViewModel → Domain (protocol), with DI
binding Domain ← Data at the composition root. ViewModels and Views are fully
testable and previewable against mocks.

> The app links **Presentation** (for the root views) and **DI** (so the Factory
> registrations are compiled into the binary and available at resolution time).

### Why a separate DI package?

Putting registrations inside Data forced Presentation to link Data (a layering
leak) and made the `Container` keyPaths invisible where they were used. Isolating
composition in its own package means: Domain and Data stay free of any DI
framework, Presentation depends only on DI for the keyPaths (never on concrete
implementations), and all wiring lives in one navigable place that splits cleanly
into per-feature files as the app grows.

## Dependency injection — Factory (FactoryKit)

- Factory lives **only** in the DI package. `import DI` brings in `Container`, `@Injected`, etc. (DI re-exports FactoryKit), so ViewModels import DI rather than FactoryKit directly.
- Registrations live in `Packages/DI/Sources/DI/Registrations/`, one file per feature (e.g. `ArticleRegistrations.swift`), binding protocol types to concrete implementations with the `self { }` sugar.
- ViewModels use `@ObservationIgnored @Injected(\.someUseCase)`.
- Previews swap in mocks with `Container.shared.x.preview { Mock() }`.
- Tests use the Swift Testing `@Suite(.container)` trait for isolated, parallel-safe runs and `.register { Mock() }` (via `FactoryTesting`).

## Reference feature

A complete vertical slice ships as a reference, spanning all layers:

`Article` (Model) → `ArticleRepository` protocol + `FetchArticles` use case (Domain)
→ `RemoteArticleRepository` + DTO/mapper (Data) → `ArticleRegistrations` (DI)
→ `ArticleListViewModel` + `ArticleListView` (Presentation).

The repository's network call is stubbed with sample data so the app runs out of
the box. Replace `loadRawArticles()` in `RemoteArticleRepository` with a real
URLSession request to go live. To remove the example entirely, run
`make new-project` (see *Starting from a clean slate*).

## Swift toolchain & concurrency

The packages target the **Swift 6.3 tools version** and compile in **Swift 6
language mode** (`swiftLanguageModes: [.v6]`). Every layer enables the same set of
upcoming features, written against the stricter future-default semantics today:

- `ExistentialAny` — `any` required on existential types.
- `InternalImportsByDefault` — imports are `internal` unless declared `public import`. (That's why types crossing a module's public API — e.g. `Model` in Domain's public protocols — are imported with `public import`.)
- `MemberImportVisibility` — you must import the module a member comes from.
- `InferIsolatedConformances` — isolated conformance inference.
- `NonisolatedNonsendingByDefault` — `nonisolated` async functions run on the caller's actor.

**Default actor isolation** differs by layer, on purpose:

- **Presentation** sets `.defaultIsolation(MainActor.self)` — it's all SwiftUI Views and `@Observable` ViewModels, so main-actor-by-default is the right call.
- **Common, Model, Domain, Data, DI** stay actor-agnostic (no default isolation). Domain and Data especially should *not* be pinned to the main actor — networking, persistence, and pure logic belong off the main thread.
- The **app target** mirrors a fresh Xcode 26 project: `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `SWIFT_APPROACHABLE_CONCURRENCY = YES` in `project.yml`.

The toolchain is pinned in `.swift-version` (Swift 6.3.1). With [Swiftly](https://www.swift.org/install/),
`swiftly use` reads it; CI selects the matching Xcode.

## Linting, formatting & CI

- **SwiftFormat** ([nicklockwood/SwiftFormat](https://github.com/nicklockwood/SwiftFormat)) — config in `.swiftformat`. `make format` rewrites in place; `make format-check` verifies without writing (used by CI). Install with `brew install swiftformat`.
- **SwiftLint** — config in `.swiftlint.yml`, tuned to the layered design (keeps explicit `public`, allows short DI identifiers). `make lint`. Install with `brew install swiftlint`.
- **CI** — `.github/workflows/ci.yml` runs on every push/PR to `main`: selects the pinned Xcode, installs the tools, then runs `make format-check`, `make lint`, `make generate`, `make test`, and `make build`. The runner image and Xcode path are pinned in the workflow; GitHub rotates these over time, so update them if a run fails to find Xcode.

Both tools are optional locally (the Makefile prints an install hint if missing) but required in CI. The `.swiftformat` options are intentionally conservative — run `swiftformat --inferoptions Packages App` to tune them to your style.

## Quick start

A `Makefile` wraps the common tasks. Run `make help` to list them.

```
make setup                 # install XcodeGen and generate the project
make setup NAME=AcmeReader  # …and rename the project in the same step
make setup RESOLVE=1        # …and pre-resolve packages into the Xcode project
make new-project NAME=Acme  # strip the example slice and rename — start fresh
make open                  # open the Xcode project
make test                  # run every package's test suite
make build                 # build the app for the simulator
make lint                  # lint with SwiftLint
make format                # reformat in place with SwiftFormat
make install-templates     # install Xcode file templates (View/ViewModel, UseCase)
make rename NAME=NewName   # rename the project (app shell only, not the layers)
make clean                 # remove the generated project and build artifacts
```

### Why packages seem to "fetch again" when you open the project

`make setup` only generates the project by default — it does **not** resolve
packages unless you pass `RESOLVE=1`. Even with `RESOLVE=1`, Xcode still runs a
quick resolution *validation* pass on first open (checking `Package.resolved`
against the manifests). That pass is a cache hit, not a fresh download: SwiftPM
caches cloned repositories globally (`~/Library/Caches/org.swift.swiftpm`), shared
between the command line and Xcode. To keep it fast and deterministic,
`Package.resolved` is committed (it pins exact versions), so resolution never has
to re-query GitHub for tags.

There are two *separate* resolution scopes, which is the source of the "twice"
feeling:

- **Into the Xcode project** — `make resolve-app` (or `make setup RESOLVE=1`) writes into Xcode's `DerivedData/.../SourcePackages`. This is what the IDE reads.
- **Per layer package via the CLI** — `make resolve` writes a `Packages/<layer>/.build` checkout for each package. Only needed for command-line builds/tests without Xcode (e.g. `cd Packages/Domain && swift test`) or in CI.

Both share the same global repository cache, so whichever runs second is a cache
hit — but each keeps its own working checkout, which is why you may see resolution
happen in both places.

`make test` runs each package's suite in parallel (via `make -j`), and within a
package Swift Testing parallelizes too. To target a
specific simulator for `build` / `test-app`, override the destination:

```
make build DESTINATION='platform=iOS Simulator,name=iPhone 16 Pro'
```

> Each package declares both `.iOS(.v26)` and `.macOS(.v26)` in its manifest.
> `swift test` builds for the host Mac (not the simulator), so the macOS platform
> is required for APIs like `os.Logger` and `ContentUnavailableView` to be
> available during command-line testing. The app itself still ships iOS-only —
> the layers are UI-light and portable, so testing them on macOS is sound. If you
> add genuinely iOS-only code to a package, test it via `make test-app` (iOS
> simulator) instead.

### Renaming the project

```
make rename NAME=AcmeReader
```

### Starting from a clean slate

The scaffold ships with an example `Article` feature so you can see the pattern
end to end. When you're ready to build your own app, strip it:

```
make new-project              # remove the example slice
make new-project NAME=Acme    # …and rename the project at the same time
```

This deletes the `Article` files from all six packages, keeps the structural
pieces (`ViewState`, `Log`, the DI re-export), drops a placeholder into each
target so SPM still compiles, and resets the app entry point to an empty scene.
Then add your first feature following the slice in *Adding a new feature* below.

> The `make` targets above are the entry points. They wrap helper scripts in
> `scripts/` (`rename.sh`, `scaffold-clean.sh`) — run them via `make`, which
> invokes them from the repo root where they expect to be.

The sections below explain what `make setup` does under the hood, plus a fully
manual path if you'd rather not use the Makefile.

## Creating the Xcode project

The `.xcodeproj` isn't checked in — it's generated from `project.yml` with
[XcodeGen](https://github.com/yonaskolb/XcodeGen). This keeps the project config
readable and out of source control.

### Recommended: XcodeGen

1. Install XcodeGen (once): `brew install xcodegen`
2. From the repo root, run: `xcodegen generate`
3. Open the generated `MyApp.xcodeproj`, then build and run.

`project.yml` references all six local packages and defines a single minimal app
target that links Presentation and DI, sets the iOS 26 deployment target,
enables Swift 6 with complete strict concurrency, and generates the `Info.plist`.
Re-run `xcodegen generate` whenever you change `project.yml`.

### Fallback: create it by hand in Xcode

1. **File → New → Project → iOS App.** Name it `MyApp`, interface SwiftUI,
   language Swift. Save it so `MyApp.xcodeproj` sits next to `App/` and `Packages/`.
2. Delete the default `ContentView.swift` and the generated `App` struct, then
   add `App/MyApp/MyApp.swift` to the target.
3. **File → Add Package Dependencies → Add Local…** and add each of the six
   packages in `Packages/` (Common, Model, Domain, Data, DI, Presentation).
4. App target → **General → Frameworks, Libraries, and Embedded Content** → add
   the **Presentation** and **DI** library products.
5. Set the deployment target to **iOS 26**.
6. Build and run.

> Run each package's tests with `swift test` from inside that package directory
> (e.g. `cd Packages/Domain && swift test`), or via the test targets in Xcode.
> Do **not** add `FactoryKit` to a *test* target — use `FactoryTesting` there
> (wired into the Presentation test target). The Domain tests use no DI framework
> at all — they construct use cases directly with mock repositories.

## Adding a new feature

1. **Model** — add the entity (plain value type).
2. **Domain** — add the repository protocol and a use case.
3. **Data** — implement the protocol, add DTO/mapper.
4. **DI** — add a `FooRegistrations.swift` under `Sources/DI/Registrations/`
   extending `Container` with the feature's keyPaths, binding the Domain
   protocol to the Data implementation.
5. **Presentation** — add a `@MainActor @Observable` ViewModel (inject the use
   case via `@Injected`) and a View that renders its `ViewState`.
6. **Tests** — cover the use case (Domain package) and the ViewModel
   (Presentation package) against mocks.
