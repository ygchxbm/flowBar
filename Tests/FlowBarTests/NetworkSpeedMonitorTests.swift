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
        let initial = monitor.sampleSpeeds(now: 10)
        XCTAssertNil(initial.download)
        XCTAssertNil(initial.upload)
        let speeds = monitor.sampleSpeeds(now: 12)
        XCTAssertEqual(speeds.download, 2000)
        XCTAssertEqual(speeds.upload, 500)
        let reset = monitor.sampleSpeeds(now: 14)
        XCTAssertEqual(reset.download, 1000)
        XCTAssertNil(reset.upload)
    }

    func testFirstSampleReturnsNilBecauseNoDeltaExists() {
        let provider = FakeNetworkInterfaceProvider(samples: [
            [NetworkInterfaceSample(name: "en0", receivedBytes: 1_000, isLoopback: false, isActive: true)]
        ])
        let monitor = NetworkSpeedMonitor(provider: provider)

        XCTAssertNil(monitor.sampleSpeeds(now: 10).download)
    }

    func testSecondSampleCalculatesDownloadBytesPerSecond() {
        let provider = FakeNetworkInterfaceProvider(samples: [
            [NetworkInterfaceSample(name: "en0", receivedBytes: 1_000, isLoopback: false, isActive: true)],
            [NetworkInterfaceSample(name: "en0", receivedBytes: 5_000, isLoopback: false, isActive: true)]
        ])
        let monitor = NetworkSpeedMonitor(provider: provider)

        _ = monitor.sampleSpeeds(now: 10).download
        XCTAssertEqual(monitor.sampleSpeeds(now: 12).download, 2_000)
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

        _ = monitor.sampleSpeeds(now: 10).download
        XCTAssertEqual(monitor.sampleSpeeds(now: 12).download, 1_000)
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

        _ = monitor.sampleSpeeds(now: 10).download
        XCTAssertEqual(monitor.sampleSpeeds(now: 12).download, 1_500)
    }

    func testNonPositiveElapsedTimeReturnsNil() {
        let provider = FakeNetworkInterfaceProvider(samples: [
            [NetworkInterfaceSample(name: "en0", receivedBytes: 1_000, isLoopback: false, isActive: true)],
            [NetworkInterfaceSample(name: "en0", receivedBytes: 5_000, isLoopback: false, isActive: true)]
        ])
        let monitor = NetworkSpeedMonitor(provider: provider)

        _ = monitor.sampleSpeeds(now: 10).download
        XCTAssertNil(monitor.sampleSpeeds(now: 10).download)
    }

    func testCounterDecreaseReturnsNil() {
        let provider = FakeNetworkInterfaceProvider(samples: [
            [NetworkInterfaceSample(name: "en0", receivedBytes: 5_000, isLoopback: false, isActive: true)],
            [NetworkInterfaceSample(name: "en0", receivedBytes: 1_000, isLoopback: false, isActive: true)]
        ])
        let monitor = NetworkSpeedMonitor(provider: provider)

        _ = monitor.sampleSpeeds(now: 10).download
        XCTAssertNil(monitor.sampleSpeeds(now: 12).download)
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

        _ = monitor.sampleSpeeds(now: 10).download
        XCTAssertEqual(monitor.sampleSpeeds(now: 12).download, 1_000)
        XCTAssertEqual(monitor.sampleSpeeds(now: 14).download, 3_000)
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

        _ = monitor.sampleSpeeds(now: 10).download
        XCTAssertEqual(monitor.sampleSpeeds(now: 12).download, 2_000)
    }

    func testResetDiscardsBothBaselinesUntilNextSample() {
        let provider = FakeNetworkInterfaceProvider(samples: [
            [sample(received: 1_000, sent: 2_000)],
            [sample(received: 3_000, sent: 6_000)],
            [sample(received: 1_000_000, sent: 2_000_000)],
            [sample(received: 1_002_000, sent: 2_004_000)]
        ])
        let monitor = NetworkSpeedMonitor(provider: provider)

        _ = monitor.sampleSpeeds(now: 10)
        XCTAssertEqual(monitor.sampleSpeeds(now: 12).download, 1_000)
        monitor.reset()
        let firstAfterReset = monitor.sampleSpeeds(now: 100)
        XCTAssertNil(firstAfterReset.download)
        XCTAssertNil(firstAfterReset.upload)
        let next = monitor.sampleSpeeds(now: 102)
        XCTAssertEqual(next.download, 1_000)
        XCTAssertEqual(next.upload, 2_000)
    }

    func testEmptySampleRequiresNewBaselineBeforeRecovery() {
        let provider = FakeNetworkInterfaceProvider(samples: [
            [sample(received: 1_000, sent: 2_000)],
            [],
            [sample(received: 1_000_000, sent: 2_000_000)],
            [sample(received: 1_002_000, sent: 2_004_000)]
        ])
        let monitor = NetworkSpeedMonitor(provider: provider)

        _ = monitor.sampleSpeeds(now: 10)
        for timestamp in [12.0, 14.0] {
            let unavailable = monitor.sampleSpeeds(now: timestamp)
            XCTAssertNil(unavailable.download)
            XCTAssertNil(unavailable.upload)
        }
        let recovered = monitor.sampleSpeeds(now: 16)
        XCTAssertEqual(recovered.download, 1_000)
        XCTAssertEqual(recovered.upload, 2_000)
    }

    func testCounterResetRecoversOnNextSampleAndDoesNotDiscardOtherDirection() {
        let provider = FakeNetworkInterfaceProvider(samples: [
            [sample(received: 5_000, sent: 2_000)],
            [sample(received: 100, sent: 6_000)],
            [sample(received: 2_100, sent: 10_000)]
        ])
        let monitor = NetworkSpeedMonitor(provider: provider)

        _ = monitor.sampleSpeeds(now: 10)
        let reset = monitor.sampleSpeeds(now: 12)
        XCTAssertNil(reset.download)
        XCTAssertEqual(reset.upload, 2_000)
        let recovered = monitor.sampleSpeeds(now: 14)
        XCTAssertEqual(recovered.download, 1_000)
        XCTAssertEqual(recovered.upload, 2_000)
    }

    func testMultipleInterfacesContributeIndependentlyAfterOneCounterResets() {
        let provider = FakeNetworkInterfaceProvider(samples: [
            [sample(received: 1_000, sent: 5_000), sample(name: "en1", received: 10_000, sent: 20_000)],
            [sample(received: 3_000, sent: 100), sample(name: "en1", received: 14_000, sent: 26_000)],
            [sample(received: 5_000, sent: 2_100), sample(name: "en1", received: 18_000, sent: 32_000)]
        ])
        let monitor = NetworkSpeedMonitor(provider: provider)

        _ = monitor.sampleSpeeds(now: 10)
        let reset = monitor.sampleSpeeds(now: 12)
        XCTAssertEqual(reset.download, 3_000)
        XCTAssertEqual(reset.upload, 3_000)
        let recovered = monitor.sampleSpeeds(now: 14)
        XCTAssertEqual(recovered.download, 3_000)
        XCTAssertEqual(recovered.upload, 4_000)
    }

    func testNonFiniteTimestampsDiscardBaselineAndRecover() {
        for invalidTimestamp in [TimeInterval.nan, .infinity, -.infinity] {
            let provider = FakeNetworkInterfaceProvider(samples: [
                [sample(received: 1_000, sent: 2_000)],
                [sample(received: 3_000, sent: 6_000)],
                [sample(received: 5_000, sent: 10_000)],
                [sample(received: 7_000, sent: 14_000)]
            ])
            let monitor = NetworkSpeedMonitor(provider: provider)

            _ = monitor.sampleSpeeds(now: 10)
            let invalid = monitor.sampleSpeeds(now: invalidTimestamp)
            XCTAssertNil(invalid.download)
            XCTAssertNil(invalid.upload)
            let rebaseline = monitor.sampleSpeeds(now: 14)
            XCTAssertNil(rebaseline.download)
            XCTAssertNil(rebaseline.upload)
            let recovered = monitor.sampleSpeeds(now: 16)
            XCTAssertEqual(recovered.download, 1_000)
            XCTAssertEqual(recovered.upload, 2_000)
        }
    }

    func testBackwardTimestampRebaselinesWithoutProducingNegativeRates() {
        let provider = FakeNetworkInterfaceProvider(samples: [
            [sample(received: 1_000, sent: 2_000)],
            [sample(received: 3_000, sent: 6_000)],
            [sample(received: 5_000, sent: 10_000)]
        ])
        let monitor = NetworkSpeedMonitor(provider: provider)

        _ = monitor.sampleSpeeds(now: 10)
        let invalid = monitor.sampleSpeeds(now: 8)
        XCTAssertNil(invalid.download)
        XCTAssertNil(invalid.upload)
        let recovered = monitor.sampleSpeeds(now: 10)
        XCTAssertEqual(recovered.download, 1_000)
        XCTAssertEqual(recovered.upload, 2_000)
    }

    private func sample(name: String = "en0", received: UInt64, sent: UInt64) -> NetworkInterfaceSample {
        NetworkInterfaceSample(name: name, receivedBytes: received, isLoopback: false, isActive: true, sentBytes: sent)
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
