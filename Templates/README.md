# Xcode File Templates

Xcode "New File…" templates that generate scaffold-conforming code: a SwiftUI
View + ViewModel pair, and async/sync UseCases. They follow the project's
conventions out of the box — `public` access, `public import` where types cross
the module boundary, `@Observable @MainActor` view models, and the `callAsFunction`
use-case style.

## Installing

```
make install-templates
```

This symlinks the bundles into `~/Library/Developer/Xcode/Templates/MVVM Scaffold/`
(symlinked, so edits to these files take effect immediately — no reinstall).
Restart Xcode if it was open, then **File → New → File… → MVVM Scaffold**.

Remove them with `make uninstall-templates`.

## The templates

| Template | Generates | Layer | Prompts for |
|---|---|---|---|
| **MVVM** | `<Scene>View.swift` + `<Scene>ViewModel.swift` | Presentation | Scene name |
| **UseCase Async** | `<Name>UseCase` protocol + `<Name>` struct (`async throws`) | Domain | UseCase name, protocol name |
| **UseCase Sync** | `<Name>UseCase` protocol + `<Name>` struct (`throws`) | Domain | UseCase name, protocol name |

All three set `SupportsSwiftPackage`, so they work when you create a file inside a
package target. The async UseCase includes a commented `@concurrent` example
explaining when to force work off the caller's actor onto a background thread.

## After generating

These templates produce a single layer's files. A full feature still spans the
stack, so after generating:

- **UseCase** (Domain) → add the concrete repository in **Data**, then register
  both in **DI** (`Packages/DI/Sources/DI/Registrations/`).
- **MVVM** (Presentation) → inject the use case into the view model via
  `@ObservationIgnored @Injected(\.someUseCase)` and render the `ViewState`.

See the "Implementing a feature" section in `AGENTS.md` for the full slice.

## A note on the MVVM naming

The MVVM template asks for a **Scene Name** as an option rather than deriving it
from the file name. This is deliberate: Xcode's `___FILEBASENAME___` resolves to
the full file name, so a file named `ProfileView.swift` would expand
`___FILEBASENAME___ViewModel` to `ProfileViewViewModel`. Using a named option
avoids that and keeps `ProfileView` / `ProfileViewModel` correct.
