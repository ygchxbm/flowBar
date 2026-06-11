import XCTest
@testable import FlowBar

final class FlowBarScaffoldTests: XCTestCase {
    func testUnavailableMetricsSnapshot() {
        XCTAssertNil(MetricsSnapshot.unavailable.downloadBytesPerSecond)
        XCTAssertEqual(MetricsSnapshot.unavailable.battery.powerState, .unknown)
    }
}
