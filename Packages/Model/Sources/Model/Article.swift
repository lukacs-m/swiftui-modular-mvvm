public import Foundation

/// A domain entity. Plain value type with no logic and no dependencies beyond Common.
public struct Article: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let summary: String
    public let publishedAt: Date

    public init(
        id: UUID,
        title: String,
        summary: String,
        publishedAt: Date
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.publishedAt = publishedAt
    }
}
