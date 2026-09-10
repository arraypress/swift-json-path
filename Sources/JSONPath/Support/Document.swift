//
//  Document.swift
//  JSONPath
//
//  A body as the shape it has: an object, a list of objects, a list of
//  scalars, or not JSON at all — and the bridge to the typed value.
//

import Foundation

/// Reads a response body into Foundation objects, and converts them to and
/// from ``JSONValue``.
///
/// The engine works on `NSDictionary` and `NSNumber` because the formatters
/// need what only they carry — a boolean's identity inside a number, a
/// number's own string form — and because that is what the extracted output
/// has always been measured against.
enum Document {

    /// A JSON object, or nil.
    static func object(_ text: String) -> NSDictionary? {
        raw(text) as? NSDictionary
    }

    /// A JSON array of objects, or nil.
    static func objectArray(_ text: String) -> [NSDictionary]? {
        raw(text) as? [NSDictionary]
    }

    /// A JSON array of anything, or nil. Checked after ``objectArray(_:)`` so
    /// a list of objects keeps its richer handling.
    static func scalarArray(_ text: String) -> [Any]? {
        raw(text) as? [Any]
    }

    /// Whatever JSONSerialization makes of the text, or nil.
    static func raw(_ text: String) -> Any? {
        guard let data = text.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: [])
    }

    /// The typed value, or the parser's reason it is not JSON.
    static func parse(_ text: String) throws -> JSONValue {
        guard let data = text.data(using: .utf8) else {
            throw JSONPathError.invalidJSON("the text is not UTF-8")
        }
        do {
            let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            return typed(object)
        } catch {
            throw JSONPathError.invalidJSON(Self.reason(from: error))
        }
    }

    /// A Foundation JSON object as a ``JSONValue``.
    static func typed(_ object: Any) -> JSONValue {
        switch object {
        case let dictionary as NSDictionary:
            var members: [String: JSONValue] = [:]
            for case let (key as String, value) in dictionary { members[key] = typed(value) }
            return .object(members)
        case let array as [Any]:
            return .array(array.map(typed))
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() { return .bool(number.boolValue) }
            return .number(number.doubleValue)
        case let string as String:
            return .string(string)
        case is NSNull:
            return .null
        default:
            return .string(String(describing: object))
        }
    }

    /// A number as JSON would write it: `42`, not `42.0`.
    static func numberText(_ value: Double) -> String {
        if value.isFinite, value == value.rounded(), abs(value) < 1e15 {
            return String(Int64(value))
        }
        return String(value)
    }

    /// Compact JSON text for a value, keys sorted so the output is stable.
    static func compactText(_ value: JSONValue) -> String {
        switch value {
        case .string(let text):
            let data = (try? JSONSerialization.data(withJSONObject: [text])) ?? Data()
            let wrapped = String(decoding: data, as: UTF8.self)
            return String(wrapped.dropFirst().dropLast())
        case .number(let number): return numberText(number)
        case .bool(let flag): return flag ? "true" : "false"
        case .null: return "null"
        case .array(let items): return "[" + items.map(compactText).joined(separator: ",") + "]"
        case .object(let members):
            let pairs = members.keys.sorted().map { key in
                "\(compactText(.string(key))):\(compactText(members[key]!))"
            }
            return "{" + pairs.joined(separator: ",") + "}"
        }
    }

    private static func reason(from error: Error) -> String {
        let nsError = error as NSError
        if let debug = nsError.userInfo[NSDebugDescriptionErrorKey] as? String { return debug }
        return nsError.localizedDescription
    }
}
