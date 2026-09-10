//
//  NumberParsing.swift
//  JSONPath
//

import Foundation

/// Text to number, machine-format.
enum NumberParsing {

    /// Reads `42.0`, `-3`, `1e5` and nothing looser.
    ///
    /// Raw values are written dot-decimal, so the formatter must not honour
    /// the system locale — a comma-decimal locale would return nil and
    /// silently disable alerts, trends and history.
    static func number(_ text: String) -> NSNumber? {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.number(from: text)
    }
}
