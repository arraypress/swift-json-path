//
//  DateFormatting.swift
//  JSONPath
//

import Foundation

/// Date to text, for a person.
enum DateFormatting {

    /// A date through a `DateFormatter` pattern, in the system locale and
    /// zone: this is display, and a person's clock is the right clock.
    static func string(_ date: Date, pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}
