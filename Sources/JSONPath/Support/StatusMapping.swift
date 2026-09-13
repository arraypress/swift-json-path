//
//  StatusMapping.swift
//  JSONPath
//
//  The status table: text in, rules out, and a value to its label.
//

import Foundation

/// Parsing, serialising and applying status rules.
enum StatusMapping {

    /// `key:label` pairs split on commas; the prefix of each key picks the mode.
    ///
    /// The two-character comparisons are tested before the one-character ones,
    /// so `>=151` is "at least 151" and not an exact match on `>151`; the text
    /// prefixes are tested before the range separator, so `~1..2:Loading`
    /// stays a contains rule.
    static func parse(_ text: String) -> [StatusRule] {
        text.split(separator: ",").compactMap { pair in
            let parts = pair.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { return nil }
            var key = String(parts[0]).trimmingCharacters(in: .whitespaces)
            let label = String(parts[1]).trimmingCharacters(in: .whitespaces)
            var mode: StatusRule.Mode = .equals
            if key == "*" { mode = .fallback; key = "" }
            else if key.hasPrefix(">=") { mode = .atLeast; key.removeFirst(2) }
            else if key.hasPrefix("<=") { mode = .atMost; key.removeFirst(2) }
            else if key.hasPrefix(">") { mode = .above; key.removeFirst() }
            else if key.hasPrefix("<") { mode = .below; key.removeFirst() }
            else if key.hasPrefix("=") { mode = .exact; key.removeFirst() }
            else if key.hasPrefix("~") { mode = .contains; key.removeFirst() }
            else if key.contains("..") { mode = .range }
            return StatusRule(mode: mode, match: key.trimmingCharacters(in: .whitespaces), label: label)
        }
    }

    /// Rules back to text. A rule with nothing to match is dropped, except
    /// the fallback, which matches by having nothing.
    static func serialize(_ rules: [StatusRule]) -> String {
        rules.filter { $0.mode == .fallback || !$0.match.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { "\($0.mode.prefix)\($0.match.trimmingCharacters(in: .whitespaces)):\($0.label.trimmingCharacters(in: .whitespaces))" }
            .joined(separator: ", ")
    }

    /// The first matching rule wins; the fallback only when nothing else did.
    ///
    /// The value is read as a number once, up front, and the numeric rules
    /// miss when it is not one — a numeric range never matches a word.
    static func label(for rawValue: String, rules: [StatusRule]) -> String? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let number = NumberParsing.number(value)?.doubleValue
        for rule in rules where rule.mode != .fallback {
            if matches(rule, value: value, number: number) { return rule.label }
        }
        return rules.first { $0.mode == .fallback }?.label
    }

    /// The label, or the trimmed value itself when no rule matches — an
    /// unmapped state still shows.
    static func labelOrValue(_ rawValue: String, rules: [StatusRule]) -> String {
        label(for: rawValue, rules: rules) ?? rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Whether one rule matches, given the value as text and, where it read as
    /// one, as a number.
    private static func matches(_ rule: StatusRule, value: String, number: Double?) -> Bool {
        switch rule.mode {
        case .equals: rule.match.caseInsensitiveCompare(value) == .orderedSame
        case .exact: rule.match == value
        case .contains: value.range(of: rule.match, options: .caseInsensitive) != nil
        case .fallback: false
        case .range:
            if let number, let bounds = bounds(rule.match) {
                number >= bounds.low && number <= bounds.high
            } else { false }
        case .above, .atLeast, .below, .atMost:
            if let number, let bound = NumberParsing.number(rule.match)?.doubleValue {
                switch rule.mode {
                case .above: number > bound
                case .atLeast: number >= bound
                case .below: number < bound
                default: number <= bound
                }
            } else { false }
        }
    }

    /// `low..high` as a pair, reversed ends put back in order so `100..51`
    /// covers the same range as `51..100`.
    private static func bounds(_ text: String) -> (low: Double, high: Double)? {
        let parts = text.components(separatedBy: "..")
        guard parts.count == 2,
              let first = NumberParsing.number(parts[0].trimmingCharacters(in: .whitespaces))?.doubleValue,
              let second = NumberParsing.number(parts[1].trimmingCharacters(in: .whitespaces))?.doubleValue
        else { return nil }
        return first <= second ? (first, second) : (second, first)
    }
}
