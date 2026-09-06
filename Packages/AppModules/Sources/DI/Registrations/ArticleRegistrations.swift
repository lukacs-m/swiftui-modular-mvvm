import Data
public import Domain
public import FactoryKit

public extension Container {
    var articleRepository: Factory<any ArticleRepository> {
        self { SampleArticleRepository() }
    }

    var fetchArticlesUseCase: Factory<any FetchArticlesUseCase> {
        self { FetchArticles(repository: self.articleRepository()) }
    }
}
