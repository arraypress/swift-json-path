//
//  KeyPathWalk.swift
//  JSONPath
//
//  Walking a dot-separated key path by hand.
//

import Foundation

/// Key-path lookups on a dictionary, done by hand.
///
/// Cocoa's `value(forKeyPath:)` raises an uncatchable ObjC exception when a
/// hop lands on a non-dictionary value (a string, a number, `NSNull`) or a key
/// starts with `@` — both routine shapes in live JSON — so the walk is a loop.
enum KeyPathWalk {

    /// The value at a dot path, or nil when any hop is missing or null.
    ///
    /// A string that is itself JSON — Polymarket's
    /// `"outcomePrices": "[\"0.31\", \"0.69\"]"` — is decoded so the path can
    /// keep walking into it.
    static func value(forKeyPath keyPath: String, in dictionary: NSDictionary) -> Any? {
        var current: Any = dictionary
        for key in keyPath.components(separatedBy: ".") {
            guard let dictionary = current as? NSDictionary,
                  let next = dictionary[key], !(next is NSNull) else { return nil }
            current = decodingEmbeddedJSON(next)
        }
        return current
    }

    /// A string that starts like JSON is decoded; anything else passes through.
    static func decodingEmbeddedJSON(_ value: Any) -> Any {
        guard let string = value as? String else { return value }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first, first == "[" || first == "{",
              let data = trimmed.data(using: .utf8),
              let decoded = try? JSONSerialization.jsonObject(with: data)
        else { return value }
        return decoded
    }

    /// The number at a path — a JSON number, or a string that reads as one.
    static func number(forKeyPath keyPath: String, in dictionary: NSDictionary) -> NSNumber? {
        if let number = value(forKeyPath: keyPath, in: dictionary) as? NSNumber { return number }
        return string(forKeyPath: keyPath, in: dictionary).flatMap(NumberParsing.number)
    }

    /// The string at a path, when it is one.
    static func string(forKeyPath keyPath: String, in dictionary: NSDictionary) -> String? {
        value(forKeyPath: keyPath, in: dictionary) as? String
    }
}
