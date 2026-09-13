//
//  JSONPath.swift
//  JSONPath
//
//  The namespace: one value out of a response body, and the display string a
//  metric shows for it.
//

import Foundation

/// One value out of a JSON (or plain-text) response, addressed by a path, and
/// the display string a metric makes of it.
///
/// This is the engine behind MetricBar's menu bar and Powercuts' "Get Value
/// from URL" action, extracted so the two cannot drift. It answers the
/// question an API-reading tool actually has — "what number does this body
/// contain, and how should it read" — with one path grammar and one set of
/// formatters:
///
/// - `data.total`, `results[0].price` — a key path, with an index.
/// - `orders[+].price` — every price in the list, summed. `[#]` counts,
///   `[~]` averages, `[^]` and `[v]` take the largest and smallest, `[<]` and
///   `[>]` the first and last, `[=]` the median, `[-]` the range.
/// - Math on the result (cents into dollars), then a format (a number to two
///   places, a currency, a percentage, a date, a file size, a status label).
/// - A label beside the value — `<=50:Good, <=100:Moderate, *:Unhealthy`
///   turns `160` into `160 Unhealthy`, on whichever side you ask for.
///
/// A path that finds nothing extracts nothing. It does not fall back to the
/// raw body, because a metric that publishes a whole JSON document as its
/// value has not failed loudly, it has failed quietly and recorded the mess
/// as history.
public enum JSONPath {

    /// Parses a body into a typed value.
    ///
    /// - Throws: ``JSONPathError/invalidJSON(_:)`` when the text is not JSON.
    ///   Plain text is not an error to ``extract(_:from:)``, which reads it as
    ///   the value itself; this is the strict entry point for callers that
    ///   want to know.
    public static func parse(_ text: String) throws -> JSONValue {
        try Document.parse(text)
    }

    /// The value a path addresses, before any math or formatting.
    ///
    /// For an operation path (`orders[+].price`) this is the aggregate as a
    /// number. For a body that is not JSON it is the trimmed text. Nil when the
    /// path finds nothing — never the body.
    public static func value(at path: String, in text: String) -> JSONValue? {
        Locator.value(at: path, in: text)
    }

    /// Runs a whole extraction: path, array operation, math, format, prefix and
    /// suffix, and the optional second value.
    ///
    /// The result's ``Extraction/Result/rawValue`` is the primary value after
    /// math and before formatting — what trend arrows, alerts and charts track
    /// — and it is nil when nothing was found so a caller can keep its last
    /// good reading rather than blank it.
    public static func extract(_ query: Extraction, from text: String) -> Extraction.Result {
        var extractor = Extractor(query: query)
        let display = extractor.run(text)
        return Extraction.Result(display: display, rawValue: extractor.rawValue)
    }
}
