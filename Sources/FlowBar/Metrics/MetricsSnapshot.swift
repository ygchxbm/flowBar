import Foundation

struct MetricsSnapshot: Equatable {
    var downloadBytesPerSecond: Double?
    var battery: BatterySnapshot

    static let unavailable = MetricsSnapshot(
        downloadBytesPerSecond: nil,
        battery: .unavailable
    )
}

struct BatterySnapshot: Equatable {
    enum PowerState: Equatable {
        case charging
        case externalPower
        case discharging
        case full
        case unknown
    }

    var temperatureCelsius: Double?
    var chargingWatts: Double?
    var levelPercent: Int?
    var powerState: PowerState

    static let unavailable = BatterySnapshot(
        temperatureCelsius: nil,
        chargingWatts: nil,
        levelPercent: nil,
        powerState: .unknown
    )
}
