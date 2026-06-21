import Foundation
import Model

/// Data Transfer Object — mirrors the wire format, isolated from the domain Model.
/// Keeping DTOs here means a change in the API shape never leaks past the Data layer.
struct ArticleDTO: Decodable {
    let id: String
    let title: String
    let summary: String
    let publishedAt: String
}

extension ArticleDTO {
    /// Maps the wire representation into a clean domain entity.
    func toDomain() -> Article? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        let date = ISO8601DateFormatter().date(from: publishedAt) ?? Date()
        return Article(id: uuid, title: title, summary: summary, publishedAt: date)
    }
}
