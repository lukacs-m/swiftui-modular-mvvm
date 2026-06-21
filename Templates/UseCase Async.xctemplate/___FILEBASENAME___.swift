//
//  ___FILEHEADER___
//

public protocol ___VARIABLE_productName:identifier___UseCase: Sendable {
    func callAsFunction() async throws
}

public struct ___VARIABLE_productName:identifier___: ___VARIABLE_protocolName___ {

    public init() {}

    // With NonisolatedNonsendingByDefault, this async function runs on the
    // CALLER's actor by default (e.g. the MainActor when called from a view
    // model). If it does heavy work that must run off the main thread, mark it
    // `@concurrent` to force it onto the global executor (a background thread):
    //
    //     @concurrent
    //     public func callAsFunction() async throws { ... }
    //
    public func callAsFunction() async throws {
        // Implement the use case.
    }
}
