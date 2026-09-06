public import Model

public protocol ArticleRepository: Sendable {
    func fetchArticles() async throws -> [Article]
}
