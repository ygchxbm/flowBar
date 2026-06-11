import XCTest
@testable import FlowBar

final class MetricFormattersTests: XCTestCase {
    func testDownloadSpeedUnavailable() {
        XCTAssertEqual(MetricFormatters.downloadSpeed(nil), "↓ --")
        XCTAssertEqual(MetricFormatters.downloadSpeed(-1), "↓ --")
        XCTAssertEqual(MetricFormatters.downloadSpeed(.nan), "↓ --")
        XCTAssertEqual(MetricFormatters.downloadSpeed(.infinity), "↓ --")
    }

    func testDownloadSpeedUsesCompactUnits() {
        XCTAssertEqual(MetricFormatters.downloadSpeed(0), "↓ 0K")
        XCTAssertEqual(MetricFormatters.downloadSpeed(860 * 1024), "↓ 860K")
        XCTAssertEqual(MetricFormatters.downloadSpeed(1.2 * 1024 * 1024), "↓ 1.2M")
        XCTAssertEqual(MetricFormatters.downloadSpeed(1.1 * 1024 * 1024 * 1024), "↓ 1.1G")
    }

    func testDownloadSpeedRolloverStaysCompact() {
        XCTAssertEqual(MetricFormatters.downloadSpeed(1024 * 1024 - 1), "↓ 1M")
        XCTAssertEqual(MetricFormatters.downloadSpeed(1024 * 1024 * 1024 - 1), "↓ 1G")
    }

    func testBatteryFields() {
        XCTAssertEqual(MetricFormatters.temperature(nil), "--")
        XCTAssertEqual(MetricFormatters.temperature(38.4), "38°C")
        XCTAssertEqual(MetricFormatters.chargingPower(nil), "--")
        XCTAssertEqual(MetricFormatters.chargingPower(18.2), "+18W")
        XCTAssertEqual(MetricFormatters.chargingPower(-6.4), "-6W")
        XCTAssertEqual(MetricFormatters.chargingPower(0), "0W")
        XCTAssertEqual(MetricFormatters.batteryLevel(nil), "--")
        XCTAssertEqual(MetricFormatters.batteryLevel(83), "83%")
        XCTAssertEqual(MetricFormatters.batteryLevel(-4), "0%")
        XCTAssertEqual(MetricFormatters.batteryLevel(104), "100%")
    }

    func testPowerStateFormatting() {
        XCTAssertEqual(MetricFormatters.powerState(.charging), "充电中")
        XCTAssertEqual(MetricFormatters.powerState(.externalPower), "接入电源")
        XCTAssertEqual(MetricFormatters.powerState(.discharging), "使用电池")
        XCTAssertEqual(MetricFormatters.powerState(.full), "已充满")
        XCTAssertEqual(MetricFormatters.powerState(.unknown), "--")
    }
}
