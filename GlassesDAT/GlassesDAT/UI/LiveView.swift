import SwiftUI

struct LiveView: View {
    @Bindable var glasses: GlassesSession

    var body: some View {
        ZStack {
            FrameSurface(image: glasses.frame?.image)
                .ignoresSafeArea()

            VStack {
                HStack {
                    LatencyHUD(milliseconds: glasses.frame?.latencyMs)
                    Spacer()
                    Text(glasses.status)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                Spacer()

                HStack(spacing: 12) {
                    if glasses.stream.isActive {
                        Button("Stop") { glasses.stopStream() }
                            .buttonStyle(DatButtonStyle(kind: .secondary))
                    } else {
                        Button("Start") { glasses.startStream() }
                            .buttonStyle(DatButtonStyle(kind: .primary))
                    }
                    Button("Salir") { glasses.disconnect() }
                        .buttonStyle(DatButtonStyle(kind: .ghost))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
        }
        .background(Color.black)
    }
}
