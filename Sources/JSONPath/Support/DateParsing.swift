//
//  DateParsing.swift
//  JSONPath
//
//  Reading the dates APIs actually send.
//

import Foundation

/// Text to date, across the shapes APIs return.
enum DateParsing {

    /// ISO 8601 first, then bare epochs, then fifty machine-format patterns.
    ///
    /// The patterns are read in `en_US_POSIX`, because API date strings carry
    /// English month names and Latin digits and a localised formatter would
    /// fail to read `Jul 12, 2026` on any non-English system.
    static func date(from string: String) -> Date? {
        let text = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: text) { return date }
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: text) { return date }

        // Ten digits is seconds until 2286; thirteen is milliseconds.
        if text.allSatisfy(\.isNumber) {
            if text.count == 10, let seconds = TimeInterval(text) { return Date(timeIntervalSince1970: seconds) }
            if text.count == 13, let millis = TimeInterval(text) { return Date(timeIntervalSince1970: millis / 1000) }
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return patterns.lazy.compactMap { pattern in
            formatter.dateFormat = pattern
            return formatter.date(from: text)
        }.first
    }

    /// A number as a date: epoch seconds, or milliseconds when it is too big
    /// to be seconds.
    static func date(fromEpoch raw: Double) -> Date {
        let seconds = raw > 1_000_000_000_000 ? raw / 1000 : raw
        return Date(timeIntervalSince1970: seconds)
    }

    /// The patterns tried, in order. The first match wins, so the exact
    /// shapes come before the ambiguous ones.
    static let patterns: [String] = [
        "yyyy-MM-dd'T'HH:mm",
        "yyyyMMddHHmmss",
        "yyyy-MM-dd",
        "MM/dd/yyyy",
        "dd/MM/yyyy",
        "yyyy/MM/dd",
        "MMMM d, yyyy",
        "d MMMM yyyy",
        "EEE, MMM d, yyyy",
        "yyyy-MM-dd'T'HH:mm:ssZ",
        "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
        "yyyy-MM-dd HH:mm:ss",
        "MM/dd/yyyy HH:mm:ss",
        "dd/MM/yyyy HH:mm:ss",
        "dd-MM-yyyy",
        "MM-dd-yyyy",
        "yyyy.MM.dd",
        "dd.MM.yyyy",
        "MMM dd, yyyy",
        "dd MMM yyyy",
        "EEE, dd MMM yyyy",
        "EEE, dd MMM yyyy HH:mm:ss Z",
        "yyyyMMdd",
        "HH:mm:ss",
        "HH:mm",
        "yyyy-MM-dd'T'HH:mm:ssXXX",
        "yyyy-MM-dd'T'HH:mm:ss.SSSXXX",
        "yyyyMMddHHmmss",
        "yyyy/MM/dd HH:mm:ss",
        "MM/dd/yyyy HH:mm",
        "dd/MM/yyyy HH:mm",
        "yyyy-MM-dd'T'HH:mm",
        "yyyy-MM-dd HH:mm",
        "MMM-dd-yyyy",
        "dd-MMM-yyyy",
        "MMMM dd yyyy",
        "EEE, MMM dd yyyy",
        "yyyyMMdd'T'HHmmss",
        "yyyy-MM-dd'T'HHmmss.SSS",
        "yyyy.MM.dd HH:mm:ss",
        "yyyy-MM-dd'T'HH:mm:ss'Z'",
        "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
        "dd MMM yyyy HH:mm:ss Z",
        "EEE MMM dd HH:mm:ss Z yyyy",
        "yyyy-MM-dd HH:mm:ss.SSS",
        "yyyy-MM-dd'T'HH:mm:ss.SSS",
        "dd MMM yyyy HH:mm:ss",
        "MMM dd yyyy HH:mm:ss",
        "EEE MMM dd yyyy HH:mm:ss",
        "dd-MMM-yyyy HH:mm:ss",
    ]
}
