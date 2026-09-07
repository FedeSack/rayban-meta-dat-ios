import CoreMedia
import Foundation
import QuartzCore

enum Latency {
    static let hostClockMinimumSeconds: Double = 100

    static func milliseconds(
        ptsSeconds: Double?,
        now: CFTimeInterval,
        receivedAt: CFTimeInterval
    ) -> Int {
        if let ptsSeconds, ptsSeconds.isFinite, ptsSeconds > hostClockMinimumSeconds {
            return max(0, Int(((now - ptsSeconds) * 1000).rounded()))
        }
        return max(0, Int(((now - receivedAt) * 1000).rounded()))
    }

    static func milliseconds(sampleBuffer: CMSampleBuffer, receivedAt: CFTimeInterval) -> Int {
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let ptsSeconds: Double? = {
            guard CMTIME_IS_VALID(pts), CMTIME_IS_NUMERIC(pts) else { return nil }
            let seconds = CMTimeGetSeconds(pts)
            return seconds.isFinite ? seconds : nil
        }()
        return milliseconds(ptsSeconds: ptsSeconds, now: CACurrentMediaTime(), receivedAt: receivedAt)
    }
}
