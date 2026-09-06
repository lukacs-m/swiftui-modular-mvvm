import Foundation
import Model
public import SwiftUI

public struct ArticleListView: View {
    @State private var viewModel = ArticleListViewModel()
    @State private var reloadID = 0

    public init() {}

    public var body: some View {
        ArticleListContent(
            state: viewModel.state,
            refreshError: viewModel.refreshError,
            retry: { reloadID += 1 },
            refresh: { await viewModel.reload() },
        )
        .task(id: reloadID) {
            if reloadID == 0 {
                await viewModel.onAppear()
            } else {
                await viewModel.reload()
            }
        }
    }
}

private struct ArticleListContent: View {
    let state: ViewState<[Article]>
    var refreshError: LocalizedStringResource?
    var retry: () -> Void = {}
    var refresh: () async -> Void = {}

    var body: some View {
        NavigationStack {
            // Keep the title attached when switching to an unavailable-content view.
            VStack(spacing: 0) { content }
                .navigationTitle(Text("Articles", bundle: .module))
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .idle, .loading:
            ProgressView {
                Text("Loading…", bundle: .module)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case let .loaded(articles):
            List(articles) { article in
                ArticleRow(article: article)
            }
            .listStyle(.plain)
            .refreshable { await refresh() }
            .safeAreaInset(edge: .top) {
                if let refreshError {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(refreshError)
                        Button(action: retry) { Text("Retry", bundle: .module) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.regularMaterial)
                }
            }

        case .empty:
            ContentUnavailableView {
                Label { Text("No Articles", bundle: .module) } icon: {
                    Image(systemName: "doc.text")
                }
            } description: {
                Text("Check back later for new stories.", bundle: .module)
            } actions: {
                Button(action: retry) { Text("Reload", bundle: .module) }
            }

        case let .failed(message):
            ContentUnavailableView {
                Label { Text("Couldn't Load", bundle: .module) } icon: {
                    Image(systemName: "exclamationmark.triangle")
                }
            } description: {
                Text(message)
            } actions: {
                Button(action: retry) { Text("Retry", bundle: .module) }
            }
        }
    }
}

private struct ArticleRow: View {
    let article: Article

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: article.title)
                .font(.headline)
            Text(verbatim: article.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(article.publishedAt, format: .dateTime.day().month().year())
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
    private let previewArticles = [
        Article(
            id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)),
            title: "First Story",
            summary: "A short summary that remains readable at larger text sizes.",
            publishedAt: Date(timeIntervalSince1970: 1_767_355_200),
        ),
    ]

    #Preview("Loaded") { ArticleListContent(state: .loaded(previewArticles)) }
    #Preview("Empty") { ArticleListContent(state: .empty) }
    #Preview("Loading") { ArticleListContent(state: .loading) }
    #Preview("Failed") {
        ArticleListContent(state: .failed(LocalizedStringResource(
            "No connection. Check your network and retry.", bundle: .atURL(Bundle.module.bundleURL),
        )))
    }

    #Preview("Refresh failed - large text") {
        ArticleListContent(
            state: .loaded(previewArticles),
            refreshError: LocalizedStringResource(
                "No connection. Check your network and retry.",
                bundle: .atURL(Bundle.module.bundleURL),
            ),
        )
        .environment(\.dynamicTypeSize, .accessibility3)
    }

    #Preview("Right to left") {
        ArticleListContent(state: .loaded(previewArticles))
            .environment(\.layoutDirection, .rightToLeft)
    }

    #Preview("French") {
        ArticleListContent(state: .empty)
            .environment(\.locale, Locale(identifier: "fr"))
    }
#endif
