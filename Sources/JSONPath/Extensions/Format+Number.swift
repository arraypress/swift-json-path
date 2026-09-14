//
//  Format+Number.swift
//  JSONPath
//

import Foundation

public extension Format {

    /// This format applied to a number that did not come from a path.
    ///
    /// A reading is extracted once and then shown again in other places — a
    /// chart's axis, a point's tooltip, a history row — from the stored number
    /// rather than the original response. Those have to read exactly as the
    /// menu bar does, and the only way to guarantee that is for them to go
    /// through the same switch.
    ///
    /// Callers used to reimplement it, which is how a delimited metric could
    /// come out grouped in one place and bare in another.
    func string(for number: NSNumber) -> String {
        switch self {
        case .raw:
            return number.stringValue
        case .compact:
            return NumberFormatting.compact(number)
        case .delimited:
            return NumberFormatting.delimited(number)
        case .percentage:
            return NumberFormatting.percentage(number)
        case .currency(let code):
            return NumberFormatting.currency(number, code: code)
        case .bytes:
            return NumberFormatting.bytes(number)
        case .duration:
            return NumberFormatting.duration(number)
        case .status(let rules):
            /// A JSON boolean arrives as a number; it is matched as true/false so a
            /// "true:Up, false:Down" table works, otherwise as the number itself so
            /// "200:OK" does.
            let isBool = CFGetTypeID(number) == CFBooleanGetTypeID()
            let key = isBool ? (number.boolValue ? "true" : "false") : number.stringValue
            return StatusMapping.labelOrValue(key, rules: rules)
        case .date(let pattern):
            return DateFormatting.string(DateParsing.date(fromEpoch: number.doubleValue), pattern: pattern)
        case .number(let decimals):
            return NumberFormatting.plain(number, decimals: decimals)
        }
    }
}
