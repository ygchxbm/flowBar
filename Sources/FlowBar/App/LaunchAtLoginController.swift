import Foundation
import ServiceManagement

@MainActor
protocol LaunchAtLoginServicing {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
    func openSettings()
}

private struct SystemLaunchAtLoginService: LaunchAtLoginServicing {
    var status: SMAppService.Status { SMAppService.mainApp.status }
    func register() throws { try SMAppService.mainApp.register() }
    func unregister() throws { try SMAppService.mainApp.unregister() }
    func openSettings() { SMAppService.openSystemSettingsLoginItems() }
}

struct LaunchAtLoginUpdateResult {
    let status: SMAppService.Status
    let errorMessage: String?
}

@MainActor
final class LaunchAtLoginController {
    private let service: LaunchAtLoginServicing

    init(service: LaunchAtLoginServicing? = nil) {
        self.service = service ?? SystemLaunchAtLoginService()
    }

    var isEnabled: Bool { service.status == .enabled }

    func setEnabled(_ enabled: Bool) -> LaunchAtLoginUpdateResult {
        let currentStatus = service.status
        do {
            if enabled && currentStatus != .enabled && currentStatus != .requiresApproval {
                try service.register()
            } else if !enabled && (currentStatus == .enabled || currentStatus == .requiresApproval) {
                try service.unregister()
            }
            return LaunchAtLoginUpdateResult(status: service.status, errorMessage: nil)
        } catch {
            NSLog("Failed to %@ launch at login: %@", enabled ? "enable" : "disable", error.localizedDescription)
            return LaunchAtLoginUpdateResult(status: service.status, errorMessage: error.localizedDescription)
        }
    }

    func openSettings() {
        service.openSettings()
    }
}
