import AppKit

private final class HandCursorButton: NSButton {
    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

final class BatteryPopoverViewController: NSViewController {
    static let cornerRadius: CGFloat = 20

    private let downloadValueLabel = NSTextField.label(value: "--")
    private let temperatureValueLabel = NSTextField.label(value: "--")
    private let powerValueLabel = NSTextField.label(value: "--")
    private let batteryValueLabel = NSTextField.label(value: "--")
    private let stateValueLabel = NSTextField.label(value: "--")
    private let launchAtLoginSwitch = NSSwitch()
    private let quitButton = HandCursorButton(title: "退出 FlowBar", target: nil, action: nil)
    private let launchAtLoginController: LaunchAtLoginController

    init(launchAtLoginController: LaunchAtLoginController = LaunchAtLoginController()) {
        self.launchAtLoginController = launchAtLoginController
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 160, height: 200))
        view.translatesAutoresizingMaskIntoConstraints = false

        let contentStack = NSStackView()
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 8
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false

        launchAtLoginSwitch.target = self
        launchAtLoginSwitch.action = #selector(launchAtLoginChanged(_:))
        launchAtLoginSwitch.state = launchAtLoginController.isEnabled ? .on : .off

        quitButton.bezelStyle = .rounded
        quitButton.controlSize = .large
        quitButton.target = self
        quitButton.action = #selector(quitApp)
        quitButton.translatesAutoresizingMaskIntoConstraints = false

        contentStack.addArrangedSubview(Self.row(title: "下载速度", valueLabel: downloadValueLabel))
        contentStack.addArrangedSubview(Self.row(title: "电池温度", valueLabel: temperatureValueLabel))
        contentStack.addArrangedSubview(Self.row(title: "充电功率", valueLabel: powerValueLabel))
        contentStack.addArrangedSubview(Self.row(title: "电池电量", valueLabel: batteryValueLabel))
        contentStack.addArrangedSubview(Self.row(title: "电源状态", valueLabel: stateValueLabel))
        contentStack.addArrangedSubview(separator)
        contentStack.addArrangedSubview(Self.row(title: "登录时启动", control: launchAtLoginSwitch))
        contentStack.addArrangedSubview(quitButton)

        view.addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            contentStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 14),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -14),
            separator.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            quitButton.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            quitButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }

    func update(snapshot: MetricsSnapshot) {
        downloadValueLabel.stringValue = MetricFormatters.downloadSpeed(snapshot.downloadBytesPerSecond)
        temperatureValueLabel.stringValue = MetricFormatters.temperature(snapshot.battery.temperatureCelsius)
        powerValueLabel.stringValue = MetricFormatters.chargingPower(snapshot.battery.chargingWatts)
        batteryValueLabel.stringValue = MetricFormatters.batteryLevel(snapshot.battery.levelPercent)
        stateValueLabel.stringValue = MetricFormatters.powerState(snapshot.battery.powerState)
        launchAtLoginSwitch.state = launchAtLoginController.isEnabled ? .on : .off
    }

    @objc private func launchAtLoginChanged(_ sender: NSSwitch) {
        launchAtLoginController.setEnabled(sender.state == .on)
        sender.state = launchAtLoginController.isEnabled ? .on : .off
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private static func row(title: String, valueLabel: NSTextField) -> NSView {
        row(title: title, control: valueLabel)
    }

    private static func row(title: String, control: NSView) -> NSView {
        let titleLabel = NSTextField.label(value: title)
        titleLabel.textColor = .secondaryLabelColor

        let rowStack = NSStackView()
        rowStack.orientation = .horizontal
        rowStack.alignment = .centerY
        rowStack.distribution = .fill
        rowStack.spacing = 8
        rowStack.translatesAutoresizingMaskIntoConstraints = false

        rowStack.addArrangedSubview(titleLabel)
        rowStack.addArrangedSubview(control)

        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        control.setContentHuggingPriority(.required, for: .horizontal)

        NSLayoutConstraint.activate([
            rowStack.heightAnchor.constraint(greaterThanOrEqualToConstant: 20)
        ])

        return rowStack
    }
}

private extension NSTextField {
    static func label(value: String) -> NSTextField {
        let label = NSTextField(labelWithString: value)
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
}
