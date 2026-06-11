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

        let temperature = temperatureCelsius(from: values)
        let voltageMillivolts = firstIntValue(in: values, keys: ["Voltage"])
        let amperageMilliamps = firstIntValue(in: values, keys: ["Amperage", "Current"])
        let watts = Self.watts(voltageMillivolts: voltageMillivolts, amperageMilliamps: amperageMilliamps)
        let level = firstIntValue(in: values, keys: ["CurrentCapacity", "Current Capacity"])
        let isCharging = firstBoolValue(in: values, keys: ["IsCharging", "Is Charging"])
        let isFull = firstBoolValue(in: values, keys: ["IsCharged", "Is Charged", "FullyCharged"])

        return BatterySnapshot(
            temperatureCelsius: temperature,
            chargingWatts: watts,
            levelPercent: level,
            powerState: powerState(isCharging: isCharging, isFull: isFull, watts: watts)
        )
    }

    private static func watts(voltageMillivolts: Int?, amperageMilliamps: Int?) -> Double? {
        guard let voltageMillivolts, let amperageMilliamps else {
            return nil
        }
        return (Double(voltageMillivolts) / 1000.0) * (Double(amperageMilliamps) / 1000.0)
    }

    private func powerState(isCharging: Bool?, isFull: Bool?, watts: Double?) -> BatterySnapshot.PowerState {
        if isFull == true {
            return .full
        }
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

    private func temperatureCelsius(from values: [String: Any]) -> Double? {
        if let normalized = doubleValue(values["TemperatureCelsius"]) {
            return normalized
        }
        if let celsius = doubleValue(values["Temperature Celsius"]) {
            return celsius
        }
        if let temperature = doubleValue(values["Temperature"]) {
            return Self.normalizedTemperatureCelsius(temperature)
        }
        return nil
    }

    static func normalizedTemperatureCelsius(_ temperature: Double) -> Double {
        if abs(temperature) > 200 {
            return temperature / 100.0
        }
        return temperature
    }

    private func firstIntValue(in values: [String: Any], keys: [String]) -> Int? {
        for key in keys {
            if let value = intValue(values[key]) {
                return value
            }
        }
        return nil
    }

    private func firstBoolValue(in values: [String: Any], keys: [String]) -> Bool? {
        for key in keys {
            if let value = boolValue(values[key]) {
                return value
            }
        }
        return nil
    }

    private func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? Int32 { return Int(value) }
        if let value = value as? Int64 { return Int(value) }
        if let value = value as? NSNumber { return value.intValue }
        return nil
    }

    private func doubleValue(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? Float { return Double(value) }
        if let value = value as? Int { return Double(value) }
        if let value = value as? Int32 { return Double(value) }
        if let value = value as? Int64 { return Double(value) }
        if let value = value as? NSNumber { return value.doubleValue }
        return nil
    }

    private func boolValue(_ value: Any?) -> Bool? {
        if let value = value as? Bool { return value }
        if let value = value as? NSNumber { return value.boolValue }
        return nil
    }
}
