import Foundation

enum MenuBarMetric: String, CaseIterable {
    case download, upload, temperature, power, level, powerState

    var title: String {
        switch self {
        case .download: return "下载速度"
        case .upload: return "上传速度"
        case .temperature: return "电池温度"
        case .power: return "电池功率"
        case .level: return "电池电量"
        case .powerState: return "电源状态"
        }
    }

    var symbol: String {
        switch self {
        case .download: return "arrow.down.circle"
        case .upload: return "arrow.up.circle"
        case .temperature: return "thermometer"
        case .power: return "bolt.fill"
        case .level: return "battery.75"
        case .powerState: return "powerplug"
        }
    }

    var index: Int { Self.allCases.firstIndex(of: self)! }

    func moved(by offset: Int) -> Self {
        let count = Self.allCases.count
        return Self.allCases[(index + offset % count + count) % count]
    }

    func detailFormatted(_ snapshot: MetricsSnapshot) -> String {
        switch self {
        case .temperature: return MetricFormatters.detailedTemperature(snapshot.battery.temperatureCelsius)
        case .power: return MetricFormatters.detailedBatteryPower(snapshot.battery.chargingWatts)
        default: return formatted(snapshot)
        }
    }

    func formatted(_ snapshot: MetricsSnapshot) -> String {
        switch self {
        case .download: return MetricFormatters.downloadSpeed(snapshot.downloadBytesPerSecond)
        case .upload: return MetricFormatters.uploadSpeed(snapshot.uploadBytesPerSecond)
        case .temperature: return MetricFormatters.temperature(snapshot.battery.temperatureCelsius)
        case .power: return MetricFormatters.chargingPower(snapshot.battery.chargingWatts)
        case .level: return MetricFormatters.batteryLevel(snapshot.battery.levelPercent)
        case .powerState: return MetricFormatters.powerState(snapshot.battery.powerState)
        }
    }
}

final class MenuBarSelection {
    private let defaults: UserDefaults
    private let key = "menuBarMetric"
    var metric: MenuBarMetric {
        didSet { defaults.set(metric.rawValue, forKey: key) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        metric = defaults.string(forKey: key).flatMap(MenuBarMetric.init(rawValue:)) ?? .download
    }
}
