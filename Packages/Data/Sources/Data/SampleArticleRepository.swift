import Common
public import Domain
import Foundation
public import Model
import os

/// Offline sample transport. Replace its DI registration when adding a real API.
public struct SampleArticleRepository: ArticleRepository {
    private let load: @Sendable () async throws -> [ArticleDTO]

    public init() {
        load = Self.loadSampleArticles
    }

    init(load: @escaping @Sendable () async throws -> [ArticleDTO]) {
        self.load = load
    }

    public func fetchArticles() async throws -> [Article] {
        do {
            try Task.checkCancellation()
            let dtos = try await load()
            try Task.checkCancellation()
            return try dtos.map { try $0.toDomain() }
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch is URLError {
            Log.data.error("Article fetch failed: network")
            throw DomainError.network
        } catch let error as DomainError {
            throw error
        } catch {
            Log.data.error("Article fetch failed: \(String(describing: error))")
            throw DomainError.unknown
        }
    }

    private static func loadSampleArticles() async throws -> [ArticleDTO] {
        // Keep enough latency to demonstrate loading and cancellation in the sample UI.
        try await Task.sleep(for: .milliseconds(400))
        return [
            ArticleDTO(
                id: "00000000-0000-0000-0000-000000000001",
                title: "Modular SwiftUI Architecture",
                summary: "Why a layered set of packages keeps an app honest.",
                publishedAt: "2026-01-02T12:00:00Z",
            ),
            ArticleDTO(
                id: "00000000-0000-0000-0000-000000000002",
                title: "Dependency Injection with Factory",
                summary: "Compile-time-safe containers for testable, previewable code.",
                publishedAt: "2026-01-01T12:00:00Z",
            ),
        ]
    }
}
