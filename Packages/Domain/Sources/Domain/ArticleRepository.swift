public import Model

/// Domain-level error vocabulary. The Data layer maps low-level failures
/// (URLError, decoding errors) into these before they cross the boundary.
public enum DomainError: Error, Equatable, Sendable {
    case network
    case notFound
    case unknown
}

/// The abstraction the Domain owns. Data provides the concrete implementation;
/// Presentation depends only on this protocol, never on the implementation.
public protocol ArticleRepository: Sendable {
    func fetchArticles() async throws -> [Article]
}
