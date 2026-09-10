import XCTest
@testable import FlowBar

final class NetworkSpeedMonitorTests: XCTestCase {
    func testUploadAndDownloadShareSampleAndResetIndependently() {
        let provider = FakeNetworkInterfaceProvider(samples: [
            [NetworkInterfaceSample(name: "en0", receivedBytes: 100, isLoopback: false, isActive: true, sentBytes: 200)],
            [NetworkInterfaceSample(name: "en0", receivedBytes: 4100, isLoopback: false, isActive: true, sentBytes: 1200)],
            [NetworkInterfaceSample(name: "en0", receivedBytes: 6100, isLoopback: false, isActive: true, sentBytes: 10)]
        ])
        let monitor = NetworkSpeedMonitor(provider: provider)
        let initial = monitor.sampleSpeeds(now: Date(timeIntervalSince1970: 10))
        XCTAssertNil(initial.download)
        XCTAssertNil(initial.upload)
        let speeds = monitor.sampleSpeeds(now: Date(timeIntervalSince1970: 12))
        XCTAssertEqual(speeds.download, 2000)
        XCTAssertEqual(speeds.upload, 500)
        let reset = monitor.sampleSpeeds(now: Date(timeIntervalSince1970: 14))
        XCTAssertEqual(reset.download, 1000)
        XCTAssertNil(reset.upload)
    }

    func testFirstSampleReturnsNilBecauseNoDeltaExists() {
        let provider = FakeNetworkInterfaceProvider(samples: [
            [NetworkInterfaceSample(name: "en0", receivedBytes: 1_000, isLoopback: false, isActive: true)]
        ])
        let monitor = NetworkSpeedMonitor(provider: provider)

        XCTAssertNil(monitor.sampleSpeeds(now: Date(timeIntervalSince1970: 10)).download)
    }

    func testSecondSampleCalculatesDownloadBytesPerSecond() {
        let provider = FakeNetworkInterfaceProvider(samples: [
            [NetworkInterfaceSample(name: "en0", receivedBytes: 1_000, isLoopback: false, isActive: true)],
            [NetworkInterfaceSample(name: "en0", receivedBytes: 5_000, isLoopback: false, isActive: true)]
        ])
        let monitor = NetworkSpeedMonitor(provider: provider)

        _ = monitor.sampleSpeeds(now: Date(timeIntervalSince1970: 10)).download
        XCTAssertEqual(monitor.sampleSpeeds(now: Date(timeIntervalSince1970: 12)).download, 2_000)
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

        _ = monitor.sampleSpeeds(now: Date(timeIntervalSince1970: 10)).download
        XCTAssertEqual(monitor.sampleSpeeds(now: Date(timeIntervalSince1970: 12)).download, 1_000)
    }

    func testDoesNotCountTrafficAgainOnVirtualInterfaces() {
        let provider = FakeNetworkInterfaceProvider(samples: [1_000, 4_000].map { bytes in
            [
                NetworkInterfaceSample(name: "en0", receivedBytes: UInt64(bytes), isLoopback: false, isActive: true),
                NetworkInterfaceSample(name: "utun0", receivedBytes: UInt64(bytes), isLoopback: false, isActive: true, isHardware: false),
                NetworkInterfaceSample(name: "bridge0", receivedBytes: UInt64(bytes), isLoopback: false, isActive: true, isHardware: false)
            ]
        })
        let monitor = NetworkSpeedMonitor(provider: provider)

        _ = monitor.sampleSpeeds(now: Date(timeIntervalSince1970: 10)).download
        XCTAssertEqual(monitor.sampleSpeeds(now: Date(timeIntervalSince1970: 12)).download, 1_500)
    }

    func testNonPositiveElapsedTimeReturnsNil() {
        let provider = FakeNetworkInterfaceProvider(samples: [
            [NetworkInterfaceSample(name: "en0", receivedBytes: 1_000, isLoopback: false, isActive: true)],
            [NetworkInterfaceSample(name: "en0", receivedBytes: 5_000, isLoopback: false, isActive: true)]
        ])
        let monitor = NetworkSpeedMonitor(provider: provider)

        _ = monitor.sampleSpeeds(now: Date(timeIntervalSince1970: 10)).download
        XCTAssertNil(monitor.sampleSpeeds(now: Date(timeIntervalSince1970: 10)).download)
    }

    func testCounterDecreaseReturnsNil() {
        let provider = FakeNetworkInterfaceProvider(samples: [
            [NetworkInterfaceSample(name: "en0", receivedBytes: 5_000, isLoopback: false, isActive: true)],
            [NetworkInterfaceSample(name: "en0", receivedBytes: 1_000, isLoopback: false, isActive: true)]
        ])
        let monitor = NetworkSpeedMonitor(provider: provider)

        _ = monitor.sampleSpeeds(now: Date(timeIntervalSince1970: 10)).download
        XCTAssertNil(monitor.sampleSpeeds(now: Date(timeIntervalSince1970: 12)).download)
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

        _ = monitor.sampleSpeeds(now: Date(timeIntervalSince1970: 10)).download
        XCTAssertEqual(monitor.sampleSpeeds(now: Date(timeIntervalSince1970: 12)).download, 1_000)
        XCTAssertEqual(monitor.sampleSpeeds(now: Date(timeIntervalSince1970: 14)).download, 3_000)
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

        _ = monitor.sampleSpeeds(now: Date(timeIntervalSince1970: 10)).download
        XCTAssertEqual(monitor.sampleSpeeds(now: Date(timeIntervalSince1970: 12)).download, 2_000)
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
