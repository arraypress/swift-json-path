//
//  Extraction+Result.swift
//  JSONPath
//

import Foundation

extension Extraction {

    /// What an extraction produced.
    public struct Result: Sendable, Hashable, Codable {

        /// The full display string: prefix, value, separator and second value,
        /// suffix. Prefix and suffix are present even when nothing was found,
        /// because that is what the caller asked to show around a value.
        public let display: String

        /// The primary value after math and before formatting — `42.5`, not
        /// `$42.50` — or the text itself for a plain-text body. Nil when the
        /// path found nothing.
        ///
        /// Alerts, trend arrows and history follow this, not ``display``: it
        /// has to be the number the user sees (dollars, not cents), and it
        /// has to be absent rather than empty when there was nothing, so the
        /// caller can keep its previous reading.
        public let rawValue: String?

        /// A result, as the engine produces it.
        public init(display: String, rawValue: String?) {
            self.display = display
            self.rawValue = rawValue
        }
    }
}
