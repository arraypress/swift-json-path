//
//  ObjectReductionTests.swift
//  JSONPath
//

import XCTest
@testable import JSONPath

/// Reducing across an object's values, for services that key their answer by the thing you asked
/// for instead of listing it — npm's bulk downloads, Steam's `{"570": {…}}`.
final class ObjectReductionTests: XCTestCase {

    /// What `api.npmjs.org/downloads/point/last-month/react,vue,svelte` actually returns.
    private let bulk = #"""
    {"react":{"downloads":100,"package":"react"},
     "vue":{"downloads":50,"package":"vue"},
     "svelte":{"downloads":25,"package":"svelte"}}
    """#

    private func reduce(_ body: String, _ path: String, _ operation: ArrayOperation) -> String? {
        var query = Extraction(path: path)
        query.arrayOperation = operation
        var extractor = Extractor(query: query)
        _ = extractor.run(body)
        return extractor.rawValue
    }

    func testDownloadsAcrossEveryPackageAddUp() {
        XCTAssertEqual(reduce(bulk, "[+].downloads", .sum), "175.0")
    }

    func testTheObjectCanBeCounted() {
        XCTAssertEqual(reduce(bulk, "[#]", .count), "3.0")
    }

    func testTheAverageTheLargestAndTheSmallest() {
        XCTAssertEqual(reduce(bulk, "[~].downloads", .average), "58.333333333333336")
        XCTAssertEqual(reduce(bulk, "[^].downloads", .max), "100.0")
        XCTAssertEqual(reduce(bulk, "[v].downloads", .min), "25.0")
    }

    func testFirstAndLastRefuseAnObject() {
        /// A JSON object has no order. Answering would mean handing back whichever key the
        /// dictionary happened to iterate first — a different answer on a different run, and a
        /// wrong number nobody would think to doubt.
        XCTAssertNil(reduce(bulk, "[<].downloads", .first))
        XCTAssertNil(reduce(bulk, "[>].downloads", .last))
    }

    func testAListStillReducesTheWayItDid() {
        let list = #"{"orders":[{"price":10},{"price":20}]}"#
        XCTAssertEqual(reduce(list, "orders[+].price", .sum), "30.0")
        XCTAssertEqual(reduce(list, "orders[<].price", .first), "10.0", "order means something in a list")
        XCTAssertEqual(reduce(list, "orders[>].price", .last), "20.0")
    }

    func testAMissingKeyAcrossAnObjectIsStillNothing() {
        XCTAssertNil(reduce(bulk, "[+].missing", .sum))
    }

    func testAnObjectOfPlainNumbersIsNotMistakenForOne() {
        /// The values must be objects to have a key read out of them
        XCTAssertNil(reduce(#"{"a": 1, "b": 2}"#, "[+].downloads", .sum))
    }

    func testAnEmptyObjectReducesToNothing() {
        XCTAssertNil(reduce("{}", "[+].downloads", .sum))
    }
}
