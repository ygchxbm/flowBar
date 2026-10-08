import Foundation
import IOKit.ps

/// Supplies raw system fields, optionally including AppleSmartBatteryPack data.
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
        guard !values.isEmpty,
              BatteryNumericValue.bool(values["BatteryInstalled"]) != false,
              BatteryNumericValue.bool(values["Is Present"]) != false else {
            return .unavailable
        }

        // Select the raw alias before conversion: an invalid alias still replaces
        // the registry key, matching the precedence of IOPS descriptions.
        func value(_ key: String, overriddenBy alias: String) -> Any? { values[alias] ?? values[key] }
        let voltageMillivolts = BatteryNumericValue.integer(values["Voltage"])
        let amperageMilliamps = BatteryNumericValue.integer(value("Amperage", overriddenBy: "Current"))
        let watts = Self.watts(voltageMillivolts: voltageMillivolts, amperageMilliamps: amperageMilliamps)
        let level = levelPercent(
            current: value("CurrentCapacity", overriddenBy: "Current Capacity"),
            maximum: value("MaxCapacity", overriddenBy: "Max Capacity")
        )
        let isCharging = BatteryNumericValue.bool(value("IsCharging", overriddenBy: "Is Charging"))
        let isFull = BatteryNumericValue.bool(value("IsCharged", overriddenBy: "Is Charged"))
            ?? BatteryNumericValue.bool(values["FullyCharged"])
        let externalConnected = (values[kIOPSPowerSourceStateKey] as? String).map { $0 == kIOPSACPowerValue }
            ?? BatteryNumericValue.bool(values["ExternalConnected"])
            ?? BatteryNumericValue.bool(values["AppleRawExternalConnected"])

        return BatterySnapshot(
            temperatureCelsius: BatteryTemperature.celsius(from: values),
            chargingWatts: watts,
            levelPercent: level,
            powerState: powerState(
                isCharging: isCharging,
                isFull: isFull,
                externalConnected: externalConnected,
                watts: watts
            )
        )
    }

    private static func watts(voltageMillivolts: Int?, amperageMilliamps: Int?) -> Double? {
        guard let voltageMillivolts, voltageMillivolts > 0, let amperageMilliamps else {
            return nil
        }
        return (Double(voltageMillivolts) / 1000.0) * (Double(amperageMilliamps) / 1000.0)
    }

    private func levelPercent(current rawCurrent: Any?, maximum rawMaximum: Any?) -> Int? {
        guard let current = BatteryNumericValue.integer(rawCurrent),
              current >= 0 else { return nil }
        if let rawMaximum {
            guard let maximum = BatteryNumericValue.integer(rawMaximum), maximum > 0 else { return nil }
            // Registry capacity can be mAh; IOPS normally supplies current / 100 instead.
            let percent = min(100, Double(current) / Double(maximum) * 100)
            return Int(percent.rounded())
        }
        // Older providers already return a percentage without a matching maximum.
        return current <= 100 ? current : nil
    }

    private func powerState(
        isCharging: Bool?,
        isFull: Bool?,
        externalConnected: Bool?,
        watts: Double?
    ) -> BatterySnapshot.PowerState {
        if isFull == true {
            return .full
        }
        if isCharging == true {
            return .charging
        }
        if externalConnected == true {
            return .externalPower
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
}

/// Shared with the provider only to decide whether another registry read is needed.
enum BatteryTemperature {
    static func primaryCelsius(from values: [String: Any]) -> Double? {
        if let normalized = BatteryNumericValue.double(values["TemperatureCelsius"]) {
            return normalized
        }
        if let celsius = BatteryNumericValue.double(values["Temperature Celsius"]) {
            return celsius
        }
        if let temperature = BatteryNumericValue.double(values["Temperature"]) {
            return abs(temperature) > 1000 ? (temperature / 10.0) - 273.15 : temperature
        }
        return nil
    }

    static func celsius(from values: [String: Any]) -> Double? {
        if let temperature = primaryCelsius(from: values) { return temperature }
        guard let pack = values["AppleSmartBatteryPack"] as? [String: Any],
              let batteryData = pack["BatteryData"] as? [String: Any],
              let temperature = BatteryNumericValue.double(batteryData["Temperature"]) else { return nil }
        return temperature / 100.0
    }
}
