# FlowBar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a lightweight macOS 13+ AppKit menu bar app that shows download speed in the status bar and battery details in a small popover.

**Architecture:** Use a Swift Package with one executable target and one test target. Keep metric collection, formatting, AppKit UI, and launch-at-login integration in separate files so core logic is testable without starting the UI.

**Tech Stack:** Swift 5.9+, AppKit, IOKit, ServiceManagement, XCTest, Swift Package Manager, shell script for local `.app` bundling.

---

## File Structure

- Create `Package.swift`: Swift package manifest for the `FlowBar` executable and `FlowBarTests`.
- Create `Sources/FlowBar/App/FlowBarApp.swift`: app entry point and application delegate.
- Create `Sources/FlowBar/App/StatusBarController.swift`: owns `NSStatusItem`, timer, and popover.
- Create `Sources/FlowBar/App/BatteryPopoverViewController.swift`: AppKit popover view for current metrics and launch-at-login toggle.
- Create `Sources/FlowBar/App/LaunchAtLoginController.swift`: `SMAppService` wrapper.
- Create `Sources/FlowBar/Metrics/MetricsSnapshot.swift`: shared metric value types.
- Create `Sources/FlowBar/Metrics/MetricFormatters.swift`: compact display formatting.
- Create `Sources/FlowBar/Metrics/MetricsSampler.swift`: combines network and battery metrics.
- Create `Sources/FlowBar/Network/NetworkSpeedMonitor.swift`: calculates download speed from cumulative received bytes.
- Create `Sources/FlowBar/Network/SystemNetworkInterfaceProvider.swift`: reads system network interface counters.
- Create `Sources/FlowBar/Battery/BatteryMonitor.swift`: parses battery values and calculates charging power.
- Create `Sources/FlowBar/Battery/IOKitBatteryProvider.swift`: reads battery data from IOKit.
- Create `Resources/Info.plist`: local app bundle metadata with menu-bar-only behavior.
- Create `Scripts/build-app.sh`: builds Swift executable and packages `FlowBar.app`.
- Create `Tests/FlowBarTests/MetricFormattersTests.swift`: formatter tests.
- Create `Tests/FlowBarTests/NetworkSpeedMonitorTests.swift`: network delta tests.
- Create `Tests/FlowBarTests/BatteryMonitorTests.swift`: battery parsing and power tests.
- Create `Tests/FlowBarTests/MetricsSamplerTests.swift`: combined snapshot tests.
- Create `README.md`: local build and verification notes.

## Task 1: Scaffold Swift Package

**Files:**
- Create: `Package.swift`
- Create: `Sources/FlowBar/App/FlowBarApp.swift`
- Create: `Sources/FlowBar/Metrics/MetricsSnapshot.swift`

- [ ] **Step 1: Create package manifest**

Create `Package.swift`:

```swift
// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "FlowBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "FlowBar", targets: ["FlowBar"])
    ],
    targets: [
        .executableTarget(
            name: "FlowBar",
            path: "Sources/FlowBar",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement")
            ]
        ),
        .testTarget(
            name: "FlowBarTests",
            dependencies: ["FlowBar"],
            path: "Tests/FlowBarTests"
        )
    ]
)
```

- [ ] **Step 2: Create shared metric models**

Create `Sources/FlowBar/Metrics/MetricsSnapshot.swift`:

```swift
import Foundation

struct MetricsSnapshot: Equatable {
    var downloadBytesPerSecond: Double?
    var battery: BatterySnapshot

    static let unavailable = MetricsSnapshot(
        downloadBytesPerSecond: nil,
        battery: .unavailable
    )
}

struct BatterySnapshot: Equatable {
    enum PowerState: Equatable {
        case charging
        case discharging
        case full
        case unknown
    }

    var temperatureCelsius: Double?
    var chargingWatts: Double?
    var levelPercent: Int?
    var powerState: PowerState

    static let unavailable = BatterySnapshot(
        temperatureCelsius: nil,
        chargingWatts: nil,
        levelPercent: nil,
        powerState: .unknown
    )
}
```

- [ ] **Step 3: Create minimal app entry point**

Create `Sources/FlowBar/App/FlowBarApp.swift`:

```swift
import AppKit

@main
final class FlowBarApp: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    static func main() {
        let app = NSApplication.shared
        let delegate = FlowBarApp()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController()
    }
}
```

- [ ] **Step 4: Add temporary status bar controller stub**

Create `Sources/FlowBar/App/StatusBarController.swift`:

```swift
import AppKit

final class StatusBarController {
    private let statusItem: NSStatusItem

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "↓ --"
    }
}
```

- [ ] **Step 5: Build to verify scaffold**

Run:

```bash
swift build
```

Expected: build succeeds.

- [ ] **Step 6: Commit scaffold**

```bash
git add Package.swift Sources/FlowBar
git commit -m "chore: scaffold FlowBar Swift package"
```

## Task 2: Metric Formatting

**Files:**
- Create: `Sources/FlowBar/Metrics/MetricFormatters.swift`
- Create: `Tests/FlowBarTests/MetricFormattersTests.swift`

- [ ] **Step 1: Write failing formatter tests**

Create `Tests/FlowBarTests/MetricFormattersTests.swift`:

```swift
import XCTest
@testable import FlowBar

final class MetricFormattersTests: XCTestCase {
    func testDownloadSpeedUnavailable() {
        XCTAssertEqual(MetricFormatters.downloadSpeed(nil), "↓ --")
    }

    func testDownloadSpeedUsesCompactUnits() {
        XCTAssertEqual(MetricFormatters.downloadSpeed(0), "↓ 0K")
        XCTAssertEqual(MetricFormatters.downloadSpeed(860 * 1024), "↓ 860K")
        XCTAssertEqual(MetricFormatters.downloadSpeed(1.2 * 1024 * 1024), "↓ 1.2M")
        XCTAssertEqual(MetricFormatters.downloadSpeed(1.1 * 1024 * 1024 * 1024), "↓ 1.1G")
    }

    func testBatteryFields() {
        XCTAssertEqual(MetricFormatters.temperature(nil), "--")
        XCTAssertEqual(MetricFormatters.temperature(38.4), "38°C")
        XCTAssertEqual(MetricFormatters.chargingPower(nil), "--")
        XCTAssertEqual(MetricFormatters.chargingPower(18.2), "+18W")
        XCTAssertEqual(MetricFormatters.chargingPower(-6.4), "-6W")
        XCTAssertEqual(MetricFormatters.chargingPower(0), "0W")
        XCTAssertEqual(MetricFormatters.batteryLevel(nil), "--")
        XCTAssertEqual(MetricFormatters.batteryLevel(83), "83%")
    }
}
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
swift test --filter MetricFormattersTests
```

Expected: fails because `MetricFormatters` does not exist.

- [ ] **Step 3: Implement formatters**

Create `Sources/FlowBar/Metrics/MetricFormatters.swift`:

```swift
import Foundation

enum MetricFormatters {
    static func downloadSpeed(_ bytesPerSecond: Double?) -> String {
        guard let bytesPerSecond, bytesPerSecond.isFinite, bytesPerSecond >= 0 else {
            return "↓ --"
        }

        let kib = 1024.0
        let mib = kib * 1024.0
        let gib = mib * 1024.0

        if bytesPerSecond >= gib {
            return "↓ \(oneDecimal(bytesPerSecond / gib))G"
        }
        if bytesPerSecond >= mib {
            return "↓ \(oneDecimal(bytesPerSecond / mib))M"
        }
        return "↓ \(Int((bytesPerSecond / kib).rounded()))K"
    }

    static func temperature(_ celsius: Double?) -> String {
        guard let celsius, celsius.isFinite else { return "--" }
        return "\(Int(celsius.rounded()))°C"
    }

    static func chargingPower(_ watts: Double?) -> String {
        guard let watts, watts.isFinite else { return "--" }
        let rounded = Int(watts.rounded())
        if rounded > 0 { return "+\(rounded)W" }
        if rounded < 0 { return "\(rounded)W" }
        return "0W"
    }

    static func batteryLevel(_ percent: Int?) -> String {
        guard let percent else { return "--" }
        return "\(max(0, min(100, percent)))%"
    }

    static func powerState(_ state: BatterySnapshot.PowerState) -> String {
        switch state {
        case .charging: return "Charging"
        case .discharging: return "Discharging"
        case .full: return "Full"
        case .unknown: return "--"
        }
    }

    private static func oneDecimal(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded == floor(rounded) {
            return String(Int(rounded))
        }
        return String(format: "%.1f", rounded)
    }
}
```

- [ ] **Step 4: Run formatter tests**

Run:

```bash
swift test --filter MetricFormattersTests
```

Expected: all formatter tests pass.

- [ ] **Step 5: Commit formatter work**

```bash
git add Sources/FlowBar/Metrics/MetricFormatters.swift Tests/FlowBarTests/MetricFormattersTests.swift
git commit -m "feat: add metric formatters"
```

## Task 3: Network Speed Monitor

**Files:**
- Create: `Sources/FlowBar/Network/NetworkSpeedMonitor.swift`
- Create: `Sources/FlowBar/Network/SystemNetworkInterfaceProvider.swift`
- Create: `Tests/FlowBarTests/NetworkSpeedMonitorTests.swift`

- [ ] **Step 1: Write failing network monitor tests**

Create `Tests/FlowBarTests/NetworkSpeedMonitorTests.swift`:

```swift
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
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
swift test --filter NetworkSpeedMonitorTests
```

Expected: fails because network monitor types do not exist.

- [ ] **Step 3: Implement network monitor**

Create `Sources/FlowBar/Network/NetworkSpeedMonitor.swift`:

```swift
import Foundation

struct NetworkInterfaceSample: Equatable {
    var name: String
    var receivedBytes: UInt64
    var isLoopback: Bool
    var isActive: Bool
}

protocol NetworkInterfaceProviding {
    func interfaceSamples() -> [NetworkInterfaceSample]
}

final class NetworkSpeedMonitor {
    private let provider: NetworkInterfaceProviding
    private var previousBytes: UInt64?
    private var previousDate: Date?

    init(provider: NetworkInterfaceProviding = SystemNetworkInterfaceProvider()) {
        self.provider = provider
    }

    func sample(now: Date = Date()) -> Double? {
        let currentBytes = provider.interfaceSamples()
            .filter { !$0.isLoopback && $0.isActive }
            .reduce(UInt64(0)) { $0 + $1.receivedBytes }

        defer {
            previousBytes = currentBytes
            previousDate = now
        }

        guard let previousBytes, let previousDate else {
            return nil
        }

        let elapsed = now.timeIntervalSince(previousDate)
        guard elapsed > 0, currentBytes >= previousBytes else {
            return nil
        }

        return Double(currentBytes - previousBytes) / elapsed
    }
}
```

- [ ] **Step 4: Implement system interface provider**

Create `Sources/FlowBar/Network/SystemNetworkInterfaceProvider.swift`:

```swift
import Foundation

#if os(macOS)
import Darwin

final class SystemNetworkInterfaceProvider: NetworkInterfaceProviding {
    func interfaceSamples() -> [NetworkInterfaceSample] {
        var addressPointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addressPointer) == 0, let firstAddress = addressPointer else {
            return []
        }
        defer { freeifaddrs(addressPointer) }

        var samples: [NetworkInterfaceSample] = []
        var pointer: UnsafeMutablePointer<ifaddrs>? = firstAddress

        while let current = pointer {
            let interface = current.pointee
            let flags = Int32(interface.ifa_flags)
            let isUp = (flags & IFF_UP) != 0
            let isRunning = (flags & IFF_RUNNING) != 0
            let isLoopback = (flags & IFF_LOOPBACK) != 0

            if let data = interface.ifa_data,
               let namePointer = interface.ifa_name {
                let dataPointer = data.bindMemory(to: if_data.self, capacity: 1)
                let receivedBytes = UInt64(dataPointer.pointee.ifi_ibytes)
                let name = String(cString: namePointer)

                samples.append(NetworkInterfaceSample(
                    name: name,
                    receivedBytes: receivedBytes,
                    isLoopback: isLoopback,
                    isActive: isUp && isRunning
                ))
            }

            pointer = interface.ifa_next
        }

        return samples
    }
}
#endif
```

- [ ] **Step 5: Run network tests**

Run:

```bash
swift test --filter NetworkSpeedMonitorTests
```

Expected: all network monitor tests pass.

- [ ] **Step 6: Commit network monitor**

```bash
git add Sources/FlowBar/Network Tests/FlowBarTests/NetworkSpeedMonitorTests.swift
git commit -m "feat: add download speed monitor"
```

## Task 4: Battery Monitor

**Files:**
- Create: `Sources/FlowBar/Battery/BatteryMonitor.swift`
- Create: `Sources/FlowBar/Battery/IOKitBatteryProvider.swift`
- Create: `Tests/FlowBarTests/BatteryMonitorTests.swift`

- [ ] **Step 1: Write failing battery monitor tests**

Create `Tests/FlowBarTests/BatteryMonitorTests.swift`:

```swift
import XCTest
@testable import FlowBar

final class BatteryMonitorTests: XCTestCase {
    func testCalculatesChargingWattsFromMillivoltsAndMilliamps() {
        let monitor = BatteryMonitor(provider: FakeBatteryProvider(values: [
            "Temperature": 3042,
            "Voltage": 12000,
            "Amperage": 1500,
            "CurrentCapacity": 83,
            "IsCharging": true
        ]))

        let snapshot = monitor.snapshot()

        XCTAssertEqual(snapshot.temperatureCelsius, 30.42, accuracy: 0.001)
        XCTAssertEqual(snapshot.chargingWatts, 18.0, accuracy: 0.001)
        XCTAssertEqual(snapshot.levelPercent, 83)
        XCTAssertEqual(snapshot.powerState, .charging)
    }

    func testCalculatesDischargingWatts() {
        let monitor = BatteryMonitor(provider: FakeBatteryProvider(values: [
            "Voltage": 12000,
            "Amperage": -500,
            "CurrentCapacity": 66,
            "IsCharging": false
        ]))

        let snapshot = monitor.snapshot()

        XCTAssertEqual(snapshot.chargingWatts, -6.0, accuracy: 0.001)
        XCTAssertEqual(snapshot.levelPercent, 66)
        XCTAssertEqual(snapshot.powerState, .discharging)
    }

    func testUnavailableFieldsStayNil() {
        let monitor = BatteryMonitor(provider: FakeBatteryProvider(values: [:]))

        XCTAssertEqual(monitor.snapshot(), .unavailable)
    }
}

private struct FakeBatteryProvider: BatteryInfoProviding {
    var values: [String: Any]

    func batteryInfo() -> [String: Any] {
        values
    }
}
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
swift test --filter BatteryMonitorTests
```

Expected: fails because battery monitor types do not exist.

- [ ] **Step 3: Implement battery monitor parser**

Create `Sources/FlowBar/Battery/BatteryMonitor.swift`:

```swift
import Foundation

protocol BatteryInfoProviding {
    func batteryInfo() -> [String: Any]
}

final class BatteryMonitor {
    private let provider: BatteryInfoProviding

    init(provider: BatteryInfoProviding = IOKitBatteryProvider()) {
        self.provider = provider
    }

    func snapshot() -> BatterySnapshot {
        let values = provider.batteryInfo()
        guard !values.isEmpty else {
            return .unavailable
        }

        let temperature = intValue(values["Temperature"]).map { Double($0) / 100.0 }
        let voltageMillivolts = intValue(values["Voltage"])
        let amperageMilliamps = intValue(values["Amperage"])
        let watts = Self.watts(voltageMillivolts: voltageMillivolts, amperageMilliamps: amperageMilliamps)
        let level = intValue(values["CurrentCapacity"])
        let isCharging = boolValue(values["IsCharging"])

        return BatterySnapshot(
            temperatureCelsius: temperature,
            chargingWatts: watts,
            levelPercent: level,
            powerState: powerState(isCharging: isCharging, watts: watts)
        )
    }

    private static func watts(voltageMillivolts: Int?, amperageMilliamps: Int?) -> Double? {
        guard let voltageMillivolts, let amperageMilliamps else {
            return nil
        }
        return (Double(voltageMillivolts) / 1000.0) * (Double(amperageMilliamps) / 1000.0)
    }

    private func powerState(isCharging: Bool?, watts: Double?) -> BatterySnapshot.PowerState {
        if isCharging == true {
            return .charging
        }
        if isCharging == false {
            return .discharging
        }
        if let watts, watts > 0 {
            return .charging
        }
        if let watts, watts < 0 {
            return .discharging
        }
        return .unknown
    }

    private func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? Int32 { return Int(value) }
        if let value = value as? Int64 { return Int(value) }
        if let value = value as? NSNumber { return value.intValue }
        return nil
    }

    private func boolValue(_ value: Any?) -> Bool? {
        if let value = value as? Bool { return value }
        if let value = value as? NSNumber { return value.boolValue }
        return nil
    }
}
```

- [ ] **Step 4: Implement IOKit battery provider**

Create `Sources/FlowBar/Battery/IOKitBatteryProvider.swift`:

```swift
import Foundation
import IOKit.ps

final class IOKitBatteryProvider: BatteryInfoProviding {
    func batteryInfo() -> [String: Any] {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return [:]
        }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
                  description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType else {
                continue
            }
            return description
        }

        return [:]
    }
}
```

- [ ] **Step 5: Run battery tests**

Run:

```bash
swift test --filter BatteryMonitorTests
```

Expected: all battery monitor tests pass.

- [ ] **Step 6: Commit battery monitor**

```bash
git add Sources/FlowBar/Battery Tests/FlowBarTests/BatteryMonitorTests.swift
git commit -m "feat: add battery monitor"
```

## Task 5: Metrics Sampler

**Files:**
- Create: `Sources/FlowBar/Metrics/MetricsSampler.swift`
- Create: `Tests/FlowBarTests/MetricsSamplerTests.swift`

- [ ] **Step 1: Write failing sampler tests**

Create `Tests/FlowBarTests/MetricsSamplerTests.swift`:

```swift
import XCTest
@testable import FlowBar

final class MetricsSamplerTests: XCTestCase {
    func testCombinesNetworkAndBatterySnapshots() {
        let sampler = MetricsSampler(
            networkSpeed: FakeNetworkSpeedSampling(value: 2048),
            battery: FakeBatterySampling(value: BatterySnapshot(
                temperatureCelsius: 38,
                chargingWatts: 18,
                levelPercent: 80,
                powerState: .charging
            ))
        )

        let snapshot = sampler.snapshot()

        XCTAssertEqual(snapshot.downloadBytesPerSecond, 2048)
        XCTAssertEqual(snapshot.battery.temperatureCelsius, 38)
        XCTAssertEqual(snapshot.battery.chargingWatts, 18)
        XCTAssertEqual(snapshot.battery.levelPercent, 80)
        XCTAssertEqual(snapshot.battery.powerState, .charging)
    }
}

private struct FakeNetworkSpeedSampling: NetworkSpeedSampling {
    var value: Double?
    func sample(now: Date) -> Double? { value }
}

private struct FakeBatterySampling: BatterySampling {
    var value: BatterySnapshot
    func snapshot() -> BatterySnapshot { value }
}
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
swift test --filter MetricsSamplerTests
```

Expected: fails because sampler protocols do not exist.

- [ ] **Step 3: Add sampling protocols and sampler**

Create `Sources/FlowBar/Metrics/MetricsSampler.swift`:

```swift
import Foundation

protocol NetworkSpeedSampling {
    func sample(now: Date) -> Double?
}

protocol BatterySampling {
    func snapshot() -> BatterySnapshot
}

extension NetworkSpeedMonitor: NetworkSpeedSampling {}
extension BatteryMonitor: BatterySampling {}

final class MetricsSampler {
    private let networkSpeed: NetworkSpeedSampling
    private let battery: BatterySampling

    init(
        networkSpeed: NetworkSpeedSampling = NetworkSpeedMonitor(),
        battery: BatterySampling = BatteryMonitor()
    ) {
        self.networkSpeed = networkSpeed
        self.battery = battery
    }

    func snapshot(now: Date = Date()) -> MetricsSnapshot {
        MetricsSnapshot(
            downloadBytesPerSecond: networkSpeed.sample(now: now),
            battery: battery.snapshot()
        )
    }
}
```

- [ ] **Step 4: Run sampler tests**

Run:

```bash
swift test --filter MetricsSamplerTests
```

Expected: all sampler tests pass.

- [ ] **Step 5: Run all tests**

Run:

```bash
swift test
```

Expected: all tests pass.

- [ ] **Step 6: Commit sampler**

```bash
git add Sources/FlowBar/Metrics/MetricsSampler.swift Tests/FlowBarTests/MetricsSamplerTests.swift
git commit -m "feat: add metrics sampler"
```

## Task 6: Status Bar and Popover UI

**Files:**
- Modify: `Sources/FlowBar/App/StatusBarController.swift`
- Create: `Sources/FlowBar/App/BatteryPopoverViewController.swift`

- [ ] **Step 1: Replace status controller with timer-driven implementation**

Modify `Sources/FlowBar/App/StatusBarController.swift`:

```swift
import AppKit

final class StatusBarController {
    private let statusItem: NSStatusItem
    private let sampler: MetricsSampler
    private let popover: NSPopover
    private var timer: Timer?
    private var latestSnapshot: MetricsSnapshot = .unavailable

    init(sampler: MetricsSampler = MetricsSampler()) {
        self.sampler = sampler
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()
        configureStatusItem()
        configurePopover()
        refresh()
        startTimer()
    }

    deinit {
        timer?.invalidate()
    }

    private func configureStatusItem() {
        statusItem.button?.title = "↓ --"
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 240, height: 190)
        popover.contentViewController = BatteryPopoverViewController(snapshot: latestSnapshot)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func refresh() {
        latestSnapshot = sampler.snapshot()
        statusItem.button?.title = MetricFormatters.downloadSpeed(latestSnapshot.downloadBytesPerSecond)
        if let viewController = popover.contentViewController as? BatteryPopoverViewController {
            viewController.update(snapshot: latestSnapshot)
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        refresh()
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
```

- [ ] **Step 2: Create popover view controller**

Create `Sources/FlowBar/App/BatteryPopoverViewController.swift`:

```swift
import AppKit

final class BatteryPopoverViewController: NSViewController {
    private let downloadValue = NSTextField(labelWithString: "--")
    private let temperatureValue = NSTextField(labelWithString: "--")
    private let powerValue = NSTextField(labelWithString: "--")
    private let levelValue = NSTextField(labelWithString: "--")
    private let stateValue = NSTextField(labelWithString: "--")
    private let launchAtLoginSwitch = NSSwitch()
    private let launchAtLoginController = LaunchAtLoginController()

    init(snapshot: MetricsSnapshot) {
        super.init(nibName: nil, bundle: nil)
        update(snapshot: snapshot)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 10
        root.edgeInsets = NSEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        root.translatesAutoresizingMaskIntoConstraints = false

        root.addArrangedSubview(row("Download", downloadValue))
        root.addArrangedSubview(row("Battery Temp", temperatureValue))
        root.addArrangedSubview(row("Power", powerValue))
        root.addArrangedSubview(row("Battery", levelValue))
        root.addArrangedSubview(row("State", stateValue))
        root.addArrangedSubview(separator())
        root.addArrangedSubview(launchAtLoginRow())

        view = NSView()
        view.addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            root.topAnchor.constraint(equalTo: view.topAnchor),
            root.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        launchAtLoginSwitch.state = launchAtLoginController.isEnabled ? .on : .off
    }

    func update(snapshot: MetricsSnapshot) {
        downloadValue.stringValue = MetricFormatters.downloadSpeed(snapshot.downloadBytesPerSecond)
        temperatureValue.stringValue = MetricFormatters.temperature(snapshot.battery.temperatureCelsius)
        powerValue.stringValue = MetricFormatters.chargingPower(snapshot.battery.chargingWatts)
        levelValue.stringValue = MetricFormatters.batteryLevel(snapshot.battery.levelPercent)
        stateValue.stringValue = MetricFormatters.powerState(snapshot.battery.powerState)
    }

    private func row(_ title: String, _ value: NSTextField) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.textColor = .secondaryLabelColor

        value.alignment = .right
        value.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)

        let stack = NSStackView(views: [label, value])
        stack.orientation = .horizontal
        stack.distribution = .fillEqually
        return stack
    }

    private func separator() -> NSView {
        let box = NSBox()
        box.boxType = .separator
        return box
    }

    private func launchAtLoginRow() -> NSView {
        let label = NSTextField(labelWithString: "Launch at Login")
        label.textColor = .secondaryLabelColor
        launchAtLoginSwitch.target = self
        launchAtLoginSwitch.action = #selector(toggleLaunchAtLogin)

        let stack = NSStackView(views: [label, launchAtLoginSwitch])
        stack.orientation = .horizontal
        stack.distribution = .fill
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        launchAtLoginSwitch.setContentHuggingPriority(.required, for: .horizontal)
        return stack
    }

    @objc private func toggleLaunchAtLogin() {
        launchAtLoginController.setEnabled(launchAtLoginSwitch.state == .on)
        launchAtLoginSwitch.state = launchAtLoginController.isEnabled ? .on : .off
    }
}
```

- [ ] **Step 3: Add launch-at-login stub so UI compiles**

Create `Sources/FlowBar/App/LaunchAtLoginController.swift`:

```swift
import Foundation

final class LaunchAtLoginController {
    var isEnabled: Bool {
        false
    }

    func setEnabled(_ enabled: Bool) {
    }
}
```

- [ ] **Step 4: Build and test UI compilation**

Run:

```bash
swift test
swift build
```

Expected: tests and build pass.

- [ ] **Step 5: Commit UI shell**

```bash
git add Sources/FlowBar/App
git commit -m "feat: add menu bar popover UI"
```

## Task 7: Launch at Login

**Files:**
- Modify: `Sources/FlowBar/App/LaunchAtLoginController.swift`

- [ ] **Step 1: Implement ServiceManagement integration**

Modify `Sources/FlowBar/App/LaunchAtLoginController.swift`:

```swift
import Foundation
import ServiceManagement

final class LaunchAtLoginController {
    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            NSLog("FlowBar launch-at-login update failed: \(error.localizedDescription)")
        }
    }
}
```

- [ ] **Step 2: Build to verify ServiceManagement usage**

Run:

```bash
swift build
```

Expected: build succeeds.

- [ ] **Step 3: Commit launch-at-login integration**

```bash
git add Sources/FlowBar/App/LaunchAtLoginController.swift
git commit -m "feat: add launch at login controller"
```

## Task 8: Local `.app` Bundle

**Files:**
- Create: `Resources/Info.plist`
- Create: `Scripts/build-app.sh`
- Modify: `.gitignore`

- [ ] **Step 1: Create app Info.plist**

Create `Resources/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>FlowBar</string>
    <key>CFBundleIdentifier</key>
    <string>dev.local.FlowBar</string>
    <key>CFBundleName</key>
    <string>FlowBar</string>
    <key>CFBundleDisplayName</key>
    <string>FlowBar</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
```

- [ ] **Step 2: Create bundle build script**

Create `Scripts/build-app.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${1:-release}"
APP_DIR="$ROOT_DIR/.build/FlowBar.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"

swift build -c "$CONFIGURATION"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
cp "$ROOT_DIR/.build/$CONFIGURATION/FlowBar" "$MACOS_DIR/FlowBar"
cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"

echo "$APP_DIR"
```

- [ ] **Step 3: Make script executable and ignore generated app**

Run:

```bash
chmod +x Scripts/build-app.sh
```

Modify `.gitignore`:

```gitignore
.superpowers/
.build/
```

- [ ] **Step 4: Build app bundle**

Run:

```bash
Scripts/build-app.sh
```

Expected: command prints `.build/FlowBar.app` path and exits successfully.

- [ ] **Step 5: Commit app bundle tooling**

```bash
git add .gitignore Resources/Info.plist Scripts/build-app.sh
git commit -m "chore: add local app bundle build"
```

## Task 9: README and Manual Verification

**Files:**
- Create: `README.md`

- [ ] **Step 1: Create README**

Create `README.md`:

```markdown
# FlowBar

FlowBar is a lightweight macOS 13+ menu bar app that shows current download speed in the status bar and current battery details in a small popover.

## Build

```bash
swift test
Scripts/build-app.sh
```

The app bundle is created at:

```text
.build/FlowBar.app
```

## Run

```bash
open .build/FlowBar.app
```

FlowBar is menu-bar-only and should not appear in the Dock.

## Version 1 Scope

- Shows download speed in the status bar.
- Refreshes every 2 seconds.
- Shows battery temperature, charging power, battery level, and charging state in the popover.
- Includes a minimal Launch at Login toggle.
- Does not show upload speed.
- Does not store metric history.
- Does not use third-party sensor tools.

## Manual Verification

- Start FlowBar and confirm a `↓` speed appears in the menu bar.
- Generate network download activity and confirm the menu bar value changes.
- Stop network activity and confirm the value returns to a low or zero speed.
- Click the menu bar item and confirm the popover opens.
- Confirm unavailable battery fields show `--` without breaking other fields.
- Connect and disconnect power and confirm charging state changes if macOS exposes it.
- Toggle Launch at Login on and off.
- Confirm FlowBar does not appear in the Dock.
```

- [ ] **Step 2: Run full verification commands**

Run:

```bash
swift test
Scripts/build-app.sh
```

Expected: tests pass and app bundle builds.

- [ ] **Step 3: Commit README**

```bash
git add README.md
git commit -m "docs: add FlowBar build instructions"
```

## Task 10: Final Manual Smoke Test

**Files:**
- No source files expected.

- [ ] **Step 1: Build release app**

Run:

```bash
Scripts/build-app.sh
```

Expected: `.build/FlowBar.app` is created.

- [ ] **Step 2: Launch app manually**

Run:

```bash
open .build/FlowBar.app
```

Expected: FlowBar appears in the menu bar and does not appear in the Dock.

- [ ] **Step 3: Exercise popover**

Click the FlowBar menu bar item.

Expected: popover opens and shows download speed, battery temperature or `--`, charging power or `--`, battery level or `--`, state, and Launch at Login toggle.

- [ ] **Step 4: Check final status**

Run:

```bash
git status --short
```

Expected: no uncommitted source changes except ignored `.build/` artifacts.

## Self-Review

Spec coverage:

- Menu bar download speed: Tasks 2, 3, 5, and 6.
- 2-second refresh: Task 6.
- Battery temperature, charging power, level, and state: Tasks 2, 4, 5, and 6.
- AppKit, no Electron/WebView/third-party tools: Tasks 1, 6, and 8.
- No Dock icon: Tasks 1 and 8.
- Launch at Login toggle: Tasks 6 and 7.
- Local developer `.app`: Task 8.
- Manual verification: Tasks 9 and 10.

Placeholder scan: no placeholder markers or deferred implementation notes remain.

Type consistency: `MetricsSnapshot`, `BatterySnapshot`, `MetricFormatters`, `NetworkSpeedMonitor`, `BatteryMonitor`, `MetricsSampler`, `StatusBarController`, `BatteryPopoverViewController`, and `LaunchAtLoginController` names are consistent across tasks.
