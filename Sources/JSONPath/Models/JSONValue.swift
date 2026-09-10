//
//  JSONValue.swift
//  JSONPath
//

import Foundation

/// A JSON value, typed.
///
/// What a path resolves to when a caller wants the value rather than the
/// display string. Numbers are doubles because that is what JSON carries;
/// a value that arrived as a string of digits stays a string, so the caller
/// can see what the API actually sent.
public enum JSONValue: Sendable, Hashable {

    /// A JSON string.
    case string(String)

    /// A JSON number. Integers arrive as whole doubles.
    case number(Double)

    /// A JSON boolean.
    case bool(Bool)

    /// JSON `null`.
    case null

    /// A JSON array, in order.
    case array([JSONValue])

    /// A JSON object. Key order is not preserved, as in the wire format.
    case object([String: JSONValue])
}
