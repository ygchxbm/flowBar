import Foundation

struct NetworkInterfaceSample: Equatable {
    var name: String
    var receivedBytes: UInt64
    var isLoopback: Bool
    var isActive: Bool
    var isHardware: Bool = true
    var sentBytes: UInt64 = 0
}

protocol NetworkInterfaceProviding {
    func interfaceSamples() -> [NetworkInterfaceSample]
}

struct NetworkSpeeds {
    var download: Double?
    var upload: Double?
}

final class NetworkSpeedMonitor {
    private let provider: NetworkInterfaceProviding
    private var previous: [String: NetworkInterfaceSample] = [:]
    private var previousTimestamp: TimeInterval?

    init(provider: NetworkInterfaceProviding = SystemNetworkInterfaceProvider()) {
        self.provider = provider
    }

    func reset() {
        previous = [:]
        previousTimestamp = nil
    }

    func sampleSpeeds(now: TimeInterval = ProcessInfo.processInfo.systemUptime) -> NetworkSpeeds {
        let current = provider.interfaceSamples()
            .filter { !$0.isLoopback && $0.isActive && $0.isHardware }
            .reduce(into: [String: NetworkInterfaceSample]()) { $0[$1.name] = $1 }
        guard now.isFinite else {
            reset()
            return NetworkSpeeds(download: nil, upload: nil)
        }
        defer { previous = current; previousTimestamp = now }
        guard let previousTimestamp else {
            return NetworkSpeeds(download: nil, upload: nil)
        }
        let elapsed = now - previousTimestamp
        guard elapsed.isFinite, elapsed > 0 else {
            return NetworkSpeeds(download: nil, upload: nil)
        }
        func rate(_ key: KeyPath<NetworkInterfaceSample, UInt64>) -> Double? {
            var delta = 0.0
            var valid = false
            for (name, sample) in current {
                guard let old = previous[name], sample[keyPath: key] >= old[keyPath: key] else { continue }
                delta += Double(sample[keyPath: key] - old[keyPath: key])
                valid = true
            }
            return valid ? delta / elapsed : nil
        }
        return NetworkSpeeds(download: rate(\.receivedBytes), upload: rate(\.sentBytes))
    }
}
