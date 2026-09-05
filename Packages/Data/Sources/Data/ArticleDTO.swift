import Domain
import Foundation
import Model

struct ArticleDTO: Decodable, Sendable {
    let id: String
    let title: String
    let summary: String
    let publishedAt: String

    func toDomain() throws -> Article {
        guard let uuid = UUID(uuidString: id) else { throw DomainError.invalidData }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        // ISO8601DateFormatter normalizes impossible dates instead of rejecting them.
        formatter.isLenient = false
        guard let date = formatter.date(from: publishedAt) else { throw DomainError.invalidData }
        return Article(id: uuid, title: title, summary: summary, publishedAt: date)
    }
}
