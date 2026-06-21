//
//  ___FILEHEADER___
//

public import Observation
import DI
import Common

@Observable
@MainActor
public final class ___VARIABLE_sceneName:identifier___ViewModel {

    // Replace `Void` with the model type this screen loads (e.g. ViewState<[Item]>).
    private(set) var state: ViewState<Void> = .idle

    // Inject use cases from the DI container, e.g.:
    // @ObservationIgnored @Injected(\.someUseCase) private var someUseCase

    public init() {}
}
