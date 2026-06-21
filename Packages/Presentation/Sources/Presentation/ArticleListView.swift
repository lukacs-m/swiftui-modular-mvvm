public import SwiftUI
import DI
import Model
import Domain
import Common

/// The article list screen. The View is dumb: it renders ViewModel state and
/// forwards intent. No business logic lives in `body`.
public struct ArticleListView: View {
    @State private var viewModel = ArticleListViewModel()

    public init() {}

    public var body: some View {
        NavigationStack {
            content
                .navigationTitle("Articles")
        }
        .task { await viewModel.onAppear() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView("Loading…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case let .loaded(articles):
            List(articles) { article in
                ArticleRow(article: article)
            }
            .listStyle(.plain)
            .refreshable { await viewModel.reload() }

        case .empty:
            ContentUnavailableView(
                "No Articles",
                systemImage: "doc.text",
                description: Text("Check back later for new stories.")
            )

        case let .failed(message):
            ContentUnavailableView {
                Label("Couldn't Load", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Retry") { Task { await viewModel.reload() } }
            }
        }
    }
}

/// A small, focused subview — extracted to keep `body` readable and limit redraws.
private struct ArticleRow: View {
    let article: Article

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(article.title)
                .font(.headline)
            Text(article.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(article.publishedAt, format: .dateTime.day().month().year())
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Previews

/// A mock repository so previews never hit the network. Lives in the preview
/// block so it isn't compiled into the shipping app.
private struct PreviewArticleRepository: ArticleRepository {
    let articles: [Article]
    func fetchArticles() async throws -> [Article] { articles }
}

#Preview("Loaded") {
    let _ = Container.shared.articleRepository.preview {
        PreviewArticleRepository(articles: [
            Article(id: UUID(), title: "First Story",
                    summary: "A short summary.", publishedAt: Date()),
            Article(id: UUID(), title: "Second Story",
                    summary: "Another summary.",
                    publishedAt: Date().addingTimeInterval(-86_400)),
        ])
    }
    ArticleListView()
}

#Preview("Empty") {
    let _ = Container.shared.articleRepository.preview {
        PreviewArticleRepository(articles: [])
    }
    ArticleListView()
}
