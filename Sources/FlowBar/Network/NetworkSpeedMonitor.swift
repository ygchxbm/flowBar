import Foundation

struct NetworkInterfaceSample: Equatable {
    var name: String
    var receivedBytes: UInt64
    var isLoopback: Bool
    var isActive: Bool
}

protocol NetworkInterfaceProviding {
    func interfaceSamples() -> [NetworkInterfaceSample]
}

final class NetworkSpeedMonitor {
    private let provider: NetworkInterfaceProviding
    private var previousBytesByInterface: [String: UInt64] = [:]
    private var previousDate: Date?

    init(provider: NetworkInterfaceProviding = SystemNetworkInterfaceProvider()) {
        self.provider = provider
    }

    func sample(now: Date = Date()) -> Double? {
        let currentBytesByInterface = provider.interfaceSamples()
            .filter { !$0.isLoopback && $0.isActive }
            .reduce(into: [String: UInt64]()) { result, sample in
                result[sample.name] = sample.receivedBytes
            }

        defer {
            previousBytesByInterface = currentBytesByInterface
            previousDate = now
        }

        guard let previousDate else {
            return nil
        }

        let elapsed = now.timeIntervalSince(previousDate)
        guard elapsed > 0 else {
            return nil
        }

        var bytesDelta: UInt64 = 0
        var hasValidDelta = false

        for (name, currentBytes) in currentBytesByInterface {
            guard let previousBytes = previousBytesByInterface[name],
                  currentBytes >= previousBytes else {
                continue
            }

            bytesDelta += currentBytes - previousBytes
            hasValidDelta = true
        }

        guard hasValidDelta else {
            return nil
        }

        return Double(bytesDelta) / elapsed
    }
}
