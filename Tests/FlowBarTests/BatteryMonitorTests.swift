import XCTest
@testable import FlowBar

final class BatteryMonitorTests: XCTestCase {
    func testCalculatesBatteryFieldsFromAppleSmartBatteryValues() {
        let monitor = BatteryMonitor(provider: FakeBatteryProvider(values: [
            "Temperature": 3042,
            "Voltage": 12000,
            "Amperage": 1500,
            "CurrentCapacity": 83,
            "IsCharging": true
        ]))

        let snapshot = monitor.snapshot()

        XCTAssertEqual(try XCTUnwrap(snapshot.temperatureCelsius), 31.05, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(snapshot.chargingWatts), 18.0, accuracy: 0.001)
        XCTAssertEqual(snapshot.levelPercent, 83)
        XCTAssertEqual(snapshot.powerState, .charging)
    }

    func testCalculatesDischargingWatts() {
        let monitor = BatteryMonitor(provider: FakeBatteryProvider(values: [
            "Voltage": 12000,
            "Amperage": -500,
            "CurrentCapacity": 66,
            "IsCharging": false
        ]))

        let snapshot = monitor.snapshot()

        XCTAssertEqual(try XCTUnwrap(snapshot.chargingWatts), -6.0, accuracy: 0.001)
        XCTAssertEqual(snapshot.levelPercent, 66)
        XCTAssertEqual(snapshot.powerState, .discharging)
    }

    func testUnavailableFieldsStayNil() {
        let monitor = BatteryMonitor(provider: FakeBatteryProvider(values: [:]))

        XCTAssertEqual(monitor.snapshot(), .unavailable)
    }

    func testParsesPowerSourceDescriptionKeys() {
        let monitor = BatteryMonitor(provider: FakeBatteryProvider(values: [
            "TemperatureCelsius": 30.5,
            "Voltage": NSNumber(value: 12000),
            "Current": NSNumber(value: 1500),
            "Current Capacity": NSNumber(value: 91),
            "Is Charging": NSNumber(value: true)
        ]))

        let snapshot = monitor.snapshot()

        XCTAssertEqual(try XCTUnwrap(snapshot.temperatureCelsius), 30.5, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(snapshot.chargingWatts), 18.0, accuracy: 0.001)
        XCTAssertEqual(snapshot.levelPercent, 91)
        XCTAssertEqual(snapshot.powerState, .charging)
    }

    func testFullBatteryStateTakesPrecedence() {
        let monitor = BatteryMonitor(provider: FakeBatteryProvider(values: [
            "Voltage": 12000,
            "Amperage": 0,
            "CurrentCapacity": 100,
            "IsCharging": false,
            "IsCharged": true
        ]))

        XCTAssertEqual(monitor.snapshot().powerState, .full)
    }

    func testExternalPowerWithoutChargingIsNotDischarging() {
        let monitor = BatteryMonitor(provider: FakeBatteryProvider(values: [
            "Voltage": 12590,
            "Amperage": 0,
            "CurrentCapacity": 80,
            "IsCharging": false,
            "FullyCharged": false,
            "ExternalConnected": true
        ]))

        XCTAssertEqual(monitor.snapshot().powerState, .externalPower)
    }

    func testPartialDictionaryKeepsMissingFieldsNil() {
        let monitor = BatteryMonitor(provider: FakeBatteryProvider(values: [
            "CurrentCapacity": 44
        ]))

        let snapshot = monitor.snapshot()

        XCTAssertNil(snapshot.temperatureCelsius)
        XCTAssertNil(snapshot.chargingWatts)
        XCTAssertEqual(snapshot.levelPercent, 44)
        XCTAssertEqual(snapshot.powerState, .unknown)
    }

    func testProviderNormalizesAppleSmartBatteryTemperatureFromDeciKelvin() {
        let values = IOKitBatteryProvider.normalized([
            "Temperature": 3104
        ])

        XCTAssertEqual(try XCTUnwrap(values["TemperatureCelsius"] as? Double), 37.25, accuracy: 0.001)
    }

    func testProviderKeepsCelsiusTemperatureAsCelsius() {
        let values = IOKitBatteryProvider.normalized([
            "Temperature": 30.5
        ])

        XCTAssertEqual(try XCTUnwrap(values["TemperatureCelsius"] as? Double), 30.5, accuracy: 0.001)
    }

    func testProviderNormalizesPackBatteryTemperatureFromCentiCelsius() {
        let values = IOKitBatteryProvider.normalized([
            "AppleSmartBatteryPack": [
                "BatteryData": [
                    "Temperature": 3839
                ]
            ]
        ])

        XCTAssertEqual(try XCTUnwrap(values["TemperatureCelsius"] as? Double), 38.39, accuracy: 0.001)
    }
}

private struct FakeBatteryProvider: BatteryInfoProviding {
    var values: [String: Any]

    func batteryInfo() -> [String: Any] {
        values
    }
}
