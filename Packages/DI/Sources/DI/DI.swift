// Re-export FactoryKit so any module that imports DI also gets `Container`,
// `@Injected`, `@InjectedObservable`, etc. Presentation imports DI for the
// registration keyPaths and needs nothing else to resolve dependencies.
@_exported import FactoryKit
