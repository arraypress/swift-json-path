//
//  Reductions.swift
//  JSONPath
//
//  A list of numbers to one number.
//

import Foundation

/// The array operations on plain doubles.
enum Reductions {

    /// The reduction, or nil when the operation has nothing to give: an
    /// average of nothing, a first of an empty list, a range with no values.
    /// `count` counts `itemCount` — the whole list, not the numeric values in
    /// it — because "how many items" is about the list.
    static func reduce(_ values: [Double], itemCount: Int, by operation: ArrayOperation) -> Double? {
        switch operation {
        case .none:
            return nil
        case .sum:
            return values.reduce(0, +)
        case .average:
            guard !values.isEmpty else { return nil }
            return values.reduce(0, +) / Double(values.count)
        case .max:
            return values.max()
        case .min:
            return values.min()
        case .count:
            return Double(itemCount)
        case .first:
            return values.first
        case .last:
            return values.last
        case .median:
            let sorted = values.sorted()
            guard !sorted.isEmpty else { return nil }
            let mid = sorted.count / 2
            return sorted.count.isMultiple(of: 2) ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
        case .range:
            guard let largest = values.max(), let smallest = values.min() else { return nil }
            return largest - smallest
        }
    }
}
