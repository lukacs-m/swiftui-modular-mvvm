import Common
public import Domain
import Foundation
public import Model

/// Concrete implementation of the Domain's ArticleRepository abstraction.
/// This is the only place that knows about transport details and DTO decoding.
///
/// The network call is stubbed with sample data so the scaffold runs out of the box.
/// Replace `loadRawArticles()` with a real URLSession request when wiring an API.
public struct RemoteArticleRepository: ArticleRepository {
    public init() {}

    public func fetchArticles() async throws -> [Article] {
        do {
            let dtos = try await loadRawArticles()
            return dtos.compactMap { $0.toDomain() }
        } catch is URLError {
            Log.error("Article fetch failed: network")
            throw DomainError.network
        } catch {
            Log.error("Article fetch failed: \(error)")
            throw DomainError.unknown
        }
    }

    // MARK: - Stubbed transport

    /// Stand-in for a real network request. Swap for URLSession + JSONDecoder.
    private func loadRawArticles() async throws -> [ArticleDTO] {
        try await Task.sleep(for: .milliseconds(400)) // simulate latency
        return [
            ArticleDTO(
                id: UUID().uuidString,
                title: "Modular SwiftUI Architecture",
                summary: "Why a layered set of packages keeps an app honest.",
                publishedAt: ISO8601DateFormatter().string(from: Date()),
            ),
            ArticleDTO(
                id: UUID().uuidString,
                title: "Dependency Injection with Factory",
                summary: "Compile-time-safe containers for testable, previewable code.",
                publishedAt: ISO8601DateFormatter().string(
                    from: Date().addingTimeInterval(-86400),
                ),
            ),
        ]
    }
}
