import Foundation
import XCTest
@testable import FlowBar

final class MetricsSamplerTests: XCTestCase {
    func testSnapshotCombinesNetworkSpeedAndBatterySnapshot() {
        let batterySnapshot = BatterySnapshot(
            temperatureCelsius: 31.2,
            chargingWatts: 12.5,
            levelPercent: 72,
            powerState: .charging
        )
        let sampler = MetricsSampler(
            networkSpeed: FakeNetworkSpeedSampler(speed: 1_024),
            battery: FakeBatterySampler(snapshot: batterySnapshot)
        )

        let snapshot = sampler.snapshot(now: Date(timeIntervalSince1970: 42))

        XCTAssertEqual(snapshot.downloadBytesPerSecond, 1_024)
        XCTAssertEqual(snapshot.battery, batterySnapshot)
    }

    func testSnapshotAllowsUnavailableNetworkSpeed() {
        let sampler = MetricsSampler(
            networkSpeed: FakeNetworkSpeedSampler(speed: nil),
            battery: FakeBatterySampler(snapshot: .unavailable)
        )

        let snapshot = sampler.snapshot(now: Date(timeIntervalSince1970: 42))

        XCTAssertNil(snapshot.downloadBytesPerSecond)
        XCTAssertEqual(snapshot.battery, .unavailable)
    }
}

private struct FakeNetworkSpeedSampler: NetworkSpeedSampling {
    var speed: Double?

    func sample(now: Date) -> Double? {
        speed
    }
}

private struct FakeBatterySampler: BatterySampling {
    var snapshot: BatterySnapshot

    func snapshot() -> BatterySnapshot {
        snapshot
    }
}
