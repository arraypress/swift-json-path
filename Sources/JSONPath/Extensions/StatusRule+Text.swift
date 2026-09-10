//
//  StatusRule+Text.swift
//  JSONPath
//
//  The text form the rules travel in.
//

import Foundation

extension StatusRule {

    /// Reads `key:label, ~key:label, =key:label, *:label` into rules.
    ///
    /// A pair with no colon is skipped rather than refused, so one typo in a
    /// long table does not blank a status page.
    public static func parse(_ text: String) -> [StatusRule] {
        StatusMapping.parse(text)
    }

    /// Writes rules back to the text form, dropping rules that match nothing.
    public static func serialize(_ rules: [StatusRule]) -> String {
        StatusMapping.serialize(rules)
    }

    /// The label the first matching rule gives, the fallback's if only that
    /// matches, nil if none does.
    public static func label(for value: String, rules: [StatusRule]) -> String? {
        StatusMapping.label(for: value, rules: rules)
    }
}
