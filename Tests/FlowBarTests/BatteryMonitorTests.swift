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

    func testConvertsRawTemperatureUnitsIntoSnapshotCelsius() {
        let cases: [([String: Any], Double)] = [
            (["Temperature": 3104], 37.25),
            (["Temperature": 30.5], 30.5),
            (["AppleSmartBatteryPack": ["BatteryData": ["Temperature": 3839]]], 38.39)
        ]
        for (values, expected) in cases {
            let snapshot = BatteryMonitor(provider: FakeBatteryProvider(values: values)).snapshot()
            XCTAssertEqual(try XCTUnwrap(snapshot.temperatureCelsius), expected, accuracy: 0.001)
        }
    }

    func testCalculatesPercentageFromRegistryCapacityUnits() {
        let values: [String: Any] = ["CurrentCapacity": 2500, "MaxCapacity": 5000]
        let snapshot = BatteryMonitor(provider: FakeBatteryProvider(values: values)).snapshot()

        XCTAssertEqual(snapshot.levelPercent, 50)
    }

    func testCalculatesPercentageFromPowerSourceCapacityKeys() {
        let values: [String: Any] = ["Current Capacity": 1500, "Max Capacity": 6000]
        let snapshot = BatteryMonitor(provider: FakeBatteryProvider(values: values)).snapshot()

        XCTAssertEqual(snapshot.levelPercent, 25)
    }

    func testPowerSourceAliasesOverrideConflictingRegistryFields() {
        let snapshot = BatteryMonitor(provider: FakeBatteryProvider(values: [
            "Voltage": 12000, "Amperage": -500, "Current": 1500,
            "CurrentCapacity": 90, "Current Capacity": 1500,
            "MaxCapacity": 100, "Max Capacity": 6000,
            "IsCharging": false, "Is Charging": true,
            "IsCharged": true, "Is Charged": false
        ])).snapshot()

        XCTAssertEqual(snapshot.chargingWatts, 18)
        XCTAssertEqual(snapshot.levelPercent, 25)
        XCTAssertEqual(snapshot.powerState, .charging)
    }

    func testInvalidAliasesStillMaskValidRegistryFields() {
        for invalid: Any in [NSNull(), "invalid", Double.nan] {
            var values: [String: Any] = [
                "Voltage": 12000, "Amperage": 1500, "Current": invalid,
                "CurrentCapacity": 50, "Current Capacity": invalid,
                "IsCharging": true, "Is Charging": invalid,
                "IsCharged": true, "Is Charged": invalid
            ]
            let snapshot = BatteryMonitor(provider: FakeBatteryProvider(values: values)).snapshot()
            XCTAssertNil(snapshot.chargingWatts)
            XCTAssertNil(snapshot.levelPercent)
            XCTAssertEqual(snapshot.powerState, .unknown)

            values["FullyCharged"] = true
            XCTAssertEqual(BatteryMonitor(provider: FakeBatteryProvider(values: values)).snapshot().powerState, .full)
            let capacity = BatteryMonitor(provider: FakeBatteryProvider(values: [
                "CurrentCapacity": 50, "MaxCapacity": 100, "Max Capacity": invalid
            ])).snapshot()
            XCTAssertNil(capacity.levelPercent)
        }
    }

    func testPowerSourceStateOverridesConnectionFlagsOnlyForStrings() {
        let cases: [([String: Any], BatterySnapshot.PowerState)] = [
            (["Power Source State": "AC Power", "ExternalConnected": false], .externalPower),
            (["Power Source State": "Battery Power", "ExternalConnected": true, "AppleRawExternalConnected": true], .discharging),
            (["Power Source State": "Unknown", "ExternalConnected": true], .discharging),
            (["Power Source State": true, "ExternalConnected": true], .externalPower),
            (["Power Source State": NSNull(), "ExternalConnected": false, "AppleRawExternalConnected": true], .discharging),
            (["Power Source State": NSNull(), "ExternalConnected": "invalid", "AppleRawExternalConnected": true], .externalPower)
        ]
        for (fields, expected) in cases {
            var values = fields
            values["IsCharging"] = false
            XCTAssertEqual(BatteryMonitor(provider: FakeBatteryProvider(values: values)).snapshot().powerState, expected)
        }
    }

    func testCapacityNormalizationHandlesRoundingAndOverfullReadings() {
        for (current, maximum, expected) in [(2, 3, 67), (110, 100, 100), (0, 100, 0)] {
            let snapshot = BatteryMonitor(provider: FakeBatteryProvider(values: [
                "CurrentCapacity": current, "MaxCapacity": maximum
            ])).snapshot()
            XCTAssertEqual(snapshot.levelPercent, expected)
        }
    }

    func testInvalidMaximumCapacityDoesNotFallBackToRawPercentage() {
        let invalidMaxima: [Any] = [0, -1, Double.nan, Double.infinity, NSNumber(value: UInt64.max), "100"]
        for maximum in invalidMaxima {
            let snapshot = BatteryMonitor(provider: FakeBatteryProvider(values: [
                "CurrentCapacity": 50, "MaxCapacity": maximum
            ])).snapshot()
            XCTAssertNil(snapshot.levelPercent, "maximum: \(maximum)")
        }
    }

    func testCapacityWithoutMaximumRequiresValidPercentage() {
        for current in [-1, 101, Int.max] {
            let snapshot = BatteryMonitor(provider: FakeBatteryProvider(values: ["CurrentCapacity": current])).snapshot()
            XCTAssertNil(snapshot.levelPercent)
        }
        for current in [0, 50, 100] {
            let snapshot = BatteryMonitor(provider: FakeBatteryProvider(values: ["CurrentCapacity": current])).snapshot()
            XCTAssertEqual(snapshot.levelPercent, current)
        }
    }

    func testMaximumIntegerCapacitiesDoNotOverflow() {
        let snapshot = BatteryMonitor(provider: FakeBatteryProvider(values: [
            "CurrentCapacity": Int.max, "MaxCapacity": Int.max
        ])).snapshot()

        XCTAssertEqual(snapshot.levelPercent, 100)
    }

    func testExplicitlyAbsentBatteryIsUnavailableDespiteRemainingFields() {
        for key in ["BatteryInstalled", "Is Present"] {
            let values: [String: Any] = [key: false, "CurrentCapacity": 0, "Voltage": 0, "Amperage": 0, "IsCharging": false]
            XCTAssertEqual(BatteryMonitor(provider: FakeBatteryProvider(values: values)).snapshot(), .unavailable)
        }
    }

    func testInvalidNumericReadingsRemainMissing() {
        let invalidValues: [Any] = [Double.nan, Double.infinity, NSNumber(value: UInt64.max), Double.greatestFiniteMagnitude, true]
        for value in invalidValues {
            let snapshot = BatteryMonitor(provider: FakeBatteryProvider(values: [
                "Voltage": 12000, "Amperage": value, "CurrentCapacity": value
            ])).snapshot()
            XCTAssertNil(snapshot.chargingWatts, "current: \(value)")
            XCTAssertNil(snapshot.levelPercent, "capacity: \(value)")
        }
    }

    func testNonpositiveVoltageDoesNotProducePowerReading() {
        for voltage in [0, -12000] {
            let snapshot = BatteryMonitor(provider: FakeBatteryProvider(values: [
                "Voltage": voltage, "Amperage": -500
            ])).snapshot()
            XCTAssertNil(snapshot.chargingWatts)
            XCTAssertEqual(snapshot.powerState, .unknown)
        }
    }

    func testInvalidNormalizedTemperatureFallsBackToValidRawReading() {
        let snapshot = BatteryMonitor(provider: FakeBatteryProvider(values: [
            "TemperatureCelsius": Double.nan, "Temperature": 3042
        ])).snapshot()

        XCTAssertEqual(try XCTUnwrap(snapshot.temperatureCelsius), 31.05, accuracy: 0.001)
    }

    func testValidPrimaryTemperatureSkipsBatteryPackRead() {
        for (key, reading) in [("Temperature", 3042.0), ("TemperatureCelsius", 31.05), ("Temperature Celsius", 31.05)] {
            var queries: [String] = []
            let provider = IOKitBatteryProvider { name in
                queries.append(name)
                return [key: reading, "CurrentCapacity": 50]
            }

            let snapshot = BatteryMonitor(provider: provider).snapshot()

            XCTAssertEqual(queries, ["AppleSmartBattery"])
            XCTAssertEqual(try XCTUnwrap(snapshot.temperatureCelsius), 31.05, accuracy: 0.001)
        }
    }

    func testInvalidPrimaryTemperatureReadsBatteryPackFallback() {
        var queries: [String] = []
        let provider = IOKitBatteryProvider { name in
            queries.append(name)
            if name == "AppleSmartBattery" { return ["Temperature": Double.nan] }
            return ["BatteryData": ["Temperature": 3839]]
        }

        let snapshot = BatteryMonitor(provider: provider).snapshot()

        XCTAssertEqual(queries, ["AppleSmartBattery", "AppleSmartBatteryPack"])
        XCTAssertEqual(try XCTUnwrap(snapshot.temperatureCelsius), 38.39, accuracy: 0.001)
    }

    func testAbsentBatterySkipsBatteryPackRead() {
        for key in ["BatteryInstalled", "Is Present"] {
            var queries: [String] = []
            let provider = IOKitBatteryProvider { name in
                queries.append(name)
                return [key: false, "CurrentCapacity": 0]
            }

            XCTAssertEqual(BatteryMonitor(provider: provider).snapshot(), .unavailable)
            XCTAssertEqual(queries, ["AppleSmartBattery"])
        }
    }
}

private struct FakeBatteryProvider: BatteryInfoProviding {
    var values: [String: Any]

    func batteryInfo() -> [String: Any] {
        values
    }
}
