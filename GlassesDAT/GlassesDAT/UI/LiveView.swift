import SwiftUI

struct LiveView: View {
    @Bindable var glasses: GlassesSession

    var body: some View {
        ZStack {
            videoStage
            latencyBadge
            startControl
        }
        .background(DatColor.background.ignoresSafeArea())
    }

    @ViewBuilder
    private var videoStage: some View {
        if glasses.frame?.image != nil {
            FrameSurface(image: glasses.frame?.image)
                .ignoresSafeArea()
        } else {
            LinearGradient(
                stops: [
                    .init(color: Color(red: 15 / 255, green: 20 / 255, blue: 31 / 255), location: 0),
                    .init(color: Color(red: 31 / 255, green: 41 / 255, blue: 56 / 255), location: 0.45),
                    .init(color: Color(red: 8 / 255, green: 10 / 255, blue: 13 / 255), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            Text("Glasses camera POV")
                .font(DatFont.placeholder())
                .foregroundStyle(DatColor.placeholder)
        }
    }

    private var latencyBadge: some View {
        VStack {
            HStack {
                LatencyHUD(milliseconds: glasses.frame?.latencyMs)
                Spacer()
            }
            .padding(.leading, DatMetrics.horizontalPad)
            .padding(.top, DatMetrics.latencyTop)
            Spacer()
        }
    }

    private var startControl: some View {
        VStack {
            Spacer()
            Button(glasses.stream.isActive ? "Stop" : "Start") {
                if glasses.stream.isActive {
                    glasses.stopStream()
                } else {
                    glasses.startStream()
                }
            }
            .buttonStyle(DatButtonStyle(kind: .primary))
            .frame(width: DatMetrics.liveButtonWidth, height: DatMetrics.buttonHeight)
            .padding(.bottom, DatMetrics.safeBottom)
        }
    }
}
