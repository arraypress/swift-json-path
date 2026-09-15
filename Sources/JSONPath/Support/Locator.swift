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
            if let key = PathSyntax.rootKey(in: path) {
                guard let items = KeyPathWalk.value(forKeyPath: root, in: dictionary) as? [NSDictionary],
                      items.count > index else { return nil }
                return located(in: items[index], path: key)
            }
            guard let scalars = KeyPathWalk.value(forKeyPath: root, in: dictionary) as? [Any],
                  scalars.count > index else { return nil }
            return KeyPathWalk.decodingEmbeddedJSON(scalars[index])
        }
        if let operation = PathSyntax.operation(in: path), operation != .none,
           let root = PathSyntax.rootPath(in: path) {
            if let items = KeyPathWalk.value(forKeyPath: root, in: dictionary) as? [NSDictionary] {
                return aggregate(operation, key: PathSyntax.rootKey(in: path), items: items)
            }
            if let scalars = KeyPathWalk.value(forKeyPath: root, in: dictionary) as? [Any] {
                let wrapped = scalars.map { NSDictionary(dictionary: ["value": $0]) }
                return aggregate(operation, key: "value", items: wrapped)
            }
        }
        return nil
    }

    private static func locatedInArray(_ array: [NSDictionary], path: String) -> Any? {
        if let operation = PathSyntax.operation(in: path), operation != .none {
            return aggregate(operation, key: PathSyntax.rootKey(in: path), items: array)
        }
        guard let key = PathSyntax.rootKey(in: path), let index = PathSyntax.index(in: path),
              array.count > index else { return nil }
        return located(in: array[index], path: key)
    }

    private static func aggregate(_ operation: ArrayOperation, key: String?, items: [NSDictionary]) -> Any? {
        if operation == .count { return NSNumber(value: items.count) }
        guard let key else { return nil }
        let numbers = items.compactMap { KeyPathWalk.number(forKeyPath: key, in: $0)?.doubleValue }
        return Reductions.reduce(numbers, itemCount: items.count, by: operation).map { NSNumber(value: $0) }
    }
}
