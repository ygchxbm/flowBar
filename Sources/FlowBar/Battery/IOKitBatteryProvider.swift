import Foundation
import IOKit
import IOKit.ps

final class IOKitBatteryProvider: BatteryInfoProviding {
    private let readRegistry: (String) -> [String: Any]?

    init(readRegistry: @escaping (String) -> [String: Any]? = IOKitBatteryProvider.registryProperties) {
        self.readRegistry = readRegistry
    }

    func batteryInfo() -> [String: Any] {
        if var smartBatteryInfo = readRegistry("AppleSmartBattery") {
            guard Self.isPresent(smartBatteryInfo) else { return [:] }
            if BatteryTemperature.primaryCelsius(from: smartBatteryInfo) == nil,
               let smartBatteryPackInfo = readRegistry("AppleSmartBatteryPack") {
                smartBatteryInfo["AppleSmartBatteryPack"] = smartBatteryPackInfo
            }
            return smartBatteryInfo
        }

        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return [:]
        }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?
                .takeUnretainedValue() as? [String: Any],
                description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                Self.isPresent(description) else {
                continue
            }
            return description
        }

        return [:]
    }

    private static func registryProperties(matching serviceName: String) -> [String: Any]? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(serviceName))
        guard service != 0 else {
            return nil
        }
        defer { IOObjectRelease(service) }

        var properties: Unmanaged<CFMutableDictionary>?
        let result = IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0)
        guard result == KERN_SUCCESS,
              let dictionary = properties?.takeRetainedValue() as? [String: Any] else {
            return nil
        }

        return dictionary
    }

    private static func isPresent(_ description: [String: Any]) -> Bool {
        BatteryNumericValue.bool(description["BatteryInstalled"]) != false
            && BatteryNumericValue.bool(description[kIOPSIsPresentKey]) != false
    }
}
