//
//  StatusRule.swift
//  JSONPath
//

import Foundation

/// One row of a status table: what to match, how, and what to show.
///
/// Written as text, comma-separated, `match:Label`. A prefix on the match
/// picks the mode: none is a case-insensitive equal, `=` exact and
/// case-sensitive, `~` contains, and `*` alone matches whatever is left.
/// `none:Operational, minor:Minor Outage, *:Issues` is a status page.
public struct StatusRule: Sendable, Hashable, Codable {

    /// How ``match`` is compared.
    public var mode: Mode

    /// The text to compare against. Empty for the fallback.
    public var match: String

    /// What to show when the rule matches.
    public var label: String

    public init(mode: Mode = .equals, match: String = "", label: String = "") {
        self.mode = mode
        self.match = match
        self.label = label
    }
}
