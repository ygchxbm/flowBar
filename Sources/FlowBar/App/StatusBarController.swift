import AppKit

final class StatusBarController {
    private let statusItem: NSStatusItem
    private let metricsSampler: MetricsSampler
    private let popover: NSPopover
    private let popoverViewController: BatteryPopoverViewController
    private var timer: Timer?
    private var latestSnapshot: MetricsSnapshot = .unavailable

    init(metricsSampler: MetricsSampler = MetricsSampler()) {
        self.metricsSampler = metricsSampler
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        popoverViewController = BatteryPopoverViewController()
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 240, height: 190)
        popover.contentViewController = popoverViewController

        statusItem.button?.title = "↓ --"
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover(_:))

        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    deinit {
        timer?.invalidate()
    }

    @objc private func togglePopover(_ sender: Any?) {
        refresh()

        if popover.isShown {
            popover.performClose(sender)
            return
        }

        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    private func refresh() {
        latestSnapshot = metricsSampler.snapshot()
        statusItem.button?.title = MetricFormatters.downloadSpeed(latestSnapshot.downloadBytesPerSecond)
        popoverViewController.update(snapshot: latestSnapshot)
    }
}
