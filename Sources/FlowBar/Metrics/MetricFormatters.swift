import Foundation

enum MetricFormatters {
    static func downloadSpeed(_ bytesPerSecond: Double?) -> String {
        guard let bytesPerSecond, bytesPerSecond.isFinite, bytesPerSecond >= 0 else {
            return "↓ --"
        }

        let kib = 1024.0

        let roundedKib = Int((bytesPerSecond / kib).rounded())
        if roundedKib >= 1024 * 1024 {
            return "↓ \(oneDecimal(Double(roundedKib) / (1024 * 1024)))G"
        }
        if roundedKib >= 1024 {
            return "↓ \(oneDecimal(Double(roundedKib) / 1024))M"
        }
        return "↓ \(roundedKib)K"
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
        case .charging: return "充电中"
        case .externalPower: return "接入电源"
        case .discharging: return "使用电池"
        case .full: return "已充满"
        case .unknown: return "--"
        }
    }

    private static func oneDecimal(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded == floor(rounded) {
            return String(Int(rounded))
        }
        return String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), rounded)
    }
}
