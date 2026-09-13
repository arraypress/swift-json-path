//
//  StatusRule+Mode.swift
//  JSONPath
//

import Foundation

extension StatusRule {

    /// The comparison a rule makes.
    ///
    /// The text modes compare the value as it reads; the numeric ones read it
    /// as a number first and miss when it is not one, so a text table and a
    /// numeric table can sit in the same list without either disturbing the
    /// other.
    public enum Mode: String, CaseIterable, Sendable, Codable {

        /// Equal, ignoring case. The default, and what a bare `live:On Air` means.
        case equals

        /// Equal, case-sensitive. Written `=live:On Air`.
        case exact

        /// The value contains the match, ignoring case. Written `~degraded:Issues`.
        case contains

        /// Greater than the match. Written `>300:Hazardous`.
        case above

        /// Greater than or equal to the match. Written `>=151:Unhealthy`.
        case atLeast

        /// Less than the match. Written `<0:Below Freezing`.
        case below

        /// Less than or equal to the match. Written `<=50:Good`.
        case atMost

        /// Inside `low..high`, both ends included. Written `51..100:Moderate`.
        ///
        /// The separator is `..` rather than `-` so a range over negative
        /// numbers — `-10..-5` — still reads.
        case range

        /// Anything no other rule matched. Written `*:Unknown`.
        case fallback

        /// Whether the rule reads its value as a number.
        public var isNumeric: Bool {
            switch self {
            case .above, .atLeast, .below, .atMost, .range: true
            case .equals, .exact, .contains, .fallback: false
            }
        }

        /// The prefix that selects this mode in the text form. ``range`` has
        /// none — its `..` separator is what identifies it.
        public var prefix: String {
            switch self {
            case .equals: ""
            case .exact: "="
            case .contains: "~"
            case .above: ">"
            case .atLeast: ">="
            case .below: "<"
            case .atMost: "<="
            case .range: ""
            case .fallback: "*"
            }
        }
    }
}
