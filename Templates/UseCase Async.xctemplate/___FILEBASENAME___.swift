//
//  ___FILEHEADER___
//

public protocol ___VARIABLE_productName:identifier___UseCase: Sendable {
    func callAsFunction() async throws
}

public struct ___VARIABLE_productName:identifier___: ___VARIABLE_protocolName___ {

    public init() {}

    // This inherits the caller actor. Use @concurrent for substantial CPU work
    // that must leave that actor; async alone does not move work off MainActor.
    public func callAsFunction() async throws {
        // Implement the use case.
    }
}
