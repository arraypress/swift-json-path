//
//  MathOperation.swift
//  JSONPath
//

import Foundation

/// Arithmetic applied to the extracted number before it is formatted.
///
/// The everyday case is division: an API that returns cents, a menu bar that
/// should show dollars. The operand comes from ``Extraction/mathValue``.
public enum MathOperation: String, CaseIterable, Sendable, Codable {

    /// Leave the number alone.
    case none

    /// Add the operand.
    case add

    /// Subtract the operand.
    case subtract

    /// Multiply by the operand.
    case multiply

    /// Divide by the operand. A zero or missing operand leaves the number
    /// alone — an infinity in the menu bar helps nobody.
    case divide

    /// The operator as written: `+ - * /`, empty for none.
    public var symbol: String {
        switch self {
        case .none: ""
        case .add: "+"
        case .subtract: "-"
        case .multiply: "*"
        case .divide: "/"
        }
    }
}
