//
//  Locator.swift
//  JSONPath
//
//  The value a path addresses, typed and unformatted.
//

import Foundation

/// Finds the value at a path without formatting it: the typed answer to
/// "what is at `data.total`" or "what does `orders[+].price` come to".
enum Locator {

    static func value(at path: String, in body: String) -> JSONValue? {
        if let dictionary = Document.object(body) {
            return located(in: dictionary, path: path).map(Document.typed)
        } else if let array = Document.objectArray(body) {
            return locatedInArray(array, path: path).map(Document.typed)
        } else if let scalars = Document.scalarArray(body) {
            return located(in: NSDictionary(dictionary: ["custom": scalars]), path: "custom\(path)").map(Document.typed)
        }
        let plain = body.trimmingCharacters(in: .whitespacesAndNewlines)
        return plain.isEmpty ? nil : .string(plain)
    }

    /// Mirrors the engine's dictionary route: a direct key path, an index, or
    /// an operation named by the path's own marker. The extractor borrows it
    /// for a key that carries an index of its own.
    static func located(in dictionary: NSDictionary, path: String) -> Any? {
        if let direct = KeyPathWalk.value(forKeyPath: path, in: dictionary) {
            return direct
        }
        if let index = PathSyntax.index(in: path), let root = PathSyntax.rootPath(in: path) {
            guard let list = KeyPathWalk.value(forKeyPath: root, in: dictionary) as? [Any],
                  list.count > index else { return nil }
            let element = KeyPathWalk.decodingEmbeddedJSON(list[index])
            guard let key = PathSyntax.rootKey(in: path) else { return element }
            return descend(element, key: key)
        }
        if let operation = PathSyntax.operation(in: path), operation != .none,
           let root = PathSyntax.rootPath(in: path) {
            if let items = KeyPathWalk.value(forKeyPath: root, in: dictionary) as? [NSDictionary] {
                return aggregate(operation, key: PathSyntax.rootKey(in: path), items: items)
            }
            if let scalars = KeyPathWalk.value(forKeyPath: root, in: dictionary) as? [Any] {
                let wrapped = scalars.map { NSDictionary(dictionary: ["value": $0]) }
                return aggregate(operation, key: scalarKey(PathSyntax.rootKey(in: path)), items: wrapped)
            }
        }
        return nil
    }

    /// One level down from an element a bracket picked: into an object by key, or — when the
    /// key is another bracket — into the element as a list of its own. A list inside a list is
    /// how a SQL-style API hands back rows: `results[0][0]` is the first row's first column.
    static func descend(_ element: Any, key: String) -> Any? {
        if key.hasPrefix("[") {
            return located(in: NSDictionary(dictionary: ["custom": element]), path: "custom" + key)
        }
        guard let dictionary = element as? NSDictionary else { return nil }
        return located(in: dictionary, path: key)
    }

    /// The key that reads each wrapped scalar: `value`, or `value[0]` when the scalars are
    /// lists and the path carried on with a bracket (`matrix[+][0]`)
    static func scalarKey(_ rootKey: String?) -> String {
        guard let rootKey, rootKey.hasPrefix("[") else { return "value" }
        return "value" + rootKey
    }

    private static func locatedInArray(_ array: [NSDictionary], path: String) -> Any? {
        if let operation = PathSyntax.operation(in: path), operation != .none {
            return aggregate(operation, key: PathSyntax.rootKey(in: path), items: array)
        }
        guard let index = PathSyntax.index(in: path), array.count > index else { return nil }
        guard let key = PathSyntax.rootKey(in: path) else { return array[index] }
        return descend(array[index], key: key)
    }

    private static func aggregate(_ operation: ArrayOperation, key: String?, items: [NSDictionary]) -> Any? {
        if operation == .count { return NSNumber(value: items.count) }
        guard let key else { return nil }
        /// A key with a bracket of its own — `results[0].amount`, `value[0]` — is a path, not
        /// a key path, and is walked as one
        let numbers = items.compactMap { item -> Double? in
            let found: Any? = key.contains("[") ? located(in: item, path: key) : KeyPathWalk.number(forKeyPath: key, in: item)
            if let number = found as? NSNumber { return number.doubleValue }
            return (found as? String).flatMap(NumberParsing.number)?.doubleValue
        }
        return Reductions.reduce(numbers, itemCount: items.count, by: operation).map { NSNumber(value: $0) }
    }
}
