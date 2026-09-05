import DI
import Domain
import FactoryTesting
import Foundation
import Model
import Testing
@testable import Presentation

private actor ControlledFetch: FetchArticlesUseCase {
    let started: AsyncStream<Void>
    private let signal: AsyncStream<Void>.Continuation
    private var pending: CheckedContinuation<[Article], any Error>?
    private(set) var calls = 0

    init() {
        let pair = AsyncStream<Void>.makeStream()
        started = pair.stream
        signal = pair.continuation
    }

    func callAsFunction() async throws -> [Article] {
        calls += 1
        return try await withCheckedThrowingContinuation {
            pending = $0
            signal.yield(())
        }
    }

    func complete(_ result: Result<[Article], any Error>) {
        let continuation = pending
        pending = nil
        continuation?.resume(with: result)
    }
}

@Suite(.container, .timeLimit(.minutes(1)))
@MainActor
struct ArticleLifecycleTests {
    private let articles = [Article(
        id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)),
        title: "Story", summary: "", publishedAt: Date(timeIntervalSince1970: 1_767_355_200)
    )]

    @Test func initialLoadIsSingleFlightAndDoesNotRepeatOnAppearance() async {
        let fetch = ControlledFetch()
        Container.shared.fetchArticlesUseCase.register { fetch }
        var starts = fetch.started.makeAsyncIterator()
        let vm = ArticleListViewModel()
        let first = Task { await vm.onAppear() }
        await starts.next()
        #expect(vm.state.isLoading)
        #expect(vm.isLoading)
        await vm.reload()
        await vm.onAppear()
        #expect(await fetch.calls == 1)
        await fetch.complete(.success(articles))
        await first.value
        await vm.onAppear()
        #expect(await fetch.calls == 1)
        #expect(vm.state.value == articles)
        #expect(!vm.isLoading)
    }

    @Test func cancelledInitialLoadCanLoadOnReappearance() async {
        let fetch = ControlledFetch()
        Container.shared.fetchArticlesUseCase.register { fetch }
        var starts = fetch.started.makeAsyncIterator()
        let vm = ArticleListViewModel()
        let first = Task { await vm.onAppear() }
        await starts.next()
        first.cancel()
        // A transport may still return successfully after its caller is cancelled.
        await fetch.complete(.success(articles))
        await first.value
        if case .idle = vm.state {} else { Issue.record("Cancellation must restore idle") }
        let second = Task { await vm.onAppear() }
        await starts.next()
        await fetch.complete(.success(articles))
        await second.value
        #expect(vm.state.value == articles)
        #expect(await fetch.calls == 2)
    }

    @Test func refreshFailurePreservesContentAndRetryClearsError() async {
        let fetch = ControlledFetch()
        Container.shared.fetchArticlesUseCase.register { fetch }
        var starts = fetch.started.makeAsyncIterator()
        let vm = ArticleListViewModel()
        let initial = Task { await vm.onAppear() }
        await starts.next()
        await fetch.complete(.success(articles))
        await initial.value
        let refresh = Task { await vm.reload() }
        await starts.next()
        #expect(vm.state.value == articles)
        await fetch.complete(.failure(DomainError.network))
        await refresh.value
        #expect(vm.state.value == articles)
        #expect(vm.refreshError != nil)
        let retry = Task { await vm.reload() }
        await starts.next()
        #expect(vm.refreshError == nil)
        await fetch.complete(.success([]))
        await retry.value
        if case .empty = vm.state {} else { Issue.record("Expected empty after retry") }
    }

    @Test func cancelledRefreshPreservesContent() async {
        let fetch = ControlledFetch()
        Container.shared.fetchArticlesUseCase.register { fetch }
        var starts = fetch.started.makeAsyncIterator()
        let vm = ArticleListViewModel()
        let initial = Task { await vm.onAppear() }
        await starts.next()
        await fetch.complete(.success(articles))
        await initial.value
        let refresh = Task { await vm.reload() }
        await starts.next()
        await fetch.complete(.failure(CancellationError()))
        await refresh.value
        #expect(vm.state.value == articles)
        #expect(vm.refreshError == nil)
        #expect(!vm.isLoading)
    }

    @Test func retryAfterFailureShowsLoading() async {
        let fetch = ControlledFetch()
        Container.shared.fetchArticlesUseCase.register { fetch }
        var starts = fetch.started.makeAsyncIterator()
        let vm = ArticleListViewModel()
        let initial = Task { await vm.onAppear() }
        await starts.next()
        await fetch.complete(.failure(DomainError.invalidData))
        await initial.value
        if case .failed = vm.state {} else { Issue.record("Expected failure") }
        let retry = Task { await vm.reload() }
        await starts.next()
        #expect(vm.state.isLoading)
        await fetch.complete(.success(articles))
        await retry.value
        #expect(vm.state.value == articles)
    }
}
