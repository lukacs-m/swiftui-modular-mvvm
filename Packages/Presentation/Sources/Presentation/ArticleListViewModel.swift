public import Observation
import DI
public import Model
import Domain
public import Common

/// ViewModel for the article list. `@MainActor @Observable` so SwiftUI observes
/// its mutations on the main thread. It injects the *use case protocol* — it has
/// no knowledge of the repository, network, or any Data type.
@MainActor
@Observable
public final class ArticleListViewModel {

    public private(set) var state: ViewState<[Article]> = .idle

    @ObservationIgnored
    @Injected(\.fetchArticlesUseCase) private var fetchArticles

    public init() {}

    public func onAppear() async {
        // Only load on first appearance; the .task can re-fire on view identity
        // changes, and we don't want to refetch if we already have content.
        guard case .idle = state else { return }
        await load(showLoading: true)
    }

    public func reload() async {
        // Pull-to-refresh provides its own spinner, so don't switch to the
        // full-screen .loading state — that would tear down the List (and its
        // refresh control) mid-gesture. Keep current content until new data lands.
        await load(showLoading: false)
    }

    private func load(showLoading: Bool) async {
        if showLoading { state = .loading }
        do {
            let articles = try await fetchArticles()
            state = articles.isEmpty ? .empty : .loaded(articles)
        } catch let error as DomainError {
            state = .failed(message(for: error))
        } catch {
            state = .failed("Something went wrong. Pull to retry.")
        }
    }

    private func message(for error: DomainError) -> String {
        switch error {
        case .network: "No connection. Check your network and retry."
        case .notFound: "Nothing here yet."
        case .unknown: "Something went wrong. Pull to retry."
        }
    }
}
