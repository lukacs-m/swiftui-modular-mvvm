/// A reusable representation of an async-loaded screen's state.
/// ViewModels expose this so Views can render loading, empty, loaded, and failure
/// uniformly. Lives in Common because it carries no domain knowledge.
public enum ViewState<Value: Sendable>: Sendable {
    case idle
    case loading
    case loaded(Value)
    case empty
    case failed(String)
}

public extension ViewState {
    var value: Value? {
        if case let .loaded(value) = self { return value }
        return nil
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}
