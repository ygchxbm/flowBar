import AppKit
import Combine

enum LaunchAtLoginNotice: Equatable {
    case requiresApproval
    case failed(String)
}

@MainActor
final class FlowBarPopoverViewModel: ObservableObject {
    @Published var selectedMetric: MenuBarMetric = .download
    @Published private(set) var rows: [FlowBarMetricRow] = []
    @Published private(set) var launchAtLoginEnabled: Bool
    var onMetricChange: ((MenuBarMetric) -> Void)?
    var onLaunchAtLoginNotice: ((LaunchAtLoginNotice) -> Void)?

    private let launchAtLoginController: LaunchAtLoginController

    init(launchAtLoginController: LaunchAtLoginController) {
        self.launchAtLoginController = launchAtLoginController
        launchAtLoginEnabled = launchAtLoginController.isEnabled
        update(snapshot: .unavailable)
    }

    func cycleMetric(by offset: Int) {
        selectedMetric = selectedMetric.moved(by: offset)
        onMetricChange?(selectedMetric)
    }

    func update(snapshot: MetricsSnapshot) {
        let updatedRows = MenuBarMetric.allCases.map { metric in
            FlowBarMetricRow(metric: metric, value: metric.detailFormatted(snapshot))
        }
        // Sampling can change without changing any displayed, rounded value.
        if rows != updatedRows {
            rows = updatedRows
        }
    }

    func refreshLaunchAtLogin() {
        updateLaunchAtLoginEnabled(launchAtLoginController.isEnabled)
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        let result = launchAtLoginController.setEnabled(enabled)
        updateLaunchAtLoginEnabled(result.status == .enabled)
        // Registration can throw when consent is denied while still leaving a
        // registered service that requires approval in System Settings.
        if enabled && result.status == .requiresApproval {
            onLaunchAtLoginNotice?(.requiresApproval)
        } else if let errorMessage = result.errorMessage {
            onLaunchAtLoginNotice?(.failed(errorMessage))
        }
    }

    func openLoginItemSettings() {
        launchAtLoginController.openSettings()
    }

    func quit() {
        NSApp.terminate(nil)
    }

    private func updateLaunchAtLoginEnabled(_ enabled: Bool) {
        if launchAtLoginEnabled != enabled {
            launchAtLoginEnabled = enabled
        }
    }
}

struct FlowBarMetricRow: Identifiable, Equatable {
    let metric: MenuBarMetric
    let value: String

    var id: MenuBarMetric { metric }
}
