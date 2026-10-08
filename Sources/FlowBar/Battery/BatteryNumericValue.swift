import Foundation

// Shared conversion for numeric values returned by IOKit.
enum BatteryNumericValue {
    static func double(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID(),
              number.doubleValue.isFinite else { return nil }
        return number.doubleValue
    }

    static func integer(_ value: Any?) -> Int? {
        guard let numeric = double(value) else { return nil }
        // Preserve exact integer values near Int's limits before converting via Double.
        if let integer = value as? Int { return integer }
        // NSNumber.intValue does not report failed conversions for invalid readings.
        return Int(exactly: numeric.rounded(.towardZero))
    }

    static func bool(_ value: Any?) -> Bool? {
        guard let number = value as? NSNumber, number.doubleValue.isFinite else { return nil }
        return number.boolValue
    }
}
