//
//  NumberFormatting.swift
//  JSONPath
//
//  Every way a number is written for a person.
//

import Foundation

/// The number formats, on `NSNumber`, in the system locale.
///
/// In the system locale on purpose: this is display, and a French user's
/// menu bar should read `1 234,5`. Parsing is the other way round — see
/// ``NumberParsing`` — and never uses the locale.
enum NumberFormatting {

    /// `decimals` places, grouped: `1234.567` → `1,234.57`. Nil is whole.
    ///
    /// Grouped because this is what a reading falls back to when nobody chose
    /// a format, and an ungrouped `124451` is a number you have to count the
    /// digits of. `NumberFormatter` does not group unless asked, which is how
    /// it read that way for as long as it did.
    static func plain(_ number: NSNumber, decimals: Int?) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = decimals ?? 0
        formatter.maximumFractionDigits = decimals ?? 0
        formatter.usesGroupingSeparator = true
        return formatter.string(from: number) ?? "N/A"
    }

    /// Money: whole amounts without pence, fractional ones with two places.
    static func currency(_ number: NSNumber, code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        formatter.currencyCode = code
        if number.doubleValue.truncatingRemainder(dividingBy: 1) == 0 {
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 0
        } else {
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
        }
        return formatter.string(from: number) ?? "N/A"
    }

    /// `1500` → `1.5k`, `2000000` → `2m`, `3000000000` → `3b`. One decimal
    /// only when the division leaves one; below a thousand, a whole number.
    ///
    /// Rounded before the unit is chosen: `999,999` is `1m`, not `1,000.0k`,
    /// which is what dividing first and rounding second produced.
    static func compact(_ number: NSNumber) -> String {
        let value = number.doubleValue
        guard value.isFinite, value >= 1_000 else { return plain(number, decimals: 0) }
        let units: [(divisor: Double, suffix: String)] = [(1_000, "k"), (1_000_000, "m"), (1_000_000_000, "b")]
        for (position, unit) in units.enumerated() {
            /// To the even neighbour, as `NumberFormatter` rounds — 2.25m is 2.2m either way
            let scaled = (value / unit.divisor * 10).rounded(.toNearestOrEven) / 10
            let isLast = position == units.count - 1
            guard scaled < 1_000 || isLast else { continue }
            let decimals = scaled == scaled.rounded() ? 0 : 1
            return "\(plain(NSNumber(value: scaled), decimals: decimals))\(unit.suffix)"
        }
        return plain(number, decimals: 0)
    }

    /// Thousands separators, no fraction: `1234567` → `1,234,567`.
    static func delimited(_ number: NSNumber) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        formatter.usesGroupingSeparator = true
        return formatter.string(from: number) ?? "N/A"
    }

    /// A ratio as a whole percentage: `0.1` → `10%`, truncated not rounded.
    static func percentage(_ number: NSNumber) -> String {
        let scaled = number.doubleValue * 100
        guard scaled.isFinite else { return "0%" }
        guard abs(scaled) < Double(Int.max) else {
            return "\(plain(NSNumber(value: scaled), decimals: 0))%"
        }
        return "\(Int(scaled))%"
    }

    /// A byte count as a file size: `1048576` → `1 MB`.
    static func bytes(_ number: NSNumber) -> String {
        guard number.doubleValue.isFinite else { return plain(number, decimals: 0) }
        return ByteCountFormatter.string(fromByteCount: Int64(number.doubleValue), countStyle: .file)
    }

    /// Seconds as a two-unit duration: `3661` → `1h 1m`.
    static func duration(_ number: NSNumber) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        return formatter.string(from: number.doubleValue) ?? plain(number, decimals: 0)
    }
}
