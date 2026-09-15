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

/// A key that carries an index of its own, under an operation.
final class NestedIndexReductionTests: XCTestCase {

    private let buckets = #"""
    {"data": [
        {"starting_at": "2026-09-01", "results": [{"amount": "100.5"}]},
        {"starting_at": "2026-09-02", "results": [{"amount": "200"}]},
        {"starting_at": "2026-09-03", "results": []}
    ]}
    """#

    func testAnOperationBeforeAnIndexSumsAcrossTheList() {
        /// Anthropic's cost report: one bucket per day, the amount inside each. This used to
        /// read as the first day alone — the `[0]` won the branch choice over the `[+]`.
        let result = JSONPath.extract(Extraction(path: "data[+].results[0].amount", arrayOperation: .sum), from: buckets)
        XCTAssertEqual(result.rawValue, "300.5")
        let averaged = JSONPath.extract(Extraction(path: "data[~].results[0].amount", arrayOperation: .average), from: buckets)
        XCTAssertEqual(averaged.rawValue, "150.25", "the empty bucket has no value and is left out")
    }

    func testTheMathIsAppliedPerItemBeforeTheSum() {
        let result = JSONPath.extract(Extraction(path: "data[+].results[0].amount", arrayOperation: .sum,
                                                 mathOperation: .divide, mathValue: "100"), from: buckets)
        XCTAssertEqual(result.rawValue, "3.005")
    }

    func testAnIndexBeforeAnOperationStillReadsInsideOneItem() {
        let result = JSONPath.extract(Extraction(path: "data[0].results[+].amount", arrayOperation: .sum), from: buckets)
        XCTAssertEqual(result.rawValue, "100.5")
    }

    func testTheFirstBracketDecides() {
        XCTAssertNil(PathSyntax.index(in: "data[+].results[0].amount"), "the first bracket is an operation")
        XCTAssertEqual(PathSyntax.index(in: "data[0].results[+].amount"), 0)
        XCTAssertEqual(PathSyntax.operation(in: "data[+].results[0].amount"), .sum)
    }

    func testCompactRollsUpAtTheBoundary() {
        XCTAssertEqual(Format.compact.string(for: 999_999), "1m")
        XCTAssertEqual(Format.compact.string(for: 999_950), "1m")
        XCTAssertEqual(Format.compact.string(for: 999_940), "999.9k")
        XCTAssertEqual(Format.compact.string(for: 1_500), "1.5k")
        XCTAssertEqual(Format.compact.string(for: 2_000_000), "2m")
        XCTAssertEqual(Format.compact.string(for: 999), "999")
    }
}
