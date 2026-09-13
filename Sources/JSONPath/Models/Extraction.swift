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

    /// Rules that turn the value into a word shown beside it — `160` into
    /// `Unhealthy`. Matched against the value after math and before
    /// formatting, so a band follows the number, not how it reads.
    ///
    /// Unlike ``Format/status(rules:)``, which shows the label *instead of*
    /// the value, a band shows it *as well as*. Empty for no band.
    public var bandRules: [StatusRule]

    /// Which side the band's label sits on, and whether there is one at all.
    public var bandPosition: BandPosition

    /// Placed between the value and its band label.
    public var bandSeparator: String

    /// An optional second value shown after the first — the away score in
    /// `2 – 1`, the total in `12 / 50`. Formatted the same way, with no array
    /// operation and no math. Empty for a single value.
    public var secondaryPath: String

    /// Placed between the two values.
    public var separator: String

    /// A query with every field defaulted to doing nothing but the path.
    public init(
        path: String,
        arrayOperation: ArrayOperation = .none,
        mathOperation: MathOperation = .none,
        mathValue: String = "",
        format: Format = .number(decimals: nil),
        prefix: String = "",
        suffix: String = "",
        bandRules: [StatusRule] = [],
        bandPosition: BandPosition = .none,
        bandSeparator: String = " ",
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
        self.bandRules = bandRules
        self.bandPosition = bandPosition
        self.bandSeparator = bandSeparator
        self.secondaryPath = secondaryPath
        self.separator = separator
    }

    /// Every field is optional on the way in, so a query encoded before the
    /// band existed still decodes — a stored metric must not stop reading
    /// because the engine grew a field.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        path = try container.decodeIfPresent(String.self, forKey: .path) ?? ""
        arrayOperation = try container.decodeIfPresent(ArrayOperation.self, forKey: .arrayOperation) ?? .none
        mathOperation = try container.decodeIfPresent(MathOperation.self, forKey: .mathOperation) ?? .none
        mathValue = try container.decodeIfPresent(String.self, forKey: .mathValue) ?? ""
        format = try container.decodeIfPresent(Format.self, forKey: .format) ?? .number(decimals: nil)
        prefix = try container.decodeIfPresent(String.self, forKey: .prefix) ?? ""
        suffix = try container.decodeIfPresent(String.self, forKey: .suffix) ?? ""
        bandRules = try container.decodeIfPresent([StatusRule].self, forKey: .bandRules) ?? []
        bandPosition = try container.decodeIfPresent(BandPosition.self, forKey: .bandPosition) ?? .none
        bandSeparator = try container.decodeIfPresent(String.self, forKey: .bandSeparator) ?? " "
        secondaryPath = try container.decodeIfPresent(String.self, forKey: .secondaryPath) ?? ""
        separator = try container.decodeIfPresent(String.self, forKey: .separator) ?? ""
    }
}
