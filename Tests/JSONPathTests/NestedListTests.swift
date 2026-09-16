//
//  NestedListTests.swift
//  JSONPathTests
//
//  A list inside a list: brackets chain, the way a SQL-style API hands back rows
//

import XCTest
@testable import JSONPath

final class NestedListTests: XCTestCase {

    private func extract(_ body: String, _ path: String, _ operation: ArrayOperation = .none, format: Format = .number(decimals: nil)) -> Extraction.Result {
        JSONPath.extract(Extraction(path: path, arrayOperation: operation, mathOperation: .none, mathValue: "",
                                    format: format, prefix: "", suffix: "", secondaryPath: "", separator: ""), from: body)
    }

    func testARowsFirstColumn() {
        let body = #"{"results": [[1234]], "columns": ["count()"]}"#
        XCTAssertEqual(extract(body, "results[0][0]").display, "1,234")
        XCTAssertEqual(JSONPath.value(at: "results[0][0]", in: body), .number(1234))
    }

    func testAnyRowAnyColumn() {
        let body = #"{"results": [[1, "one"], [2, "two"]]}"#
        XCTAssertEqual(extract(body, "results[1][0]").display, "2")
        XCTAssertEqual(extract(body, "results[0][1]", format: .raw).display, "one")
        XCTAssertEqual(JSONPath.value(at: "results[1][1]", in: body), .string("two"))
    }

    func testATopLevelListOfLists() {
        XCTAssertEqual(extract("[[7, 8], [9]]", "[0][1]").display, "8")
        XCTAssertEqual(JSONPath.value(at: "[1][0]", in: "[[7, 8], [9]]"), .number(9))
    }

    func testAnObjectInsideARow() {
        let body = #"{"results": [[{"amount": 5}]]}"#
        XCTAssertEqual(extract(body, "results[0][0].amount").display, "5")
        XCTAssertEqual(JSONPath.value(at: "results[0][0].amount", in: body), .number(5))
    }

    func testDeeperStill() {
        let body = #"{"data": [{"rows": [[5, 6]]}]}"#
        XCTAssertEqual(extract(body, "data[0].rows[0][1]").display, "6")
    }

    func testAnOperationOverAColumn() {
        let body = #"{"matrix": [[1, 10], [3, 30], [5, 50]]}"#
        XCTAssertEqual(extract(body, "matrix[+][0]", .sum).display, "9")
        XCTAssertEqual(extract(body, "matrix[+][1]", .sum).display, "90")
        XCTAssertEqual(extract(body, "matrix[^][1]", .max).display, "50")
        XCTAssertEqual(JSONPath.value(at: "matrix[+][0]", in: body), .number(9))
    }

    func testAMissingRowOrColumnFindsNothing() {
        let body = #"{"results": [[1]]}"#
        XCTAssertNil(extract(body, "results[0][3]").rawValue)
        XCTAssertNil(extract(body, "results[2][0]").rawValue)
        XCTAssertNil(JSONPath.value(at: "results[0][3]", in: body))
    }

    func testTheOldShapesAreUntouched() {
        let body = #"{"data": [{"results": [{"amount": "1.5"}, {"amount": "2"}]}, {"results": [{"amount": "4"}]}]}"#
        XCTAssertEqual(extract(body, "data[0].results[+].amount", .sum).display, "3.5", "one bucket, summed")
        XCTAssertEqual(extract(body, "data[+].results[+].amount", .sum).display, "7.5", "every bucket, summed")
        XCTAssertEqual(extract(#"{"prices": [3, 4]}"#, "prices[1]").display, "4", "a scalar index")
        XCTAssertEqual(extract(#"{"prices": [3, 4]}"#, "prices[+]", .sum).display, "7", "a scalar sum")
    }
}
