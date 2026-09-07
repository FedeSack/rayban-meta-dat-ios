import SwiftUI

struct RootView: View {
    @Bindable var glasses: GlassesSession

    var body: some View {
        Group {
            if glasses.session.showsLive {
                LiveView(glasses: glasses)
            } else {
                ConnectView(glasses: glasses)
            }
        }
        .preferredColorScheme(.dark)
        .background(DatColor.background.ignoresSafeArea())
    }
}
