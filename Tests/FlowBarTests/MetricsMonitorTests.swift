import XCTest
@testable import FlowBar

@MainActor
final class MetricsMonitorTests: XCTestCase {
    func testCoalescesRequestsAndFullSampleTakesPriority() async {
        let first = expectation(description: "initial sample")
        let second = expectation(description: "coalesced sample")
        let updates = expectation(description: "published samples")
        updates.expectedFulfillmentCount = 2
        let sampler = ControlledMetricsSampler { count in
            if count == 1 { first.fulfill() }
            else if count == 2 { second.fulfill() }
            else { XCTFail("Unexpected queued sample") }
        }
        let monitor = MetricsMonitor(sampler: sampler, interval: 3600)
        monitor.onUpdate = { _ in
            XCTAssertTrue(Thread.isMainThread)
            updates.fulfill()
        }
        monitor.start()
        monitor.start()
        await fulfillment(of: [first], timeout: 2)
        for _ in 0..<20 {
            monitor.refreshBattery()
            monitor.refresh()
        }
        await sampler.completeNext(with: .unavailable)
        await fulfillment(of: [second], timeout: 2)
        await sampler.completeNext(with: .unavailable)
        await fulfillment(of: [updates], timeout: 2)
        monitor.stop()
        let requests = await sampler.requests
        XCTAssertEqual(requests, [.reset, .full])
    }

    func testStopDiscardsInFlightResultAndIgnoresFurtherRefreshes() async {
        let started = expectation(description: "started")
        let unwanted = expectation(description: "stale result")
        unwanted.isInverted = true
        let sampler = ControlledMetricsSampler { _ in started.fulfill() }
        let monitor = MetricsMonitor(sampler: sampler, interval: 3600)
        monitor.onUpdate = { _ in unwanted.fulfill() }
        monitor.start()
        await fulfillment(of: [started], timeout: 2)
        monitor.refresh()
        monitor.stop()
        monitor.refreshBattery()
        monitor.refresh()
        await sampler.completeNext(with: .unavailable)
        await fulfillment(of: [unwanted], timeout: 0.1)
        let requests = await sampler.requests
        XCTAssertEqual(requests, [.reset])
    }

    func testRestartRejectsOldResultAndResetsBeforePublishing() async {
        let first = expectation(description: "initial request")
        let restarted = expectation(description: "restart request")
        let published = expectation(description: "fresh result")
        let sampler = ControlledMetricsSampler { count in
            if count == 1 { first.fulfill() }
            else if count == 2 { restarted.fulfill() }
            else { XCTFail("Unexpected queued sample") }
        }
        let monitor = MetricsMonitor(sampler: sampler, interval: 3600)
        let fresh = MetricsSnapshot(downloadBytesPerSecond: 42, battery: .unavailable)
        monitor.onUpdate = { snapshot in
            XCTAssertEqual(snapshot, fresh)
            published.fulfill()
        }
        monitor.start()
        await fulfillment(of: [first], timeout: 2)
        monitor.stop()
        monitor.start()
        monitor.refreshBattery()
        monitor.refresh()
        await sampler.completeNext(with: .unavailable)
        await fulfillment(of: [restarted], timeout: 2)
        await sampler.completeNext(with: fresh)
        await fulfillment(of: [published], timeout: 2)
        monitor.stop()
        let requests = await sampler.requests
        XCTAssertEqual(requests, [.reset, .reset])
    }

    func testBatteryOnlyRequestAndReentrantStop() async {
        let first = expectation(description: "initial request")
        let battery = expectation(description: "battery request")
        let finished = expectation(description: "stopped in callback")
        let sampler = ControlledMetricsSampler { count in
            if count == 1 { first.fulfill() }
            else if count == 2 { battery.fulfill() }
            else { XCTFail("Unexpected sample after stop") }
        }
        let monitor = MetricsMonitor(sampler: sampler, interval: 3600)
        var updates = 0
        monitor.onUpdate = { [weak monitor] _ in
            updates += 1
            if updates == 2 {
                monitor?.stop()
                finished.fulfill()
            }
        }
        monitor.start()
        await fulfillment(of: [first], timeout: 2)
        monitor.refreshBattery()
        await sampler.completeNext(with: .unavailable)
        await fulfillment(of: [battery], timeout: 2)
        monitor.refresh()
        await sampler.completeNext(with: .unavailable)
        await fulfillment(of: [finished], timeout: 2)
        let requests = await sampler.requests
        XCTAssertEqual(requests, [.reset, .battery])
    }

    func testInFlightWorkDoesNotRetainMonitor() async {
        let started = expectation(description: "started")
        let sampler = ControlledMetricsSampler { _ in started.fulfill() }
        var monitor: MetricsMonitor? = MetricsMonitor(sampler: sampler, interval: 3600)
        weak var weakMonitor = monitor
        monitor?.start()
        await fulfillment(of: [started], timeout: 2)
        monitor = nil
        XCTAssertNil(weakMonitor)
        await sampler.completeNext(with: .unavailable)
    }
}

private actor ControlledMetricsSampler: MetricsSampling {
    enum Request: Equatable { case reset, full, battery }
    private(set) var requests: [Request] = []
    private var completion: CheckedContinuation<MetricsSnapshot, Never>?
    private let onRequest: @Sendable (Int) -> Void

    init(onRequest: @escaping @Sendable (Int) -> Void) {
        self.onRequest = onRequest
    }

    func snapshot(resetNetwork: Bool) async -> MetricsSnapshot {
        await sample(resetNetwork ? .reset : .full)
    }

    func refreshBattery() async -> MetricsSnapshot { await sample(.battery) }

    private func sample(_ request: Request) async -> MetricsSnapshot {
        XCTAssertNil(completion, "Sampling must never overlap")
        requests.append(request)
        return await withCheckedContinuation { continuation in
            completion = continuation
            onRequest(requests.count)
        }
    }

    func completeNext(with snapshot: MetricsSnapshot) {
        let continuation = completion
        completion = nil
        XCTAssertNotNil(continuation)
        continuation?.resume(returning: snapshot)
    }
}
