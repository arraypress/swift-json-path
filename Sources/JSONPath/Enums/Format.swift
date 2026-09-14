//
//  Format.swift
//  JSONPath
//

import Foundation

/// How a value is shown.
///
/// Numbers get the format; strings mostly pass through, because a name has
/// no percentage form and showing it beats showing nothing — that is how a
/// title sits next to a number as the second value.
public enum Format: Sendable, Hashable, Codable {

    /// Exactly as received: `1234.5` stays `1234.5`.
    case raw

    /// A plain number rounded to `decimals` places, with the system's
    /// grouping: `1234.567` → `1,234.57`. Nil means whole numbers.
    ///
    /// The fallback format, and the one most readings end up in, so it groups:
    /// a subscriber count is read, not counted digit by digit.
    case number(decimals: Int?)

    /// A date or timestamp rendered with a `DateFormatter` pattern:
    /// `2026-07-12` → `Jul 12, 2026` for `MMM d, yyyy`. Strings are read as
    /// dates in the common API shapes; numbers are epoch seconds, or
    /// milliseconds when the magnitude says so.
    case date(pattern: String)

    /// Shortened: `12500` → `12.5k`, `2000000` → `2m`.
    case compact

    /// Thousands separators, always whole: `1234567` → `1,234,567`.
    ///
    /// ``number(decimals:)`` groups too; this is the way to say a value is a
    /// count and has no fractional part to keep.
    case delimited

    /// A ratio as a percentage: `0.42` → `42%`.
    case percentage

    /// Money in a currency: `1234.5` → `$1,234.50` for `USD`.
    case currency(code: String)

    /// A byte count as a file size: `10485760` → `10 MB`.
    case bytes

    /// Seconds as a duration: `3661` → `1h 1m`.
    case duration

    /// A value mapped to a label through rules: `true` → `Up`.
    case status(rules: [StatusRule])
}
