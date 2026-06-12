import AppKit

final class StatusBarController: NSObject {
    private enum Layout {
        static let statusItemWidth: CGFloat = 72
    }

    private let statusItem: NSStatusItem
    private let metricsSampler: MetricsSampler
    private let popoverViewController: BatteryPopoverViewController
    private var panel: FlowBarPanel?
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?
    private var timer: Timer?
    private var latestSnapshot: MetricsSnapshot = .unavailable

    init(metricsSampler: MetricsSampler = MetricsSampler()) {
        self.metricsSampler = metricsSampler
        statusItem = NSStatusBar.system.statusItem(withLength: Layout.statusItemWidth)

        popoverViewController = BatteryPopoverViewController()
        super.init()

        statusItem.button?.title = "↓ --"
        statusItem.button?.alignment = .center
        statusItem.button?.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePanel(_:))

        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    deinit {
        timer?.invalidate()
        removeEventMonitors()
    }

    @objc private func togglePanel(_ sender: Any?) {
        refresh()

        if panel?.isVisible == true {
            closePanel()
            return
        }

        guard let button = statusItem.button else { return }
        showPanel(relativeTo: button)
    }

    private func refresh() {
        latestSnapshot = metricsSampler.snapshot()
        statusItem.button?.title = MetricFormatters.downloadSpeed(latestSnapshot.downloadBytesPerSecond)
        popoverViewController.update(snapshot: latestSnapshot)
    }

    private func showPanel(relativeTo button: NSStatusBarButton) {
        let panel = panel ?? makePanel()
        self.panel = panel
        panel.contentViewController = popoverViewController
        panel.setFrame(panelFrame(relativeTo: button), display: true)
        button.highlight(true)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        installEventMonitors()
    }

    private func makePanel() -> FlowBarPanel {
        let panel = FlowBarPanel(
            contentRect: NSRect(origin: .zero, size: BatteryPopoverViewController.preferredContentSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.transient, .fullScreenAuxiliary]
        return panel
    }

    private func panelFrame(relativeTo button: NSStatusBarButton) -> NSRect {
        let size = BatteryPopoverViewController.preferredContentSize
        guard let buttonWindow = button.window,
              let screen = buttonWindow.screen ?? NSScreen.main else {
            return NSRect(origin: .zero, size: size)
        }

        let buttonFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let x = buttonFrame.midX - size.width / 2
        let y = buttonFrame.minY - size.height - 4
        let minX = screen.visibleFrame.minX + 8
        let maxX = screen.visibleFrame.maxX - size.width - 8

        return NSRect(x: min(max(x, minX), maxX), y: y, width: size.width, height: size.height)
    }

    private func closePanel() {
        panel?.orderOut(nil)
        statusItem.button?.highlight(false)
        removeEventMonitors()
    }

    private func installEventMonitors() {
        removeEventMonitors()
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.closePanelIfNeeded()
            return event
        }
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePanel()
        }
    }

    private func closePanelIfNeeded() {
        guard let panel, panel.isVisible else { return }
        let clickLocation = NSEvent.mouseLocation
        guard !panel.frame.contains(clickLocation), !statusButtonFrameContains(clickLocation) else { return }
        closePanel()
    }

    private func statusButtonFrameContains(_ point: NSPoint) -> Bool {
        guard let button = statusItem.button,
              let buttonWindow = button.window else {
            return false
        }
        let buttonFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        return buttonFrame.contains(point)
    }

    private func removeEventMonitors() {
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }
        if let globalEventMonitor {
            NSEvent.removeMonitor(globalEventMonitor)
            self.globalEventMonitor = nil
        }
    }
}

private final class FlowBarPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
