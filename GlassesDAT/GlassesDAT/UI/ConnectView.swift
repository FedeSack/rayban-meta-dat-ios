import SwiftUI

struct ConnectView: View {
    @Bindable var glasses: GlassesSession

    private var isConnected: Bool {
        if case .ready = glasses.session { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, DatMetrics.headerTop)
            Spacer(minLength: 0)
            ctaStack
                .padding(.bottom, DatMetrics.ctaBottom)
        }
        .padding(.horizontal, DatMetrics.horizontalPad)
        .padding(.top, DatMetrics.safeTop)
        .padding(.bottom, DatMetrics.safeBottom)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DatColor.background.ignoresSafeArea())
    }

    private var header: some View {
        VStack(spacing: DatMetrics.headerGap) {
            StatusChip(connected: isConnected)
            Text("Ray-Ban Meta")
                .font(DatFont.title())
                .tracking(DatMetrics.titleTracking)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: DatMetrics.titleLine)
            Text("Stream your Ray-Ban Meta camera via Meta Wearables Device Access Toolkit.")
                .font(DatFont.subtitle())
                .foregroundStyle(DatColor.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .lineSpacing(DatMetrics.subtitleLine - DatMetrics.subtitleSize)
        }
        .frame(maxWidth: .infinity)
    }

    private var ctaStack: some View {
        VStack(spacing: DatMetrics.buttonGap) {
            Button("Connect with Meta AI") {
                tapMetaAI()
            }
            .buttonStyle(DatButtonStyle(kind: .primary))
            .disabled(glasses.session == .registering)

            Button("Use Mock Device") {
                tapMock()
            }
            .buttonStyle(DatButtonStyle(kind: .secondary))
            .disabled(glasses.session == .registering)

            if case .failed(let message) = glasses.session {
                Text(message)
                    .font(DatFont.subtitle())
                    .foregroundStyle(DatColor.danger)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func tapMetaAI() {
        if case .ready(.metaAI) = glasses.session {
            glasses.startStream()
            return
        }
        glasses.registerWithMetaAI()
    }

    private func tapMock() {
        if case .ready(.mock) = glasses.session {
            glasses.startStream()
            return
        }
        glasses.connectMock()
    }
}

struct StatusChip: View {
    var connected: Bool

    var body: some View {
        HStack(spacing: DatMetrics.chipGap) {
            Circle()
                .fill(connected ? DatColor.success : DatColor.danger)
                .frame(width: DatMetrics.chipDot, height: DatMetrics.chipDot)
            Text(connected ? "Connected" : "Disconnected")
                .font(DatFont.chip())
                .foregroundStyle(.white)
        }
        .padding(.horizontal, DatMetrics.chipPadH)
        .padding(.vertical, DatMetrics.chipPadV)
        .background(DatColor.surface, in: RoundedRectangle(cornerRadius: DatMetrics.chipRadius, style: .continuous))
    }
}
