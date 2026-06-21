import Testing
import Foundation
import DI
import FactoryTesting
@testable import Presentation
import Domain
import Model
import Common

/// Mock use case registered against the container so the ViewModel resolves it.
private struct MockFetchArticles: FetchArticlesUseCase {
    var result: Result<[Article], DomainError>
    func callAsFunction() async throws -> [Article] {
        try result.get()
    }
}

@Suite(.container)
@MainActor
struct ArticleListViewModelTests {

    @Test func loadedStateWhenArticlesReturned() async {
        Container.shared.fetchArticlesUseCase.register {
            MockFetchArticles(result: .success([
                Article(id: UUID(), title: "A", summary: "", publishedAt: Date())
            ]))
        }

        let sut = ArticleListViewModel()
        await sut.reload()

        #expect(sut.state.value?.count == 1)
    }

    @Test func emptyStateWhenNoArticles() async {
        Container.shared.fetchArticlesUseCase.register {
            MockFetchArticles(result: .success([]))
        }

        let sut = ArticleListViewModel()
        await sut.reload()

        if case .empty = sut.state {} else {
            Issue.record("Expected .empty, got \(sut.state)")
        }
    }

    @Test func failedStateOnError() async {
        Container.shared.fetchArticlesUseCase.register {
            MockFetchArticles(result: .failure(.network))
        }

        let sut = ArticleListViewModel()
        await sut.reload()

        if case .failed = sut.state {} else {
            Issue.record("Expected .failed, got \(sut.state)")
        }
    }
}
