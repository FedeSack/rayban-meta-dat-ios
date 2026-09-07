import SwiftUI

struct ConnectView: View {
    @Bindable var glasses: GlassesSession

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 8) {
                Text("DAT")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
                Text("Cámara de las gafas")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                Text(glasses.status)
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.6))
            }

            VStack(spacing: 12) {
                Button("Registrar con Meta AI") {
                    glasses.registerWithMetaAI()
                }
                .buttonStyle(DatButtonStyle(kind: .primary))
                .disabled(glasses.session == .registering)

                Button("Mock Device") {
                    glasses.connectMock()
                }
                .buttonStyle(DatButtonStyle(kind: .secondary))
                .disabled(glasses.session == .registering)
            }

            if case .failed(let message) = glasses.session {
                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(Color(red: 1, green: 0.45, blue: 0.4))
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.black)
    }
}
