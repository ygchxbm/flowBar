import AppKit

@main
final class FlowBarApp: NSObject, NSApplicationDelegate {
    private static let sharedDelegate = FlowBarApp()

    private var statusBarController: StatusBarController?

    static func main() {
        let app = NSApplication.shared
        app.delegate = sharedDelegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController()
    }
}
