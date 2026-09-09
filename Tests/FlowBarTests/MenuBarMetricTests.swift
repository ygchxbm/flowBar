import XCTest
@testable import FlowBar

final class MenuBarMetricTests: XCTestCase {
    func testCyclesThroughAllSixMetricsAndWraps() {
        XCTAssertEqual(MenuBarMetric.allCases, [.download, .upload, .temperature, .power, .level, .powerState])
        XCTAssertEqual(MenuBarMetric.download.moved(by: -1), .powerState)
        XCTAssertEqual(MenuBarMetric.powerState.moved(by: 1), .download)
        XCTAssertEqual(MenuBarMetric.download.moved(by: 1), .upload)
    }

    func testSelectionPersistsAndUnknownValueFallsBack() {
        let suite = "FlowBarTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertEqual(MenuBarSelection(defaults: defaults).metric, .download)
        let selection = MenuBarSelection(defaults: defaults)
        selection.metric = .upload
        XCTAssertEqual(MenuBarSelection(defaults: defaults).metric, .upload)
        defaults.set("removed-metric", forKey: "menuBarMetric")
        XCTAssertEqual(MenuBarSelection(defaults: defaults).metric, .download)
    }

    func testAllMetricsFormatAndUnavailableUploadKeepsDirection() {
        let snapshot = MetricsSnapshot(downloadBytesPerSecond: 8192, uploadBytesPerSecond: 2048,
            battery: BatterySnapshot(temperatureCelsius: 33, chargingWatts: -13, levelPercent: 55, powerState: .discharging))
        XCTAssertEqual(MenuBarMetric.allCases.map { $0.formatted(snapshot) },
                       ["↓ 8K", "↑ 2K", "33°C", "-13W", "55%", "使用电池"])
        XCTAssertEqual(MenuBarMetric.upload.formatted(.unavailable), "↑ --")
    }
}
