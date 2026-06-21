public import Model

/// A use case orchestrates domain logic on top of repository protocols.
/// Here it fetches and sorts; real apps add filtering, validation, policy, etc.
public protocol FetchArticlesUseCase: Sendable {
    func callAsFunction() async throws -> [Article]
}

public struct FetchArticles: FetchArticlesUseCase {
    private let repository: any ArticleRepository

    public init(repository: any ArticleRepository) {
        self.repository = repository
    }

    public func callAsFunction() async throws -> [Article] {
        let articles = try await repository.fetchArticles()
        return articles.sorted { $0.publishedAt > $1.publishedAt }
    }
}
