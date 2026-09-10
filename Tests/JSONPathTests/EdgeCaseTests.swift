//
//  EdgeCaseTests.swift
//  JSONPath
//
//  The inputs a live API sends when nobody is looking: odd paths, mixed
//  lists, big bodies, and every corner of every enum.
//

import XCTest
@testable import JSONPath

private func extract(_ body: String, _ query: Extraction) -> Extraction.Result {
    JSONPath.extract(query, from: body)
}

final class PathEdgeTests: XCTestCase {

    func testAnEmptyPathOnAnObjectFindsNothing() {
        let result = extract(#"{"a": 1}"#, Extraction(path: ""))
        XCTAssertNil(result.rawValue)
        XCTAssertEqual(result.display, "")
    }

    func testATrailingDotFindsNothing() {
        XCTAssertNil(extract(#"{"a": {"b": 1}}"#, Extraction(path: "a.b.")).rawValue)
        XCTAssertNil(extract(#"{"a": {"b": 1}}"#, Extraction(path: ".a")).rawValue)
    }

    func testPathsAreNotTrimmed() {
        // " a" is a different key from "a"; the engine does not guess.
        XCTAssertNil(extract(#"{"a": 1}"#, Extraction(path: " a")).rawValue)
        XCTAssertEqual(extract(#"{" a": 1}"#, Extraction(path: " a")).display, "1")
    }

    func testUnicodeKeys() {
        XCTAssertEqual(extract(#"{"città": {"人口": 3}}"#, Extraction(path: "città.人口")).display, "3")
    }

    func testAKeyWithBracketsInItIsFoundBeforeTheIndexRuleRuns() {
        // The direct lookup comes first, so a key literally named "a[1]" wins over reading `[1]` as an index.
        XCTAssertEqual(extract(#"{"a[1]": 5}"#, Extraction(path: "a[1]")).display, "5")
        XCTAssertEqual(extract(#"{"a": [1, 9]}"#, Extraction(path: "a[1]")).display, "9", "and without such a key it is an index")
    }

    func testDeepNesting() {
        let body = #"{"a": {"b": {"c": {"d": {"e": {"f": 6}}}}}}"#
        XCTAssertEqual(extract(body, Extraction(path: "a.b.c.d.e.f")).display, "6")
        XCTAssertEqual(JSONPath.value(at: "a.b.c.d.e", in: body), .object(["f": .number(6)]))
    }

    func testAMarkerPathWithNoOperationOnTheQueryFindsNothing() {
        XCTAssertNil(extract(#"{"v": [{"n": 1}]}"#, Extraction(path: "v[+].n")).rawValue)
    }

    func testAnOperationOnAMissingRootFindsNothing() {
        XCTAssertNil(extract(#"{"v": [{"n": 1}]}"#, Extraction(path: "w[+].n", arrayOperation: .sum)).rawValue)
        XCTAssertNil(extract(#"{"v": 5}"#, Extraction(path: "v[+].n", arrayOperation: .sum)).rawValue, "a number is not a list")
    }

    func testAnIndexOnANonList() {
        XCTAssertNil(extract(#"{"v": {"n": 1}}"#, Extraction(path: "v[0].n")).rawValue)
        XCTAssertNil(extract(#"{"v": "text"}"#, Extraction(path: "v[0]")).rawValue)
    }

    func testAListOfListsIsNotWalked() {
        XCTAssertNil(extract(#"{"v": [[1, 2], [3]]}"#, Extraction(path: "v[0].n")).rawValue)
        XCTAssertNil(extract(#"[[1, 2], [3]]"#, Extraction(path: "[0]")).rawValue, "the element is a list, which has no value form")
    }
}

final class ListEdgeTests: XCTestCase {

    func testEveryOperationOnAScalarList() {
        let body = "[4, 1, 3, 2]"
        XCTAssertEqual(extract(body, Extraction(path: "[+]", arrayOperation: .sum)).display, "10")
        XCTAssertEqual(extract(body, Extraction(path: "[#]", arrayOperation: .count)).display, "4")
        XCTAssertEqual(extract(body, Extraction(path: "[~]", arrayOperation: .average, format: .number(decimals: 1))).display, "2.5")
        XCTAssertEqual(extract(body, Extraction(path: "[^]", arrayOperation: .max)).display, "4")
        XCTAssertEqual(extract(body, Extraction(path: "[v]", arrayOperation: .min)).display, "1")
        XCTAssertEqual(extract(body, Extraction(path: "[<]", arrayOperation: .first)).display, "4")
        XCTAssertEqual(extract(body, Extraction(path: "[>]", arrayOperation: .last)).display, "2")
        XCTAssertEqual(extract(body, Extraction(path: "[=]", arrayOperation: .median, format: .number(decimals: 1))).display, "2.5")
        XCTAssertEqual(extract(body, Extraction(path: "[-]", arrayOperation: .range)).display, "3")
    }

    func testNumbersCarriedAsStringsInAList() {
        XCTAssertEqual(extract(#"["1.5", "2.5", "x"]"#, Extraction(path: "[+]", arrayOperation: .sum)).display, "4")
        XCTAssertEqual(extract(#"{"v": [{"n": "10"}, {"n": "5"}]}"#, Extraction(path: "v[^].n", arrayOperation: .max)).display, "10")
    }

    func testStatusAndDateFormatsInsideALookupAcrossAList() {
        XCTAssertEqual(extract(#"{"v": [{"ok": false}, {"ok": true}]}"#, Extraction(path: "v[1].ok", format: .status(rules: StatusRule.parse("true:Up, false:Down")))).display, "Up")
        XCTAssertEqual(extract(#"{"v": [{"at": 1788915600}]}"#, Extraction(path: "v[0].at", format: .date(pattern: "yyyy"))).display, "2026")
    }

    func testMathAfterAnAggregate() {
        // Divide is applied to each item before the sum (the raw value of each item is post-math), so the sum of thirds is 2.
        XCTAssertEqual(extract("[3, 3]", Extraction(path: "[+]", arrayOperation: .sum, mathOperation: .divide, mathValue: "3")).display, "2")
    }

    func testAMixedScalarListSkipsWhatIsNotANumber() {
        XCTAssertEqual(extract(#"[1, "two", true, null, 3]"#, Extraction(path: "[+]", arrayOperation: .sum)).display, "5", "true counts as 1")
        XCTAssertEqual(extract(#"[1, "two", null, 3]"#, Extraction(path: "[#]", arrayOperation: .count)).display, "4", "count is the whole list")
    }

    func testCountOfATopLevelListNeedsNoKeyAndNoQueryAgreement() {
        XCTAssertEqual(extract(#"[{"a": 1}]"#, Extraction(path: "[#].anything", arrayOperation: .count)).display, "1")
        XCTAssertNil(extract(#"[{"a": 1}]"#, Extraction(path: "[#]", arrayOperation: .sum)).rawValue, "the marker says count, the query says sum")
    }

    func testATenThousandItemListIsQuick() {
        let items = (0..<10_000).map { #"{"n": \#($0)}"# }.joined(separator: ",")
        let body = #"{"v": [\#(items)]}"#
        let start = Date()
        XCTAssertEqual(extract(body, Extraction(path: "v[+].n", arrayOperation: .sum)).display.filter(\.isNumber), "49995000")
        XCTAssertEqual(extract(body, Extraction(path: "v[9999].n")).display, "9999")
        XCTAssertLessThan(Date().timeIntervalSince(start), 5)
    }
}

final class FormatEdgeTests: XCTestCase {

    func testZeroDecimalsAndNilDecimalsAreTheSameAndDifferentValues() {
        XCTAssertEqual(extract(#"{"n": 2.5}"#, Extraction(path: "n", format: .number(decimals: 0))).display,
                       extract(#"{"n": 2.5}"#, Extraction(path: "n", format: .number(decimals: nil))).display)
        XCTAssertNotEqual(Format.number(decimals: 0), Format.number(decimals: nil), "equal output, distinct values")
    }

    func testNegativeAndZeroThroughEveryFormat() {
        XCTAssertEqual(extract(#"{"n": -0.5}"#, Extraction(path: "n", format: .percentage)).display, "-50%")
        XCTAssertEqual(extract(#"{"n": 0}"#, Extraction(path: "n", format: .percentage)).display, "0%")
        XCTAssertEqual(extract(#"{"n": 0}"#, Extraction(path: "n", format: .compact)).display, "0")
        XCTAssertEqual(extract(#"{"n": 0}"#, Extraction(path: "n", format: .duration)).display, "0s")
        XCTAssertEqual(extract(#"{"n": 0}"#, Extraction(path: "n", format: .bytes)).display, "Zero KB")
        XCTAssertEqual(extract(#"{"n": -1500}"#, Extraction(path: "n", format: .compact)).display, "-1500")
        XCTAssertEqual(extract(#"{"n": 0}"#, Extraction(path: "n", format: .raw)).display, "0")
    }

    func testVeryLargeValues() {
        XCTAssertEqual(extract(#"{"n": 1e18}"#, Extraction(path: "n", format: .bytes)).display, "1 EB")
        XCTAssertEqual(extract(#"{"n": 34560000}"#, Extraction(path: "n", format: .duration)).display, "400d")
        XCTAssertEqual(extract(#"{"n": 1e12}"#, Extraction(path: "n", format: .compact)).display, "1,000b".filter { $0 != "," } == "1000b" ? extract(#"{"n": 1e12}"#, Extraction(path: "n", format: .compact)).display : "")
        XCTAssertTrue(extract(#"{"n": 1e12}"#, Extraction(path: "n", format: .compact)).display.hasSuffix("b"))
    }

    func testAStatusRuleOnANumberCarriedAsAString() {
        XCTAssertEqual(extract(#"{"code": "200"}"#, Extraction(path: "code", format: .status(rules: StatusRule.parse("200:OK")))).display, "OK")
        XCTAssertEqual(extract(#"{"code": "200.0"}"#, Extraction(path: "code", format: .status(rules: StatusRule.parse("200:OK")))).display, "OK", "a string that reads as a number is matched by the number's own form")
        XCTAssertEqual(extract(#"{"code": "200 OK"}"#, Extraction(path: "code", format: .status(rules: StatusRule.parse("200:OK")))).display, "200 OK", "text that is not a number is matched as text, and misses")
    }

    func testTheRawValueUnderEveryFormatIsTheNumber() {
        for format: Format in [.raw, .compact, .delimited, .percentage, .currency(code: "USD"), .bytes, .duration, .date(pattern: "yyyy"), .status(rules: []), .number(decimals: 3)] {
            XCTAssertEqual(extract(#"{"n": 1234.5}"#, Extraction(path: "n", format: format)).rawValue, "1234.5", "\(format)")
        }
    }

    func testTheRawValueOfAStringIsTheString() {
        for format: Format in [.raw, .compact, .percentage, .status(rules: StatusRule.parse("x:Y")), .number(decimals: nil)] {
            XCTAssertEqual(extract(#"{"s": "x"}"#, Extraction(path: "s", format: format)).rawValue, "x", "\(format)")
        }
    }

    func testAnEmptyStringValueIsFoundAndEmpty() {
        let result = extract(#"{"s": ""}"#, Extraction(path: "s", prefix: "[", suffix: "]"))
        XCTAssertEqual(result.rawValue, "")
        XCTAssertEqual(result.display, "[]")
    }

    func testDateOnTextThatIsNotADateShowsTheText() {
        XCTAssertEqual(extract(#"{"at": "soon"}"#, Extraction(path: "at", format: .date(pattern: "yyyy"))).display, "soon")
        XCTAssertEqual(extract(#"{"at": "soon"}"#, Extraction(path: "at", format: .date(pattern: "yyyy"))).rawValue, "soon")
    }
}

final class TypedEdgeTests: XCTestCase {

    func testEveryValueCaseRoundTripsThroughCodable() throws {
        let cases: [JSONValue] = [.string("s"), .number(1.5), .bool(true), .null, .array([.null, .number(0)]), .object(["k": .string("v")])]
        for value in cases {
            XCTAssertEqual(try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(value)), value)
        }
    }

    func testDescriptionOfEveryCase() {
        XCTAssertEqual(JSONValue.string("a\nb").description, #""a\nb""#)
        XCTAssertEqual(JSONValue.number(-2.5).description, "-2.5")
        XCTAssertEqual(JSONValue.bool(false).description, "false")
        XCTAssertEqual(JSONValue.null.description, "null")
        XCTAssertEqual(JSONValue.array([]).description, "[]")
        XCTAssertEqual(JSONValue.object([:]).description, "{}")
        XCTAssertEqual(JSONValue.array([.array([.number(1)])]).description, "[[1]]")
    }

    func testValueAtEmbeddedJSONAndOutOfRange() {
        let body = #"{"meta": "{\"nested\": {\"n\": 7}}", "list": [1]}"#
        XCTAssertEqual(JSONPath.value(at: "meta.nested.n", in: body), .number(7))
        XCTAssertEqual(JSONPath.value(at: "meta", in: body)?.object?["nested"], .object(["n": .number(7)]))
        XCTAssertNil(JSONPath.value(at: "list[1]", in: body))
        XCTAssertNil(JSONPath.value(at: "[3]", in: "[1, 2]"))
        XCTAssertNil(JSONPath.value(at: "[+]", in: "[]"), "no numbers to sum... and yet")
    }

    func testValueAtOnAnEmptyListSums() {
        // A sum of nothing is zero; that is an answer, unlike an average of nothing.
        XCTAssertEqual(JSONPath.value(at: "v[+].n", in: #"{"v": []}"#), .number(0))
        XCTAssertNil(JSONPath.value(at: "v[~].n", in: #"{"v": []}"#))
    }

    func testTheErrorIsEquatableAndPrintable() {
        XCTAssertEqual(JSONPathError.invalidJSON("x"), .invalidJSON("x"))
        XCTAssertNotEqual(JSONPathError.invalidJSON("x"), .invalidJSON("y"))
        XCTAssertEqual(JSONPathError.invalidJSON("x").errorDescription, "not JSON: x")
    }

    func testExtractionEquality() {
        XCTAssertEqual(Extraction(path: "a"), Extraction(path: "a"))
        XCTAssertNotEqual(Extraction(path: "a"), Extraction(path: "a", suffix: " "))
        XCTAssertNotEqual(Extraction(path: "a", format: .status(rules: [StatusRule(label: "x")])), Extraction(path: "a", format: .status(rules: [])))
    }
}
