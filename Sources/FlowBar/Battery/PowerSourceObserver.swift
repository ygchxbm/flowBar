import Foundation
import IOKit.ps

/// Delivers system power-source changes on the main run loop.
final class PowerSourceObserver {
    private var sources: [CFRunLoopSource] = []
    private let onChange: () -> Void

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
        let context = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOPowerSourceCallbackType = { context in
            guard let context else { return }
            Unmanaged<PowerSourceObserver>.fromOpaque(context).takeUnretainedValue().onChange()
        }
        // Battery information updates and AC/DC transitions are distinct notifications.
        if let source = IOPSNotificationCreateRunLoopSource(callback, context)?.takeRetainedValue() {
            sources.append(source)
        }
        if let source = IOPSCreateLimitedPowerNotification(callback, context)?.takeRetainedValue() {
            sources.append(source)
        }
        for source in sources {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }
    }

    deinit {
        for source in sources {
            CFRunLoopSourceInvalidate(source)
        }
    }
}
