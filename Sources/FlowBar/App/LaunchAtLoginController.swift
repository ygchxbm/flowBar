import Foundation
import ServiceManagement

final class LaunchAtLoginController {
    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        let service = SMAppService.mainApp
        let currentlyEnabled = service.status == .enabled

        do {
            if enabled && !currentlyEnabled {
                try service.register()
            } else if !enabled && currentlyEnabled {
                try service.unregister()
            }
        } catch {
            NSLog("Failed to %@ launch at login: %@", enabled ? "enable" : "disable", error.localizedDescription)
        }
    }
}
