import Foundation

protocol NetworkSpeedSampling {
    func sampleSpeeds(now: TimeInterval) -> NetworkSpeeds
    func reset()
}

protocol BatterySampling {
    func snapshot() -> BatterySnapshot
}

extension NetworkSpeedMonitor: NetworkSpeedSampling {}

extension BatteryMonitor: BatterySampling {}

protocol MetricsSampling: Sendable {
    func snapshot(resetNetwork: Bool) async -> MetricsSnapshot
    func refreshBattery() async -> MetricsSnapshot
}

/// Serializes system reads off the main actor and owns the latest full snapshot.
actor MetricsSampler: MetricsSampling {
    private let networkSpeed: NetworkSpeedSampling
    private let battery: BatterySampling
    private var latestSnapshot: MetricsSnapshot = .unavailable

    init(
        networkSpeed: NetworkSpeedSampling = NetworkSpeedMonitor(),
        battery: BatterySampling = BatteryMonitor()
    ) {
        self.networkSpeed = networkSpeed
        self.battery = battery
    }

    func refreshBattery() -> MetricsSnapshot {
        latestSnapshot.battery = battery.snapshot()
        return latestSnapshot
    }

    func snapshot(resetNetwork: Bool = false) -> MetricsSnapshot {
        if resetNetwork { networkSpeed.reset() }
        let network = networkSpeed.sampleSpeeds(now: ProcessInfo.processInfo.systemUptime)
        latestSnapshot = MetricsSnapshot(
            downloadBytesPerSecond: network.download,
            uploadBytesPerSecond: network.upload,
            battery: battery.snapshot()
        )
        return latestSnapshot
    }
}
