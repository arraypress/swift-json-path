//
//  StatusRule.swift
//  JSONPath
//

import Foundation

/// One row of a status table: what to match, how, and what to show.
///
/// Written as text, comma-separated, `match:Label`. A prefix on the match
/// picks the mode: none is a case-insensitive equal, `=` exact and
/// case-sensitive, `~` contains, `>` `>=` `<` `<=` compare as numbers,
/// `low..high` ranges between two, and `*` alone matches whatever is left.
///
/// `none:Operational, minor:Minor Outage, *:Issues` is a status page.
/// `<=50:Good, <=100:Moderate, <=150:Unhealthy for Sensitive Groups,
/// <=200:Unhealthy, <=300:Very Unhealthy, *:Hazardous` is the US air
/// quality scale — the rules are tried in order, so ascending thresholds
/// read as the ranges between them.
public struct StatusRule: Sendable, Hashable, Codable {

    /// How ``match`` is compared.
    public var mode: Mode

    /// The text to compare against. Empty for the fallback.
    public var match: String

    /// What to show when the rule matches.
    public var label: String

    /// A rule; the defaults make an empty equals rule, which matches nothing.
    public init(mode: Mode = .equals, match: String = "", label: String = "") {
        self.mode = mode
        self.match = match
        self.label = label
    }
}
