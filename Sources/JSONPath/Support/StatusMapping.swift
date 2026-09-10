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
    static func parse(_ text: String) -> [StatusRule] {
        text.split(separator: ",").compactMap { pair in
            let parts = pair.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { return nil }
            var key = String(parts[0]).trimmingCharacters(in: .whitespaces)
            let label = String(parts[1]).trimmingCharacters(in: .whitespaces)
            var mode: StatusRule.Mode = .equals
            if key == "*" { mode = .fallback; key = "" }
            else if key.hasPrefix("=") { mode = .exact; key.removeFirst() }
            else if key.hasPrefix("~") { mode = .contains; key.removeFirst() }
            return StatusRule(mode: mode, match: key, label: label)
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
    static func label(for rawValue: String, rules: [StatusRule]) -> String? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        for rule in rules where rule.mode != .fallback {
            switch rule.mode {
            case .equals where rule.match.caseInsensitiveCompare(value) == .orderedSame: return rule.label
            case .exact where rule.match == value: return rule.label
            case .contains where value.range(of: rule.match, options: .caseInsensitive) != nil: return rule.label
            default: continue
            }
        }
        return rules.first { $0.mode == .fallback }?.label
    }

    /// The label, or the trimmed value itself when no rule matches — an
    /// unmapped state still shows.
    static func labelOrValue(_ rawValue: String, rules: [StatusRule]) -> String {
        label(for: rawValue, rules: rules) ?? rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
