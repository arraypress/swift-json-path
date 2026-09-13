//
//  Extractor.swift
//  JSONPath
//
//  The engine: the body's shape decides the route, the path decides the value,
//  the query decides the arithmetic and the words.
//

import Foundation

/// One extraction, carrying the raw value the way through.
///
/// A struct with state rather than a pile of pure functions because the raw
/// value is a by-product of whichever branch found the number, and threading
/// it back out of six nested lookups by return value made every one of them
/// return a pair. It is created per call and discarded.
struct Extractor {

    let query: Extraction

    /// The primary value after math, before formatting; nil until something
    /// is found.
    var rawValue: String?

    init(query: Extraction) {
        self.query = query
    }

    /// The display string for a body.
    mutating func run(_ body: String) -> String {
        rawValue = nil
        var result = query.prefix

        if let dictionary = Document.object(body) {
            // A missed path on valid JSON extracts nothing. It must not fall
            // through to the plain-text branch, which would publish the whole
            // body as the value and record it as history.
            if let value = dictionaryValue(from: dictionary, path: query.path, arrayOperation: query.arrayOperation,
                                           math: query.mathOperation, mathValue: query.mathValue) {
                result.append(value)
            }
        } else if let array = Document.objectArray(body) {
            if let value = arrayValue(from: array, path: query.path, arrayOperation: query.arrayOperation,
                                      math: query.mathOperation, mathValue: query.mathValue) {
                result.append(value)
            }
        } else if let scalars = Document.scalarArray(body) {
            // Wrapped in an object so `[0]`, `[+]` and `[#]` address it.
            if let value = dictionaryValue(from: NSDictionary(dictionary: ["custom": scalars]), path: "custom\(query.path)",
                                           arrayOperation: query.arrayOperation, math: query.mathOperation, mathValue: query.mathValue) {
                result.append(value)
            }
        } else {
            // Plain text, or a single value: the body is the value. Through
            // the same formatter a keyed value gets, so a HEAD probe's "200"
            // can be status-mapped and a bare number gets its decimals.
            let plain = body.trimmingCharacters(in: .whitespacesAndNewlines)
            if !plain.isEmpty {
                if let formatted = scalarResult(plain, math: query.mathOperation, mathValue: query.mathValue) {
                    result.append(formatted)
                } else {
                    rawValue = plain
                    result.append(plain)
                }
            }
        }

        // The second value uses the same format and no arithmetic, and the
        // primary's raw value is restored afterwards so trend and history keep
        // following the first value.
        if !query.secondaryPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let primary = rawValue
            if let second = secondaryValue(path: query.secondaryPath, in: body) {
                result.append(query.separator)
                result.append(second)
            }
            rawValue = primary
        }

        result.append(query.suffix)
        return banded(result)
    }

    /// The band's label placed around the finished string.
    ///
    /// It reads the raw value, not the formatted one, so a band is a
    /// threshold on the number itself and survives any display format. No
    /// value found means no label — there is nothing to describe.
    private func banded(_ text: String) -> String {
        guard query.bandPosition != .none, !query.bandRules.isEmpty,
              let raw = rawValue,
              let label = StatusMapping.label(for: raw, rules: query.bandRules),
              !label.isEmpty
        else { return text }
        return switch query.bandPosition {
        case .prefix: label + query.bandSeparator + text
        case .suffix: text + query.bandSeparator + label
        case .none: text
        }
    }

    // MARK: - Routes

    private mutating func secondaryValue(path: String, in body: String) -> String? {
        if let dictionary = Document.object(body) {
            return dictionaryValue(from: dictionary, path: path, arrayOperation: .none, math: .none, mathValue: "")
        } else if let array = Document.objectArray(body) {
            return arrayValue(from: array, path: path, arrayOperation: .none, math: .none, mathValue: "")
        }
        return nil
    }

    private mutating func dictionaryValue(
        from dictionary: NSDictionary, path: String, arrayOperation: ArrayOperation,
        math: MathOperation, mathValue: String
    ) -> String? {
        // A direct key path: person.name.
        if let direct = keyPathValue(from: dictionary, path: path, math: math, mathValue: mathValue) {
            return direct.formatted
        }

        // An index into a list: orders[0].price, or prices[0] for scalars.
        else if let index = PathSyntax.index(in: path) {
            if let root = PathSyntax.rootPath(in: path), let key = PathSyntax.rootKey(in: path),
               let items = KeyPathWalk.value(forKeyPath: root, in: dictionary) as? [NSDictionary], items.count > index {
                return dictionaryValue(from: items[index], path: key, arrayOperation: arrayOperation, math: math, mathValue: mathValue)
            } else if let root = PathSyntax.rootPath(in: path), PathSyntax.rootKey(in: path) == nil,
                      let scalars = KeyPathWalk.value(forKeyPath: root, in: dictionary) as? [Any], scalars.count > index {
                return scalarResult(scalars[index], math: math, mathValue: mathValue)
            }
        }

        // An operation over a list: orders[+].price, or prices[+] for scalars.
        else if arrayOperation != .none {
            if let root = PathSyntax.rootPath(in: path),
               let items = KeyPathWalk.value(forKeyPath: root, in: dictionary) as? [NSDictionary] {
                return operationResult(arrayOperation, path: path, items: items, math: math, mathValue: mathValue)
            } else if let root = PathSyntax.rootPath(in: path),
                      let scalars = KeyPathWalk.value(forKeyPath: root, in: dictionary) as? [Any] {
                let wrapped = scalars.map { NSDictionary(dictionary: ["value": $0]) }
                return operationResult(arrayOperation, path: "[\(arrayOperation.symbol)].value", items: wrapped, math: math, mathValue: mathValue)
            }
        }

        return nil
    }

    private mutating func arrayValue(
        from array: [NSDictionary], path: String, arrayOperation: ArrayOperation,
        math: MathOperation, mathValue: String
    ) -> String? {
        // Counting a bare top-level list needs no element key.
        if arrayOperation == .count, PathSyntax.operation(in: path) == .count {
            return operationResult(.count, path: path, items: array, math: math, mathValue: mathValue)
        }
        guard let key = PathSyntax.rootKey(in: path) else { return nil }

        switch arrayOperation {
        case .none:
            // An explicit index addresses the Nth element of the actual list.
            // Filtering to key-bearing items first would silently re-point
            // `[N]` at "the Nth element that happens to have this key".
            guard let index = PathSyntax.index(in: path), array.count > index else { return nil }
            return dictionaryValue(from: array[index], path: key, arrayOperation: arrayOperation, math: math, mathValue: mathValue)
        default:
            guard PathSyntax.operation(in: path) == arrayOperation else { return nil }
            let bearing = array.filter { item in
                dictionaryValue(from: item, path: key, arrayOperation: arrayOperation, math: math, mathValue: mathValue) != nil
            }
            return dictionaryValue(from: NSDictionary(dictionary: ["custom": bearing]), path: "custom\(path)",
                                   arrayOperation: arrayOperation, math: math, mathValue: mathValue)
        }
    }

    // MARK: - Values

    /// A raw scalar (a number or a string) through the same math and format a
    /// keyed value takes.
    private mutating func scalarResult(_ element: Any, math: MathOperation, mathValue: String) -> String? {
        keyPathValue(from: NSDictionary(dictionary: ["value": element]), path: "value", math: math, mathValue: mathValue)?.formatted
    }

    /// The value at a key path: a number (through the math), a string, or a
    /// date carried as a string.
    private mutating func keyPathValue(
        from dictionary: NSDictionary, path: String, math: MathOperation, mathValue: String
    ) -> (formatted: String, raw: Any)? {
        // A date carried as a string — "2026-09-08T13:18", Wayback's
        // "20260908131848" — is read as one before the numeric lookup can
        // mistake its digits for an epoch.
        if case .date(let pattern) = query.format,
           let text = KeyPathWalk.string(forKeyPath: path, in: dictionary),
           let date = DateParsing.date(from: text) {
            rawValue = text
            return (DateFormatting.string(date, pattern: pattern), text)
        }

        if let number = KeyPathWalk.number(forKeyPath: path, in: dictionary) {
            let updated = Arithmetic.apply(math, to: number, operand: NumberParsing.number(mathValue))
            // The raw value is the post-math number: it is what alerts, trend
            // and history track, and it has to match what the user sees.
            rawValue = "\(updated.doubleValue)"
            return outputResult(from: updated)
        }

        if let text = KeyPathWalk.string(forKeyPath: path, in: dictionary) {
            rawValue = text
            switch query.format {
            case .number, .raw:
                return (text, text)
            case .date(let pattern):
                return (DateParsing.date(from: text).map { DateFormatting.string($0, pattern: pattern) } ?? text, text)
            case .status(let rules):
                return (StatusMapping.labelOrValue(text, rules: rules), text)
            default:
                // A string has no percentage or byte form; showing it beats
                // showing nothing — it is how a name sits next to a number as
                // the second value.
                return (text, text)
            }
        }
        return nil
    }

    /// An array operation over a list of objects.
    private mutating func operationResult(
        _ operation: ArrayOperation, path: String, items: [NSDictionary], math: MathOperation, mathValue: String
    ) -> String? {
        var numbers: [Double]?
        if let key = PathSyntax.rootKey(in: path) {
            numbers = items.compactMap { item in
                (keyPathValue(from: item, path: key, math: math, mathValue: mathValue)?.raw as? NSNumber)?.doubleValue
            }
        }
        // Count has no key and no numbers; every other operation needs both.
        if operation == .count {
            return aggregateResult(Double(items.count))
        }
        guard let numbers, let value = Reductions.reduce(numbers, itemCount: items.count, by: operation) else { return nil }
        return aggregateResult(value)
    }

    /// Publishes an aggregate as the raw value and formats it. The per-item
    /// loop above leaves the raw value on the last element; the aggregate has
    /// to replace it with the combined number.
    private mutating func aggregateResult(_ value: Double) -> String? {
        let number = NSNumber(value: value)
        rawValue = "\(number.doubleValue)"
        return outputResult(from: number)?.formatted
    }

    /// A number through the query's format.
    private func outputResult(from number: NSNumber) -> (formatted: String, raw: Any)? {
        switch query.format {
        case .raw:
            return (number.stringValue, number)
        case .compact:
            return (NumberFormatting.compact(number), number)
        case .delimited:
            return (NumberFormatting.delimited(number), number)
        case .percentage:
            return (NumberFormatting.percentage(number), number)
        case .currency(let code):
            return (NumberFormatting.currency(number, code: code), number)
        case .bytes:
            return (NumberFormatting.bytes(number), number)
        case .duration:
            return (NumberFormatting.duration(number), number)
        case .status(let rules):
            // A JSON boolean arrives as a number; it is matched as true/false
            // so a "true:Up, false:Down" table works, otherwise as the number
            // itself so "200:OK" does.
            let isBool = CFGetTypeID(number) == CFBooleanGetTypeID()
            let key = isBool ? (number.boolValue ? "true" : "false") : number.stringValue
            return (StatusMapping.labelOrValue(key, rules: rules), number)
        case .date(let pattern):
            return (DateFormatting.string(DateParsing.date(fromEpoch: number.doubleValue), pattern: pattern), number)
        case .number(let decimals):
            return (NumberFormatting.plain(number, decimals: decimals), number)
        }
    }
}
