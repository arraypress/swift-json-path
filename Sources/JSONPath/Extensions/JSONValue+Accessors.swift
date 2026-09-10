//
//  JSONValue+Accessors.swift
//  JSONPath
//
//  The value as the type a caller wanted, or nil.
//

import Foundation

extension JSONValue {

    /// The number, when this is one. A string is not converted — see ``text``
    /// for the other direction.
    public var number: Double? {
        if case .number(let value) = self { return value }
        return nil
    }

    /// The text of a string, number or boolean; nil for null, arrays and objects.
    ///
    /// A whole number prints without a fraction (`42`, not `42.0`), the way
    /// JSON wrote it.
    public var text: String? {
        switch self {
        case .string(let value): return value
        case .number(let value): return Document.numberText(value)
        case .bool(let value): return value ? "true" : "false"
        case .null, .array, .object: return nil
        }
    }

    /// The boolean, when this is one.
    public var bool: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    /// The elements, when this is an array.
    public var array: [JSONValue]? {
        if case .array(let value) = self { return value }
        return nil
    }

    /// The members, when this is an object.
    public var object: [String: JSONValue]? {
        if case .object(let value) = self { return value }
        return nil
    }

    /// Whether this is JSON `null`.
    public var isNull: Bool {
        if case .null = self { return true }
        return false
    }
}

extension JSONValue: CustomStringConvertible {

    /// The value as compact JSON text — `{"a":1}`, `"x"`, `null`.
    public var description: String {
        Document.compactText(self)
    }
}

extension JSONValue: Codable {

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
}
