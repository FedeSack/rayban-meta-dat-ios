import XCTest
@testable import GlassesDAT

final class LatencyTests: XCTestCase {
    func testHostClockPTSUsesCaptureToNow() {
        let ms = Latency.milliseconds(ptsSeconds: 1000, now: 1000.250, receivedAt: 1000.249)
        XCTAssertEqual(ms, 250)
    }

    func testMediaTimelinePTSFallsBackToReceiveToNow() {
        let ms = Latency.milliseconds(ptsSeconds: 0.04, now: 12.020, receivedAt: 12.001)
        XCTAssertEqual(ms, 19)
    }

    func testMissingPTSFallsBackToReceiveToNow() {
        let ms = Latency.milliseconds(ptsSeconds: nil, now: 5.010, receivedAt: 5.000)
        XCTAssertEqual(ms, 10)
    }

    func testNegativeDeltaClampsToZero() {
        let ms = Latency.milliseconds(ptsSeconds: 2000, now: 1999.5, receivedAt: 1999.4)
        XCTAssertEqual(ms, 0)
    }
}
