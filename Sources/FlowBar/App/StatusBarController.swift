import AppKit

@MainActor
final class StatusBarController: NSObject {
    private enum Layout {
        static let statusItemWidth: CGFloat = 72
    }

    private let selection = MenuBarSelection()
    private let statusItem: NSStatusItem
    private let metricsMonitor: MetricsMonitor
    private let popoverViewController: BatteryPopoverViewController
    private var panel: FlowBarPanel?
    private var localEventMonitor: EventMonitor?
    private var globalEventMonitor: EventMonitor?
    private var powerSourceObserver: PowerSourceObserver?
    private var latestSnapshot: MetricsSnapshot = .unavailable

    init(metricsSampler: MetricsSampler = MetricsSampler()) {
        metricsMonitor = MetricsMonitor(sampler: metricsSampler)
        statusItem = NSStatusBar.system.statusItem(withLength: Layout.statusItemWidth)

        popoverViewController = BatteryPopoverViewController()
        super.init()

        statusItem.button?.alignment = .center
        statusItem.button?.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePanel(_:))

        popoverViewController.configureSelection(selection.metric) { [weak self] metric in
            guard let self else { return }
            self.selection.metric = metric
            self.updateStatusItem()
        }
        powerSourceObserver = PowerSourceObserver { [weak self] in
            self?.metricsMonitor.refreshBattery()
        }
        metricsMonitor.onUpdate = { [weak self] snapshot in
            self?.apply(snapshot)
        }
        let workspaceNotifications = NSWorkspace.shared.notificationCenter
        workspaceNotifications.addObserver(self, selector: #selector(willSleep), name: NSWorkspace.willSleepNotification, object: nil)
        workspaceNotifications.addObserver(self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActive), name: NSApplication.didBecomeActiveNotification, object: nil)
        updateStatusItem()
        metricsMonitor.start()
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func togglePanel(_ sender: Any?) {

        if panel?.isVisible == true {
            closePanel()
            return
        }

        guard let button = statusItem.button else { return }
        popoverViewController.update(snapshot: latestSnapshot)
        popoverViewController.refreshLaunchAtLogin()
        metricsMonitor.refreshBattery()
        showPanel(relativeTo: button)
    }

    @objc private func willSleep() {
        metricsMonitor.stop()
        closePanel()
        apply(.unavailable)
    }

    @objc private func didWake() {
        metricsMonitor.start()
    }

    @objc private func didBecomeActive() {
        if panel?.isVisible == true { popoverViewController.refreshLaunchAtLogin() }
    }

    private func apply(_ snapshot: MetricsSnapshot) {
        guard latestSnapshot != snapshot else { return }
        latestSnapshot = snapshot
        updateStatusItem()
        if panel?.isVisible == true { popoverViewController.update(snapshot: snapshot) }
    }

    private func updateStatusItem() {
        let text = selection.metric.formatted(latestSnapshot)
        if let button = statusItem.button {
            button.toolTip = selection.metric.title
            button.setAccessibilityLabel(selection.metric.title + " " + text)
            guard button.title != text else { return }
            button.title = text
            let font = button.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
            let width = max(Layout.statusItemWidth, ceil((text as NSString).size(withAttributes: [.font: font]).width) + 16)
            if statusItem.length != width {
                statusItem.length = width
            }
        }
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
        panel.onCancel = { [weak self] in self?.closePanel() }
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
        guard panel?.attachedSheet == nil else { return }
        panel?.orderOut(nil)
        statusItem.button?.highlight(false)
        removeEventMonitors()
    }

    private func installEventMonitors() {
        removeEventMonitors()
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.closePanelIfNeeded()
            return event
        }.map(EventMonitor.init)
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePanel()
        }.map(EventMonitor.init)
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
        localEventMonitor = nil
        globalEventMonitor = nil
    }
}

private final class EventMonitor {
    private let token: Any

    init(_ token: Any) { self.token = token }
    deinit { NSEvent.removeMonitor(token) }
}

private final class FlowBarPanel: NSPanel {
    var onCancel: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { onCancel?() }
}
