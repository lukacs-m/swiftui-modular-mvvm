import Presentation
import SwiftUI

/// The entire app target. All logic and UI live in the layer packages
/// (Common / Model / Domain / Data / Presentation); this file only declares the
/// entry point and hands off to the Presentation layer's root view.
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ArticleListView()
        }
    }
}
