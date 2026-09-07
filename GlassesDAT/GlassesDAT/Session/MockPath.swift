import Foundation
import MWDATMockDevice

enum MockPath {
    @discardableResult
    static func enableAndPair(feedURL: URL?) throws -> MockGlasses {
        let kit = MockDeviceKit.shared
        kit.enable(config: MockDeviceKitConfig(initiallyRegistered: true))
        let glasses = try kit.pairGlasses(model: .rayBanMeta)
        glasses.powerOn()
        glasses.unfold()
        glasses.don()
        if let feedURL {
            glasses.services.camera.setCameraFeed(fileURL: feedURL)
        }
        return glasses
    }

    static func disable() {
        MockDeviceKit.shared.disable()
    }
}
