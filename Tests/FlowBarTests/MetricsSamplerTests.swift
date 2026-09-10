import Foundation
import XCTest
@testable import FlowBar

final class MetricsSamplerTests: XCTestCase {
    func testBatteryOnlyRefreshPreservesNetworkAndDoesNotSampleIt() {
        let network = CountingNetworkSampler()
        let battery = BatterySnapshot(temperatureCelsius: 33.2, chargingWatts: -13.3, levelPercent: 55, powerState: .discharging)
        let sampler = MetricsSampler(networkSpeed: network, battery: FakeBatterySampler(value: battery))
        let previous = MetricsSnapshot(downloadBytesPerSecond: 8192, uploadBytesPerSecond: 2048, battery: .unavailable)
        let updated = sampler.refreshingBattery(in: previous)
        XCTAssertEqual(network.calls, 0)
        XCTAssertEqual(updated.downloadBytesPerSecond, previous.downloadBytesPerSecond)
        XCTAssertEqual(updated.uploadBytesPerSecond, previous.uploadBytesPerSecond)
        XCTAssertEqual(updated.battery, battery)
        XCTAssertEqual(MenuBarMetric.temperature.detailFormatted(updated), "33.2°C")
        XCTAssertEqual(MenuBarMetric.temperature.formatted(updated), "33°C")
    }

    func testSnapshotCombinesNetworkSpeedAndBatterySnapshot() {
        let batterySnapshot = BatterySnapshot(
            temperatureCelsius: 31.2,
            chargingWatts: 12.5,
            levelPercent: 72,
            powerState: .charging
        )
        let sampler = MetricsSampler(
            networkSpeed: FakeNetworkSpeedSampler(speed: 1_024),
            battery: FakeBatterySampler(value: batterySnapshot)
        )

        let snapshot = sampler.snapshot(now: Date(timeIntervalSince1970: 42))

        XCTAssertEqual(snapshot.downloadBytesPerSecond, 1_024)
        XCTAssertEqual(snapshot.uploadBytesPerSecond, 512)
        XCTAssertEqual(snapshot.battery, batterySnapshot)
    }

    func testSnapshotAllowsUnavailableNetworkSpeed() {
        let sampler = MetricsSampler(
            networkSpeed: FakeNetworkSpeedSampler(speed: nil),
            battery: FakeBatterySampler(value: .unavailable)
        )

        let snapshot = sampler.snapshot(now: Date(timeIntervalSince1970: 42))

        XCTAssertNil(snapshot.downloadBytesPerSecond)
        XCTAssertEqual(snapshot.battery, .unavailable)
    }
}

private struct FakeNetworkSpeedSampler: NetworkSpeedSampling {
    var speed: Double?

    func sampleSpeeds(now: Date) -> NetworkSpeeds {
        NetworkSpeeds(download: speed, upload: speed.map { $0 / 2 })
    }
}

private struct FakeBatterySampler: BatterySampling {
    var value: BatterySnapshot

    func snapshot() -> BatterySnapshot {
        value
    }
}

private final class CountingNetworkSampler: NetworkSpeedSampling {
    var calls = 0
    func sampleSpeeds(now: Date) -> NetworkSpeeds {
        calls += 1
        return NetworkSpeeds(download: nil, upload: nil)
    }
}
