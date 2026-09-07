import SwiftUI

struct LatencyHUD: View {
    let milliseconds: Int?

    var body: some View {
        Text(label)
            .font(DatFont.latency())
            .foregroundStyle(.white)
            .padding(.horizontal, DatMetrics.latencyPadH)
            .padding(.vertical, DatMetrics.latencyPadV)
            .background(DatColor.latencyFill, in: RoundedRectangle(cornerRadius: DatMetrics.latencyRadius, style: .continuous))
    }

    private var label: String {
        guard let milliseconds else { return "-- ms" }
        return "\(milliseconds) ms"
    }
}
