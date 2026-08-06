import Foundation
import IOKit
import IOKit.ps

final class IOKitBatteryProvider: BatteryInfoProviding {
    func batteryInfo() -> [String: Any] {
        if var smartBatteryInfo = appleSmartBatteryInfo() {
            if let smartBatteryPackInfo = appleSmartBatteryPackInfo() {
                smartBatteryInfo["AppleSmartBatteryPack"] = smartBatteryPackInfo
            }
            return Self.normalized(smartBatteryInfo)
        }

        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return [:]
        }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?
                .takeUnretainedValue() as? [String: Any],
                description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType else {
                continue
            }
            return Self.normalized(description)
        }

        return [:]
    }

    private func appleSmartBatteryInfo() -> [String: Any]? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        return registryProperties(for: service)
    }

    private func appleSmartBatteryPackInfo() -> [String: Any]? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBatteryPack"))
        return registryProperties(for: service)
    }

    private func registryProperties(for service: io_service_t) -> [String: Any]? {
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

    static func normalized(_ description: [String: Any]) -> [String: Any] {
        var values = description

        if let current = description["Current"] {
            values["Amperage"] = current
        }
        if let currentCapacity = description["Current Capacity"] {
            values["CurrentCapacity"] = currentCapacity
        }
        if let isCharging = description["Is Charging"] {
            values["IsCharging"] = isCharging
        }
        if let isCharged = description["Is Charged"] {
            values["IsCharged"] = isCharged
        }
        if let powerSourceState = description[kIOPSPowerSourceStateKey] as? String {
            values["ExternalConnected"] = powerSourceState == kIOPSACPowerValue
        }
        if let temperature = doubleValue(description["Temperature"]) {
            values["TemperatureCelsius"] = BatteryMonitor.normalizedTemperatureCelsius(temperature)
        } else if let pack = description["AppleSmartBatteryPack"] as? [String: Any],
                  let batteryData = pack["BatteryData"] as? [String: Any],
                  let temperature = doubleValue(batteryData["Temperature"]) {
            values["TemperatureCelsius"] = temperature / 100.0
        }

        return values
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? Float { return Double(value) }
        if let value = value as? Int { return Double(value) }
        if let value = value as? Int32 { return Double(value) }
        if let value = value as? Int64 { return Double(value) }
        if let value = value as? NSNumber { return value.doubleValue }
        return nil
    }
}
