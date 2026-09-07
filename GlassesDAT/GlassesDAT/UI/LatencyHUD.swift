import SwiftUI

struct LatencyHUD: View {
    let milliseconds: Int?

    var body: some View {
        Text(label)
            .font(.system(size: 15, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.black.opacity(0.72), in: Capsule())
    }

    private var label: String {
        guard let milliseconds else { return "-- ms" }
        return "\(milliseconds) ms"
    }
}
