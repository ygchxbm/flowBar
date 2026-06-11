import Foundation

protocol NetworkSpeedSampling {
    func sample(now: Date) -> Double?
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

    func snapshot(now: Date = Date()) -> MetricsSnapshot {
        MetricsSnapshot(
            downloadBytesPerSecond: networkSpeed.sample(now: now),
            battery: battery.snapshot()
        )
    }
}
