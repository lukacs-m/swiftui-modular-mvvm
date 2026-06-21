import Testing
import Foundation
@testable import Domain
import Model

/// A mock conforming to the Domain protocol — drives loaded, empty, and error paths.
private struct MockArticleRepository: ArticleRepository {
    var result: Result<[Article], DomainError>
    func fetchArticles() async throws -> [Article] {
        try result.get()
    }
}

private func makeArticle(daysAgo: Int, title: String) -> Article {
    Article(
        id: UUID(),
        title: title,
        summary: "",
        publishedAt: Date().addingTimeInterval(TimeInterval(-86_400 * daysAgo))
    )
}

@Suite
struct FetchArticlesTests {

    @Test func sortsByPublishedDateDescending() async throws {
        let older = makeArticle(daysAgo: 2, title: "Older")
        let newer = makeArticle(daysAgo: 0, title: "Newer")
        let repo = MockArticleRepository(result: .success([older, newer]))

        let useCase = FetchArticles(repository: repo)
        let result = try await useCase()

        #expect(result.map(\.title) == ["Newer", "Older"])
    }

    @Test func propagatesNetworkError() async {
        let repo = MockArticleRepository(result: .failure(.network))
        let useCase = FetchArticles(repository: repo)

        await #expect(throws: DomainError.network) {
            _ = try await useCase()
        }
    }
}
