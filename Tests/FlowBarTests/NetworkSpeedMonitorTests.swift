import XCTest
@testable import FlowBar

final class NetworkSpeedMonitorTests: XCTestCase {
    func testFirstSampleReturnsNilBecauseNoDeltaExists() {
        let provider = FakeNetworkInterfaceProvider(samples: [
            [NetworkInterfaceSample(name: "en0", receivedBytes: 1_000, isLoopback: false, isActive: true)]
        ])
        let monitor = NetworkSpeedMonitor(provider: provider)

        XCTAssertNil(monitor.sample(now: Date(timeIntervalSince1970: 10)))
    }

    func testSecondSampleCalculatesDownloadBytesPerSecond() {
        let provider = FakeNetworkInterfaceProvider(samples: [
            [NetworkInterfaceSample(name: "en0", receivedBytes: 1_000, isLoopback: false, isActive: true)],
            [NetworkInterfaceSample(name: "en0", receivedBytes: 5_000, isLoopback: false, isActive: true)]
        ])
        let monitor = NetworkSpeedMonitor(provider: provider)

        _ = monitor.sample(now: Date(timeIntervalSince1970: 10))
        XCTAssertEqual(monitor.sample(now: Date(timeIntervalSince1970: 12)), 2_000)
    }

    func testIgnoresLoopbackAndInactiveInterfaces() {
        let provider = FakeNetworkInterfaceProvider(samples: [
            [
                NetworkInterfaceSample(name: "lo0", receivedBytes: 10_000, isLoopback: true, isActive: true),
                NetworkInterfaceSample(name: "en0", receivedBytes: 1_000, isLoopback: false, isActive: true),
                NetworkInterfaceSample(name: "utun0", receivedBytes: 9_000, isLoopback: false, isActive: false)
            ],
            [
                NetworkInterfaceSample(name: "lo0", receivedBytes: 20_000, isLoopback: true, isActive: true),
                NetworkInterfaceSample(name: "en0", receivedBytes: 3_000, isLoopback: false, isActive: true),
                NetworkInterfaceSample(name: "utun0", receivedBytes: 20_000, isLoopback: false, isActive: false)
            ]
        ])
        let monitor = NetworkSpeedMonitor(provider: provider)

        _ = monitor.sample(now: Date(timeIntervalSince1970: 10))
        XCTAssertEqual(monitor.sample(now: Date(timeIntervalSince1970: 12)), 1_000)
    }

    func testNonPositiveElapsedTimeReturnsNil() {
        let provider = FakeNetworkInterfaceProvider(samples: [
            [NetworkInterfaceSample(name: "en0", receivedBytes: 1_000, isLoopback: false, isActive: true)],
            [NetworkInterfaceSample(name: "en0", receivedBytes: 5_000, isLoopback: false, isActive: true)]
        ])
        let monitor = NetworkSpeedMonitor(provider: provider)

        _ = monitor.sample(now: Date(timeIntervalSince1970: 10))
        XCTAssertNil(monitor.sample(now: Date(timeIntervalSince1970: 10)))
    }

    func testCounterDecreaseReturnsNil() {
        let provider = FakeNetworkInterfaceProvider(samples: [
            [NetworkInterfaceSample(name: "en0", receivedBytes: 5_000, isLoopback: false, isActive: true)],
            [NetworkInterfaceSample(name: "en0", receivedBytes: 1_000, isLoopback: false, isActive: true)]
        ])
        let monitor = NetworkSpeedMonitor(provider: provider)

        _ = monitor.sample(now: Date(timeIntervalSince1970: 10))
        XCTAssertNil(monitor.sample(now: Date(timeIntervalSince1970: 12)))
    }

    func testNewInterfaceDoesNotCreateDownloadSpikeFromLifetimeBytes() {
        let provider = FakeNetworkInterfaceProvider(samples: [
            [NetworkInterfaceSample(name: "en0", receivedBytes: 1_000, isLoopback: false, isActive: true)],
            [
                NetworkInterfaceSample(name: "en0", receivedBytes: 3_000, isLoopback: false, isActive: true),
                NetworkInterfaceSample(name: "en1", receivedBytes: 1_000_000, isLoopback: false, isActive: true)
            ],
            [
                NetworkInterfaceSample(name: "en0", receivedBytes: 5_000, isLoopback: false, isActive: true),
                NetworkInterfaceSample(name: "en1", receivedBytes: 1_004_000, isLoopback: false, isActive: true)
            ]
        ])
        let monitor = NetworkSpeedMonitor(provider: provider)

        _ = monitor.sample(now: Date(timeIntervalSince1970: 10))
        XCTAssertEqual(monitor.sample(now: Date(timeIntervalSince1970: 12)), 1_000)
        XCTAssertEqual(monitor.sample(now: Date(timeIntervalSince1970: 14)), 3_000)
    }

    func testRemovedInterfaceDoesNotPreventRemainingInterfaceDelta() {
        let provider = FakeNetworkInterfaceProvider(samples: [
            [
                NetworkInterfaceSample(name: "en0", receivedBytes: 1_000, isLoopback: false, isActive: true),
                NetworkInterfaceSample(name: "en1", receivedBytes: 10_000, isLoopback: false, isActive: true)
            ],
            [NetworkInterfaceSample(name: "en0", receivedBytes: 5_000, isLoopback: false, isActive: true)]
        ])
        let monitor = NetworkSpeedMonitor(provider: provider)

        _ = monitor.sample(now: Date(timeIntervalSince1970: 10))
        XCTAssertEqual(monitor.sample(now: Date(timeIntervalSince1970: 12)), 2_000)
    }
}

private final class FakeNetworkInterfaceProvider: NetworkInterfaceProviding {
    private var samples: [[NetworkInterfaceSample]]

    init(samples: [[NetworkInterfaceSample]]) {
        self.samples = samples
    }

    func interfaceSamples() -> [NetworkInterfaceSample] {
        samples.removeFirst()
    }
}
