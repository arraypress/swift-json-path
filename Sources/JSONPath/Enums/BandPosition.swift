//
//  BandPosition.swift
//  JSONPath
//

import Foundation

/// Where a band's label sits relative to the value it describes.
///
/// A band turns the number into a word — `160` into `Unhealthy` — and shows
/// it alongside the value rather than instead of it, which is what separates
/// it from ``Format/status(rules:)``.
public enum BandPosition: String, CaseIterable, Sendable, Hashable, Codable {

    /// No label, whatever the rules say. The default.
    case none

    /// Before the value: `Unhealthy 160`.
    case prefix

    /// After the value: `160 Unhealthy`.
    case suffix
}
