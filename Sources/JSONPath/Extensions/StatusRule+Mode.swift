//
//  StatusRule+Mode.swift
//  JSONPath
//

import Foundation

extension StatusRule {

    /// The comparison a rule makes.
    public enum Mode: String, CaseIterable, Sendable, Codable {

        /// Equal, ignoring case. The default, and what a bare `live:On Air` means.
        case equals

        /// Equal, case-sensitive. Written `=live:On Air`.
        case exact

        /// The value contains the match, ignoring case. Written `~degraded:Issues`.
        case contains

        /// Anything no other rule matched. Written `*:Unknown`.
        case fallback

        /// The prefix that selects this mode in the text form.
        public var prefix: String {
            switch self {
            case .equals: ""
            case .exact: "="
            case .contains: "~"
            case .fallback: "*"
            }
        }
    }
}
