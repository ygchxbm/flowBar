import XCTest
@testable import FlowBar

final class BatteryNumericValueTests: XCTestCase {
    func testIntegerConversionPreservesSupportedNumericTypes() {
        let values: [Any] = [Int(12), Int32(12), Int64(12), NSNumber(value: 12), NSNumber(value: 12.9)]
        for value in values {
            XCTAssertEqual(BatteryNumericValue.integer(value), 12)
        }
        XCTAssertEqual(BatteryNumericValue.integer(NSNumber(value: -12.9)), -12)
        XCTAssertEqual(BatteryNumericValue.integer(Int.max), Int.max)
        XCTAssertEqual(BatteryNumericValue.integer(Int.min), Int.min)
    }

    func testIntegerConversionRejectsNonfiniteOrOutOfRangeValues() {
        let invalid: [Any] = [
            Double.nan, Double.infinity, -Double.infinity, Double(Int.max),
            Double.greatestFiniteMagnitude, NSNumber(value: UInt64.max),
            NSDecimalNumber(string: "99999999999999999999999999999999"), true, "12"
        ]
        for value in invalid {
            XCTAssertNil(BatteryNumericValue.integer(value), "value: \(value)")
        }
    }

    func testDoubleConversionRejectsNonfiniteAndBooleanValues() {
        for value: Any in [Double.nan, Double.infinity, Float.infinity, true, "12"] {
            XCTAssertNil(BatteryNumericValue.double(value))
        }
        XCTAssertEqual(BatteryNumericValue.double(Float(30.5)), 30.5)
        XCTAssertEqual(BatteryNumericValue.double(NSNumber(value: -12)), -12)
    }

    func testBooleanConversionRejectsNonfiniteValues() {
        XCTAssertEqual(BatteryNumericValue.bool(true), true)
        XCTAssertEqual(BatteryNumericValue.bool(NSNumber(value: false)), false)
        XCTAssertEqual(BatteryNumericValue.bool(NSNumber(value: 1)), true)
        XCTAssertNil(BatteryNumericValue.bool(Double.nan))
        XCTAssertNil(BatteryNumericValue.bool(Double.infinity))
    }
}
