import Data
public import Domain
public import FactoryKit

/// Article-feature dependency registrations.
///
/// One file per feature keeps the composition root navigable as the app grows —
/// add `ProfileRegistrations.swift`, `SettingsRegistrations.swift`, etc. alongside
/// this one, each extending `Container` with that feature's keyPaths.
public extension Container {
    /// Repository abstraction (Domain) bound to its concrete implementation (Data).
    var articleRepository: Factory<any ArticleRepository> {
        self { RemoteArticleRepository() }
    }

    /// Use case, wired to resolve its repository from the container.
    var fetchArticlesUseCase: Factory<any FetchArticlesUseCase> {
        self { FetchArticles(repository: self.articleRepository()) }
    }
}
