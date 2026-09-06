import Foundation
import Testing
import Domain
import Model
@testable import Data

private func dto(id: String = "00000000-0000-0000-0000-000000000001", date: String = "2026-01-02T12:00:00Z") -> ArticleDTO {
    ArticleDTO(id: id, title: "Story", summary: "Summary", publishedAt: date)
}

@Suite struct ArticleRepositoryTests {
    @Test func mapsValidArticle() throws {
        let article = try dto().toDomain()
        #expect(article.id.uuidString == "00000000-0000-0000-0000-000000000001")
        #expect(article.title == "Story")
        #expect(article.publishedAt == Date(timeIntervalSince1970: 1_767_355_200))
    }

    @Test(arguments: ["", "not-a-date", "2026-99-99T12:00:00Z", "2026-02-31T12:00:00Z"])
    func rejectsInvalidDates(date: String) {
        #expect(throws: DomainError.invalidData) { try dto(date: date).toDomain() }
    }

    @Test func rejectsInvalidIdentifier() {
        #expect(throws: DomainError.invalidData) { try dto(id: "invalid").toDomain() }
    }

    @Test func rejectsMixedValidityCollection() async {
        let repository = SampleArticleRepository { [dto(), dto(id: "invalid")] }
        await #expect(throws: DomainError.invalidData) { try await repository.fetchArticles() }
    }

    @Test func preservesCancellation() async {
        let repository = SampleArticleRepository { throw CancellationError() }
        await #expect(throws: CancellationError.self) { try await repository.fetchArticles() }
    }

    @Test func preservesTransportCancellation() async {
        let repository = SampleArticleRepository { throw URLError(.cancelled) }
        await #expect(throws: CancellationError.self) { try await repository.fetchArticles() }
    }

    @Test func mapsNetworkFailure() async {
        let repository = SampleArticleRepository { throw URLError(.notConnectedToInternet) }
        await #expect(throws: DomainError.network) { try await repository.fetchArticles() }
    }

    @Test func mapsUnknownFailure() async {
        struct TestFailure: Error {}
        let repository = SampleArticleRepository { throw TestFailure() }
        await #expect(throws: DomainError.unknown) { try await repository.fetchArticles() }
    }

    @Test func sampleIdentityAndDatesAreStable() async throws {
        let repository = SampleArticleRepository()
        let first = try await repository.fetchArticles()
        let second = try await repository.fetchArticles()
        #expect(first == second)
        #expect(first.count == 2)
    }

    @Test func alreadyCancelledTaskDoesNotLoad() async {
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            let repository = SampleArticleRepository {
                Issue.record("Transport should not start after cancellation")
                return []
            }
            await #expect(throws: CancellationError.self) { try await repository.fetchArticles() }
        }
        await task.value
    }
}
