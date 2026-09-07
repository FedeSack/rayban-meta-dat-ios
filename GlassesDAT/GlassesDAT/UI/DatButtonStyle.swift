import SwiftUI

struct DatButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
        case ghost
    }

    var kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(foreground)
            .background(background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }

    private var foreground: Color {
        switch kind {
        case .primary:
            return .black
        case .secondary, .ghost:
            return .white
        }
    }

    private var background: Color {
        switch kind {
        case .primary:
            return .white
        case .secondary:
            return Color.white.opacity(0.12)
        case .ghost:
            return Color.white.opacity(0.06)
        }
    }
}
