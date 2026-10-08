import Foundation

/// Delivers snapshots on the main actor. One request may be in flight, with one
/// coalesced request waiting behind it, so slow system reads never build a queue.
@MainActor
final class MetricsMonitor {
    private enum Request: Int {
        case battery, full, resetNetwork
    }

    private let sampler: any MetricsSampling
    private let interval: TimeInterval
    private var timer: SamplingTimer?
    private var task: Task<Void, Never>?
    private var pendingRequest: Request?
    private var generation: UInt64 = 0
    private var isRunning = false
    var onUpdate: ((MetricsSnapshot) -> Void)?

    init(sampler: any MetricsSampling = MetricsSampler(), interval: TimeInterval = 2) {
        precondition(interval > 0 && interval.isFinite)
        self.sampler = sampler
        self.interval = interval
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
        timer.tolerance = interval * 0.1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = SamplingTimer(timer)
        request(.resetNetwork)
    }

    func stop() {
        isRunning = false
        timer = nil
        generation &+= 1
        pendingRequest = nil
        // Cancellation cannot interrupt a synchronous IOKit read. Keep the task
        // tracked until it returns and reject old results using the generation.
        task?.cancel()
    }

    func refresh() { request(.full) }
    func refreshBattery() { request(.battery) }

    private func request(_ request: Request) {
        guard isRunning else { return }
        if task != nil {
            if request.rawValue > (pendingRequest?.rawValue ?? -1) {
                pendingRequest = request
            }
            return
        }

        let generation = generation
        task = Task { [weak self, sampler] in
            let snapshot: MetricsSnapshot
            switch request {
            case .battery:
                snapshot = await sampler.refreshBattery()
            case .full, .resetNetwork:
                snapshot = await sampler.snapshot(resetNetwork: request == .resetNetwork)
            }
            guard let self else { return }
            self.task = nil
            if self.isRunning && self.generation == generation && !Task.isCancelled {
                self.onUpdate?(snapshot)
            }
            if self.isRunning, let pending = self.pendingRequest {
                self.pendingRequest = nil
                self.request(pending)
            }
        }
    }

    deinit {
        task?.cancel()
    }
}

/// Ties the run-loop registration to ownership, including when the monitor is
/// released without stop(). Its cleanup does not access main-actor state.
private final class SamplingTimer {
    private let timer: Timer

    init(_ timer: Timer) { self.timer = timer }
    deinit { timer.invalidate() }
}
