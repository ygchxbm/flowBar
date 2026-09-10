import Foundation

protocol NetworkSpeedSampling {
    func sampleSpeeds(now: Date) -> NetworkSpeeds
}

protocol BatterySampling {
    func snapshot() -> BatterySnapshot
}

extension NetworkSpeedMonitor: NetworkSpeedSampling {}

extension BatteryMonitor: BatterySampling {}

final class MetricsSampler {
    private let networkSpeed: NetworkSpeedSampling
    private let battery: BatterySampling

    init(
        networkSpeed: NetworkSpeedSampling = NetworkSpeedMonitor(),
        battery: BatterySampling = BatteryMonitor()
    ) {
        self.networkSpeed = networkSpeed
        self.battery = battery
    }

    func refreshingBattery(in snapshot: MetricsSnapshot) -> MetricsSnapshot {
        var updated = snapshot
        updated.battery = battery.snapshot()
        return updated
    }

    func snapshot(now: Date = Date()) -> MetricsSnapshot {
        let network = networkSpeed.sampleSpeeds(now: now)
        return MetricsSnapshot(
            downloadBytesPerSecond: network.download,
            uploadBytesPerSecond: network.upload,
            battery: battery.snapshot()
        )
    }
}
