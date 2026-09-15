//
//  PathSyntax.swift
//  JSONPath
//
//  Reading a path the way the engine always has: the first bracket and the
//  first dot decide everything.
//

import Foundation

/// The pieces of a path: `orders[+].price` is a root `orders`, a marker `+`
/// and a key `price`; `results[2].name` is a root, an index `2` and a key.
///
/// Deliberately not a general JSONPath parser. The grammar is the one every
/// saved metric already uses, and it is decided by the FIRST bracket and the
/// FIRST dot, so `a.b[0].c` has the root `a.b` (walked as a key path) and the
/// key `c`.
enum PathSyntax {

    /// The marker inside the first bracket pair, as an operation.
    static func operation(in path: String) -> ArrayOperation? {
        guard let marker = firstBracketContents(in: path, pattern: #"\[([^\]]+)\]"#) else { return nil }
        return ArrayOperation(symbol: marker)
    }

    /// The number inside the first bracket pair, when that pair holds one.
    ///
    /// The *first* pair, not the first numeric one: `data[+].results[0].amount` asks for a sum
    /// across days, and reading its `[0]` as the index used to answer with the first day alone,
    /// silently, as if it were the total.
    static func index(in path: String) -> Int? {
        guard let marker = firstBracketContents(in: path, pattern: #"\[([^\]]+)\]"#) else { return nil }
        return Int(marker)
    }

    /// Everything before the first `[`, else before the first `.`, else nil.
    static func rootPath(in path: String) -> String? {
        if let bracket = path.firstIndex(of: "[") {
            return String(path[..<bracket])
        } else if let dot = path.firstIndex(of: ".") {
            return String(path[..<dot])
        }
        return nil
    }

    /// The key after the first `]` (which must be followed by a dot), else
    /// everything after the first `.`, else nil.
    static func rootKey(in path: String) -> String? {
        if let closing = path.firstIndex(of: "]") {
            let rest = path[path.index(after: closing)...]
            guard rest.first == "." else { return nil }
            return String(rest.dropFirst())
        } else if let dot = path.firstIndex(of: ".") {
            return String(path[path.index(after: dot)...])
        }
        return nil
    }

    /// The character each operation writes inside its brackets.
    static func symbol(for operation: ArrayOperation) -> String {
        switch operation {
        case .none: ""
        case .sum: "+"
        case .count: "#"
        case .average: "~"
        case .max: "^"
        case .min: "v"
        case .first: "<"
        case .last: ">"
        case .median: "="
        case .range: "-"
        }
    }

    private static func firstBracketContents(in path: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(path.startIndex..<path.endIndex, in: path)
        guard let match = regex.firstMatch(in: path, options: [], range: range),
              match.numberOfRanges == 2,
              let capture = Range(match.range(at: 1), in: path) else { return nil }
        return String(path[capture])
    }
}
