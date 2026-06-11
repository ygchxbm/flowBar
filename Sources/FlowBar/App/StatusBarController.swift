import AppKit

final class StatusBarController: NSObject {
    private enum Layout {
        static let statusItemWidth: CGFloat = 48
    }

    private let statusItem: NSStatusItem
    private let metricsSampler: MetricsSampler
    private let popover: NSPopover
    private let popoverViewController: BatteryPopoverViewController
    private var timer: Timer?
    private var latestSnapshot: MetricsSnapshot = .unavailable

    init(metricsSampler: MetricsSampler = MetricsSampler()) {
        self.metricsSampler = metricsSampler
        statusItem = NSStatusBar.system.statusItem(withLength: Layout.statusItemWidth)

        popoverViewController = BatteryPopoverViewController()
        popover = NSPopover()
        super.init()

        popover.behavior = .transient
        popover.delegate = self
        popover.contentSize = NSSize(width: 160, height: 220)
        popover.contentViewController = popoverViewController

        statusItem.button?.title = "↓ --"
        statusItem.button?.alignment = .center
        statusItem.button?.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
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
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    private func refresh() {
        latestSnapshot = metricsSampler.snapshot()
        statusItem.button?.title = MetricFormatters.downloadSpeed(latestSnapshot.downloadBytesPerSecond)
        popoverViewController.update(snapshot: latestSnapshot)
    }
}

extension StatusBarController: NSPopoverDelegate {
    func popoverWillShow(_ notification: Notification) {
        guard let popover = notification.object as? NSPopover,
              let window = popover.contentViewController?.view.window,
              let frameView = window.contentView?.superview else { return }

        let radius = BatteryPopoverViewController.cornerRadius
        frameView.wantsLayer = true
        frameView.layer?.cornerRadius = radius
        frameView.layer?.masksToBounds = true
    }
}
