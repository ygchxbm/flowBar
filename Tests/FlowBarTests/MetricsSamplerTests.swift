import Foundation
import XCTest
@testable import FlowBar

final class MetricsSamplerTests: XCTestCase {
    func testUnavailableMetricsSnapshot() {
        XCTAssertNil(MetricsSnapshot.unavailable.downloadBytesPerSecond)
        XCTAssertEqual(MetricsSnapshot.unavailable.battery.powerState, .unknown)
    }

    @MainActor
    func testSystemReadsRunOffMainThreadEvenWhenRequestedByUI() async {
        let sampler = MetricsSampler(networkSpeed: ThreadCheckingNetworkSampler(), battery: ThreadCheckingBatterySampler())
        let snapshot = await sampler.snapshot()
        XCTAssertEqual(snapshot.downloadBytesPerSecond, 0)
        XCTAssertEqual(snapshot.battery.levelPercent, 0)
    }

    func testBatteryOnlyRefreshPreservesNetworkAndDoesNotSampleIt() async {
        let network = CountingNetworkSampler()
        let battery = BatterySnapshot(temperatureCelsius: 33.2, chargingWatts: -13.3, levelPercent: 55, powerState: .discharging)
        let sampler = MetricsSampler(networkSpeed: network, battery: FakeBatterySampler(value: battery))
        let previous = await sampler.snapshot()
        let updated = await sampler.refreshBattery()
        XCTAssertEqual(network.calls, 1)
        XCTAssertEqual(updated.downloadBytesPerSecond, previous.downloadBytesPerSecond)
        XCTAssertEqual(updated.uploadBytesPerSecond, previous.uploadBytesPerSecond)
        XCTAssertEqual(updated.battery, battery)
    }

    func testSnapshotCombinesNetworkSpeedAndBatterySnapshot() async {
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

        let snapshot = await sampler.snapshot()

        XCTAssertEqual(snapshot.downloadBytesPerSecond, 1_024)
        XCTAssertEqual(snapshot.uploadBytesPerSecond, 512)
        XCTAssertEqual(snapshot.battery, batterySnapshot)
    }

    func testSnapshotAllowsUnavailableNetworkSpeed() async {
        let sampler = MetricsSampler(
            networkSpeed: FakeNetworkSpeedSampler(speed: nil),
            battery: FakeBatterySampler(value: .unavailable)
        )

        let snapshot = await sampler.snapshot()

        XCTAssertNil(snapshot.downloadBytesPerSecond)
        XCTAssertEqual(snapshot.battery, .unavailable)
    }
}

private struct ThreadCheckingNetworkSampler: NetworkSpeedSampling {
    func reset() {}
    func sampleSpeeds(now: TimeInterval) -> NetworkSpeeds {
        NetworkSpeeds(download: Thread.isMainThread ? 1 : 0, upload: nil)
    }
}

private struct ThreadCheckingBatterySampler: BatterySampling {
    func snapshot() -> BatterySnapshot {
        var snapshot = BatterySnapshot.unavailable
        snapshot.levelPercent = Thread.isMainThread ? 1 : 0
        return snapshot
    }
}

private struct FakeNetworkSpeedSampler: NetworkSpeedSampling {
    func reset() {}
    var speed: Double?

    func sampleSpeeds(now: TimeInterval) -> NetworkSpeeds {
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
    func reset() {}
    var calls = 0
    func sampleSpeeds(now: TimeInterval) -> NetworkSpeeds {
        calls += 1
        return NetworkSpeeds(download: 8192, upload: 2048)
    }
}
