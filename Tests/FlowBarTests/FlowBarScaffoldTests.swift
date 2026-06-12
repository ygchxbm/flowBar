import XCTest
@testable import FlowBar

final class FlowBarScaffoldTests: XCTestCase {
    func testUnavailableMetricsSnapshot() {
        XCTAssertNil(MetricsSnapshot.unavailable.downloadBytesPerSecond)
        XCTAssertEqual(MetricsSnapshot.unavailable.battery.powerState, .unknown)
    }

    func testBuildScriptSignsAppBundleAfterPackaging() throws {
        let script = try String(contentsOfFile: "Scripts/build-app.sh", encoding: .utf8)

        XCTAssertTrue(script.contains("codesign --force --deep --sign - \"$APP_DIR\""))
    }

    func testCursorTrackingViewDoesNotInterceptQuitButtonClicks() throws {
        let source = try String(contentsOfFile: "Sources/FlowBar/App/BatteryPopoverViewController.swift", encoding: .utf8)

        XCTAssertTrue(source.contains("override func hitTest(_ point: NSPoint) -> NSView?"))
        XCTAssertTrue(source.contains("return nil"))
    }
}
