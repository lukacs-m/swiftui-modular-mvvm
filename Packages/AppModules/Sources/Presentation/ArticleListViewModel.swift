import DI
import Domain
public import Foundation
public import Model
public import Observation

@MainActor
@Observable
public final class ArticleListViewModel {
    public private(set) var state: ViewState<[Article]> = .idle
    public private(set) var isLoading = false
    public private(set) var refreshError: LocalizedStringResource?

    @ObservationIgnored
    @Injected(\.fetchArticlesUseCase) private var fetchArticles

    public init() {}

    public func onAppear() async {
        guard case .idle = state else { return }
        await reload()
    }

    public func reload() async {
        guard !isLoading else { return }
        let previousState = state
        isLoading = true
        refreshError = nil
        // Preserve the List and its refresh control throughout a refresh.
        if case .loaded = state {} else { state = .loading }
        defer { isLoading = false }

        do {
            try Task.checkCancellation()
            let articles = try await fetchArticles()
            try Task.checkCancellation()
            state = articles.isEmpty ? .empty : .loaded(articles)
        } catch is CancellationError {
            state = previousState
        } catch {
            let message = message(for: error as? DomainError ?? .unknown)
            if case .loaded = previousState {
                state = previousState
                refreshError = message
            } else {
                state = .failed(message)
            }
        }
    }

    private func message(for error: DomainError) -> LocalizedStringResource {
        let key: String.LocalizationValue = switch error {
        case .network: "No connection. Check your network and retry."
        case .notFound: "Nothing here yet."
        case .invalidData: "The articles could not be read. Please retry."
        case .unknown: "Something went wrong. Please retry."
        }
        return LocalizedStringResource(key, bundle: .atURL(Bundle.module.bundleURL))
    }
}
