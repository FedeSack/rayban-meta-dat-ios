import MWDATCore
import SwiftUI

@main
struct GlassesDATApp: App {
    @State private var glasses = GlassesSession()

    init() {
        do {
            try Wearables.configure()
        } catch {
            assertionFailure("Wearables.configure failed: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(glasses: glasses)
                .onOpenURL { url in
                    glasses.handleOpenURL(url)
                }
        }
    }
}
