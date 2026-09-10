//
//  Arithmetic.swift
//  JSONPath
//

import Foundation

/// The math step, on `NSNumber` so a boolean stays a boolean when nothing is done.
enum Arithmetic {

    /// `number` with `operation` applied using `operand`. A missing operand
    /// leaves multiply and divide alone and adds or subtracts nothing; a zero
    /// divisor leaves the value alone.
    static func apply(_ operation: MathOperation, to number: NSNumber, operand: NSNumber?) -> NSNumber {
        switch operation {
        case .none:
            return number
        case .add:
            return NSNumber(value: number.doubleValue + (operand?.doubleValue ?? 0))
        case .subtract:
            return NSNumber(value: number.doubleValue - (operand?.doubleValue ?? 0))
        case .multiply:
            guard let operand else { return number }
            return NSNumber(value: number.doubleValue * operand.doubleValue)
        case .divide:
            guard let operand, operand.doubleValue != 0 else { return number }
            return NSNumber(value: number.doubleValue / operand.doubleValue)
        }
    }
}
