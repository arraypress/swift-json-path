//
//  ArrayOperation.swift
//  JSONPath
//

import Foundation

/// How a list addressed by a path is reduced to one number.
///
/// Each carries the marker written inside the brackets: `orders[+].price`
/// sums, `orders[#]` counts. The operation on the query and the marker in the
/// path must agree — a path that says `[+]` with a query that says average
/// extracts nothing, rather than guessing which one the user meant.
public enum ArrayOperation: String, CaseIterable, Sendable, Codable {

    /// No reduction: the path addresses one value.
    case none

    /// `[+]` — add every value.
    case sum

    /// `[#]` — how many items the list has. Needs no key after it.
    case count

    /// `[~]` — the mean of the values.
    case average

    /// `[^]` — the largest value.
    case max

    /// `[v]` — the smallest value.
    case min

    /// `[<]` — the first value.
    case first

    /// `[>]` — the last value.
    case last

    /// `[=]` — the middle value, or the mean of the middle two.
    case median

    /// `[-]` — the largest minus the smallest.
    case range

    /// The character written inside the brackets.
    public var symbol: String { PathSyntax.symbol(for: self) }

    /// The operation a marker names, or nil for a marker that is not one.
    public init?(symbol: String) {
        guard let match = ArrayOperation.allCases.first(where: { $0.symbol == symbol }) else { return nil }
        self = match
    }
}
