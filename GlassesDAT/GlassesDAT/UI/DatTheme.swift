import SwiftUI

enum DatColor {
    static let background = Color("DatBackground")
    static let surface = Color("DatSurface")
    static let accent = Color("DatAccent")
    static let secondary = Color("DatSecondary")
    static let success = Color("DatSuccess")
    static let danger = Color("DatDanger")
    static let latencyFill = Color.black.opacity(0.72)
    static let placeholder = Color.white.opacity(0.35)
}

enum DatMetrics {
    static let safeTop: CGFloat = 59
    static let safeBottom: CGFloat = 34
    static let horizontalPad: CGFloat = 24
    static let headerTop: CGFloat = 24
    static let headerGap: CGFloat = 16
    static let chipPadV: CGFloat = 8
    static let chipPadH: CGFloat = 14
    static let chipRadius: CGFloat = 20
    static let chipDot: CGFloat = 8
    static let chipGap: CGFloat = 8
    static let titleSize: CGFloat = 28
    static let titleLine: CGFloat = 34
    static let titleTracking: CGFloat = -0.14
    static let subtitleSize: CGFloat = 15
    static let subtitleLine: CGFloat = 22
    static let chipLabelSize: CGFloat = 13
    static let buttonHeight: CGFloat = 52
    static let buttonRadius: CGFloat = 14
    static let buttonGap: CGFloat = 12
    static let buttonLabelSize: CGFloat = 17
    static let ctaBottom: CGFloat = 16
    static let latencyTop: CGFloat = 67
    static let latencyRadius: CGFloat = 10
    static let latencyPadV: CGFloat = 8
    static let latencyPadH: CGFloat = 12
    static let liveButtonWidth: CGFloat = 345
}

enum DatFont {
    static func title() -> Font {
        .system(size: DatMetrics.titleSize, weight: .semibold)
    }

    static func subtitle() -> Font {
        .system(size: DatMetrics.subtitleSize, weight: .regular)
    }

    static func chip() -> Font {
        .system(size: DatMetrics.chipLabelSize, weight: .medium)
    }

    static func button(_ weight: Font.Weight) -> Font {
        .system(size: DatMetrics.buttonLabelSize, weight: weight)
    }

    static func latency() -> Font {
        .system(size: 15, weight: .semibold)
    }

    static func placeholder() -> Font {
        .system(size: 13, weight: .medium)
    }
}
