import SwiftUI

struct DatButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
    }

    var kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DatFont.button(kind == .primary ? .semibold : .medium))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: DatMetrics.buttonHeight)
            .background(background, in: RoundedRectangle(cornerRadius: DatMetrics.buttonRadius, style: .continuous))
            .opacity(configuration.isPressed ? 0.72 : 1)
    }

    private var background: Color {
        switch kind {
        case .primary:
            return DatColor.accent
        case .secondary:
            return DatColor.surface
        }
    }
}
