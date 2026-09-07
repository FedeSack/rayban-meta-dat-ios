import UIKit

enum Stream: Equatable {
    case stopped
    case starting
    case waitingForDevice
    case streaming
    case paused
    case stopping

    var isActive: Bool {
        switch self {
        case .streaming, .paused, .starting, .waitingForDevice, .stopping:
            return true
        case .stopped:
            return false
        }
    }
}

struct PreviewFrame {
    let image: UIImage
    let latencyMs: Int
}
