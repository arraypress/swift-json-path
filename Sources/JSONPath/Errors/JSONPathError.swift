//
//  JSONPathError.swift
//  JSONPath
//

import Foundation

/// What was refused, in words a caller can print unchanged.
///
/// Only ``JSONPath/parse(_:)`` throws. Extraction never does: a path that finds
/// nothing is a nil raw value, which is the answer a polling metric needs.
public enum JSONPathError: Error, LocalizedError, Equatable, Sendable {

    /// The text is not JSON. Carries the parser's reason.
    case invalidJSON(String)

    public var errorDescription: String? {
        switch self {
        case .invalidJSON(let reason):
            return "not JSON: \(reason)"
        }
    }
}
