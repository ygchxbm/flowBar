import Foundation

struct MetricsSnapshot: Equatable, Sendable {
    var downloadBytesPerSecond: Double?
    var uploadBytesPerSecond: Double? = nil
    var battery: BatterySnapshot

    static let unavailable = MetricsSnapshot(
        downloadBytesPerSecond: nil,
        battery: .unavailable
    )
}

struct BatterySnapshot: Equatable, Sendable {
    enum PowerState: Equatable, Sendable {
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
