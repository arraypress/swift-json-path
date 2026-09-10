//
//  Extraction.swift
//  JSONPath
//

import Foundation

/// Everything that turns a response body into one displayed value.
///
/// The same shape MetricBar stores for a saved metric and Powercuts takes as
/// action parameters. Every field has a do-nothing default, so
/// `Extraction(path: "data.total")` is a complete query.
public struct Extraction: Sendable, Hashable, Codable {

    /// Where the value is: `data.total`, `results[0].price`, `orders[+].price`.
    public var path: String

    /// How a list at the path is reduced to one number. Must agree with the
    /// marker in the path: `orders[+].price` needs ``ArrayOperation/sum``.
    public var arrayOperation: ArrayOperation

    /// Arithmetic applied to the number before formatting.
    public var mathOperation: MathOperation

    /// The operand for ``mathOperation``, as text — `100` to turn cents into
    /// dollars. Text that is not a number leaves the value alone.
    public var mathValue: String

    /// How the value is shown.
    public var format: Format

    /// Text before the value: `$`.
    public var prefix: String

    /// Text after the value: ` USD`.
    public var suffix: String

    /// An optional second value shown after the first — the away score in
    /// `2 – 1`, the total in `12 / 50`. Formatted the same way, with no array
    /// operation and no math. Empty for a single value.
    public var secondaryPath: String

    /// Placed between the two values.
    public var separator: String

    public init(
        path: String,
        arrayOperation: ArrayOperation = .none,
        mathOperation: MathOperation = .none,
        mathValue: String = "",
        format: Format = .number(decimals: nil),
        prefix: String = "",
        suffix: String = "",
        secondaryPath: String = "",
        separator: String = ""
    ) {
        self.path = path
        self.arrayOperation = arrayOperation
        self.mathOperation = mathOperation
        self.mathValue = mathValue
        self.format = format
        self.prefix = prefix
        self.suffix = suffix
        self.secondaryPath = secondaryPath
        self.separator = separator
    }
}
