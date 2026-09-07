enum DeviceSource: Equatable {
    case metaAI
    case mock
}

enum Session: Equatable {
    case idle
    case registering
    case ready(DeviceSource)
    case connecting
    case live
    case failed(String)

    var source: DeviceSource? {
        switch self {
        case .ready(let source):
            return source
        default:
            return nil
        }
    }

    var showsLive: Bool {
        switch self {
        case .connecting, .live:
            return true
        case .idle, .registering, .ready, .failed:
            return false
        }
    }
}
