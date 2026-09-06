/// Operational failures shared by repository contracts. Cancellation propagates separately.
public enum DomainError: Error, Equatable, Sendable {
    case network
    case notFound
    case invalidData
    case unknown
}
