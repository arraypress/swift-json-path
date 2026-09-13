//
//  SupportTests.swift
//  JSONPath
//
//  The pure functions on their own: a path split, a list reduced, a number
//  written, a date read, a rule matched — each with the edge that bit once.
//

import XCTest
@testable import JSONPath

final class PathSyntaxTests: XCTestCase {

    func testTheFirstBracketAndTheFirstDotDecide() {
        XCTAssertEqual(PathSyntax.rootPath(in: "orders[+].price"), "orders")
        XCTAssertEqual(PathSyntax.rootKey(in: "orders[+].price"), "price")
        XCTAssertEqual(PathSyntax.rootPath(in: "a.b[0].c.d"), "a.b")
        XCTAssertEqual(PathSyntax.rootKey(in: "a.b[0].c.d"), "c.d")
        XCTAssertEqual(PathSyntax.rootPath(in: "person.name"), "person")
        XCTAssertEqual(PathSyntax.rootKey(in: "person.name"), "name")
        XCTAssertNil(PathSyntax.rootPath(in: "total"))
        XCTAssertNil(PathSyntax.rootKey(in: "total"))
        XCTAssertEqual(PathSyntax.rootPath(in: "[#]"), "")
        XCTAssertNil(PathSyntax.rootKey(in: "[#]"), "nothing after the bracket")
        XCTAssertEqual(PathSyntax.rootKey(in: "[+].a"), "a")
        XCTAssertNil(PathSyntax.rootKey(in: "prices[0]x"), "a bracket must be followed by a dot to have a key")
    }

    func testIndexesAndMarkers() {
        XCTAssertEqual(PathSyntax.index(in: "orders[12].price"), 12)
        XCTAssertNil(PathSyntax.index(in: "orders[+].price"))
        XCTAssertNil(PathSyntax.index(in: "orders.price"))
        XCTAssertEqual(PathSyntax.index(in: "a[1].b[2]"), 1, "the first one")
        XCTAssertEqual(PathSyntax.operation(in: "orders[+].price"), .sum)
        XCTAssertEqual(PathSyntax.operation(in: "[#]"), .count)
        XCTAssertEqual(PathSyntax.operation(in: "x[v]"), .min)
        XCTAssertNil(PathSyntax.operation(in: "orders[0].price"), "digits are an index, not an operation")
        XCTAssertNil(PathSyntax.operation(in: "orders[?].price"))
        XCTAssertNil(PathSyntax.operation(in: "orders[].price"), "empty brackets are nothing")
        XCTAssertNil(PathSyntax.operation(in: ""))
    }
}

final class KeyPathWalkTests: XCTestCase {

    private let body: NSDictionary = [
        "a": ["b": ["c": 7]], "s": "text", "n": NSNull(), "@k": 1,
        "json": "{\"inner\": [1, 2]}", "looks": "[nope", "num": "42.5", "notnum": "4 2",
    ]

    func testWalksByHandThroughEveryShape() {
        XCTAssertEqual(KeyPathWalk.value(forKeyPath: "a.b.c", in: body) as? Int, 7)
        XCTAssertEqual(KeyPathWalk.value(forKeyPath: "@k", in: body) as? Int, 1)
        XCTAssertNil(KeyPathWalk.value(forKeyPath: "s.deeper", in: body), "a hop through a string is nothing, not a crash")
        XCTAssertNil(KeyPathWalk.value(forKeyPath: "n", in: body), "null is nothing")
        XCTAssertNil(KeyPathWalk.value(forKeyPath: "missing", in: body))
        XCTAssertNil(KeyPathWalk.value(forKeyPath: "", in: body))
    }

    func testEmbeddedJSONIsDecodedOnceItLooksLikeJSON() {
        XCTAssertEqual((KeyPathWalk.value(forKeyPath: "json.inner", in: body) as? [Any])?.count, 2)
        XCTAssertEqual(KeyPathWalk.string(forKeyPath: "looks", in: body), "[nope")
        XCTAssertEqual(KeyPathWalk.decodingEmbeddedJSON(" {\"x\": 1} ") as? NSDictionary, ["x": 1])
        XCTAssertEqual(KeyPathWalk.decodingEmbeddedJSON(5) as? Int, 5)
    }

    func testNumbersFromNumbersAndFromStrings() {
        XCTAssertEqual(KeyPathWalk.number(forKeyPath: "a.b.c", in: body), 7)
        XCTAssertEqual(KeyPathWalk.number(forKeyPath: "num", in: body), 42.5)
        XCTAssertNil(KeyPathWalk.number(forKeyPath: "notnum", in: body))
        XCTAssertNil(KeyPathWalk.number(forKeyPath: "s", in: body))
        XCTAssertNil(KeyPathWalk.string(forKeyPath: "a.b.c", in: body), "a number is not a string")
    }

    func testMachineFormatNumbers() {
        XCTAssertEqual(NumberParsing.number("42.0"), 42)
        XCTAssertEqual(NumberParsing.number("-3"), -3)
        XCTAssertEqual(NumberParsing.number("1e5"), 100_000)
        XCTAssertNil(NumberParsing.number("42,5"), "no locale: a comma is not a decimal point")
        XCTAssertNil(NumberParsing.number("42 rpm"))
        XCTAssertNil(NumberParsing.number(""))
    }
}

final class ReductionTests: XCTestCase {

    private let values: [Double] = [5, 1.5, 2.5]

    func testEveryReduction() {
        XCTAssertEqual(Reductions.reduce(values, itemCount: 3, by: .sum), 9)
        XCTAssertEqual(Reductions.reduce(values, itemCount: 3, by: .average), 3)
        XCTAssertEqual(Reductions.reduce(values, itemCount: 3, by: .max), 5)
        XCTAssertEqual(Reductions.reduce(values, itemCount: 3, by: .min), 1.5)
        XCTAssertEqual(Reductions.reduce(values, itemCount: 4, by: .count), 4, "count is the list, not the numbers")
        XCTAssertEqual(Reductions.reduce(values, itemCount: 3, by: .first), 5)
        XCTAssertEqual(Reductions.reduce(values, itemCount: 3, by: .last), 2.5)
        XCTAssertEqual(Reductions.reduce(values, itemCount: 3, by: .median), 2.5)
        XCTAssertEqual(Reductions.reduce([1, 2, 3, 10], itemCount: 4, by: .median), 2.5)
        XCTAssertEqual(Reductions.reduce(values, itemCount: 3, by: .range), 3.5)
        XCTAssertNil(Reductions.reduce(values, itemCount: 3, by: .none))
    }

    func testNothingToReduce() {
        XCTAssertEqual(Reductions.reduce([], itemCount: 0, by: .sum), 0)
        XCTAssertEqual(Reductions.reduce([], itemCount: 0, by: .count), 0)
        for operation: ArrayOperation in [.average, .max, .min, .first, .last, .median, .range] {
            XCTAssertNil(Reductions.reduce([], itemCount: 0, by: operation), "\(operation)")
        }
        XCTAssertEqual(Reductions.reduce([7], itemCount: 1, by: .median), 7)
        XCTAssertEqual(Reductions.reduce([7], itemCount: 1, by: .range), 0)
    }
}

final class NumberFormattingTests: XCTestCase {

    private func digits(_ text: String) -> String { text.filter { $0.isNumber || $0 == "." || $0 == "-" } }

    func testPlain() {
        XCTAssertEqual(digits(NumberFormatting.plain(1234.567, decimals: 2)), "1234.57")
        XCTAssertEqual(digits(NumberFormatting.plain(1234.567, decimals: nil)), "1235")
        XCTAssertEqual(digits(NumberFormatting.plain(0, decimals: 3)), "0.000")
        XCTAssertEqual(digits(NumberFormatting.plain(-0.5, decimals: 0)), "-0", "a half rounds to the even neighbour")
    }

    func testCompact() {
        XCTAssertEqual(NumberFormatting.compact(999), "999")
        XCTAssertEqual(NumberFormatting.compact(1000), "1k")
        XCTAssertEqual(NumberFormatting.compact(1500), "1.5k")
        XCTAssertEqual(NumberFormatting.compact(1_000_000), "1m")
        XCTAssertEqual(NumberFormatting.compact(2_250_000), "2.2m", "one decimal, and NumberFormatter rounds a half to the even neighbour")
        XCTAssertEqual(NumberFormatting.compact(2_260_000), "2.3m")
        XCTAssertEqual(NumberFormatting.compact(3_000_000_000), "3b")
        XCTAssertEqual(NumberFormatting.compact(-1500), "-1500", "below a thousand — negatives never shorten")
        XCTAssertEqual(NumberFormatting.compact(0), "0")
    }

    func testPercentageTruncatesAndSurvivesTheEdges() {
        XCTAssertEqual(NumberFormatting.percentage(0.1), "10%")
        XCTAssertEqual(NumberFormatting.percentage(0.999), "99%")
        XCTAssertEqual(NumberFormatting.percentage(-0.25), "-25%")
        XCTAssertEqual(NumberFormatting.percentage(1.5), "150%")
        XCTAssertEqual(NumberFormatting.percentage(NSNumber(value: Double.nan)), "0%")
        XCTAssertEqual(NumberFormatting.percentage(NSNumber(value: Double.infinity)), "0%")
        XCTAssertTrue(NumberFormatting.percentage(1e20).hasSuffix("%"))
    }

    func testBytesAndDuration() {
        XCTAssertEqual(NumberFormatting.bytes(1_048_576), "1 MB")
        XCTAssertEqual(NumberFormatting.bytes(0), "Zero KB")
        XCTAssertEqual(NumberFormatting.bytes(NSNumber(value: Double.nan)), "NaN".isEmpty ? "" : NumberFormatting.plain(NSNumber(value: Double.nan), decimals: 0))
        XCTAssertEqual(NumberFormatting.duration(3661), "1h 1m")
        XCTAssertEqual(NumberFormatting.duration(59), "59s")
        XCTAssertEqual(NumberFormatting.duration(90_000), "1d 1h")
        XCTAssertEqual(NumberFormatting.duration(0), "0s")
    }

    func testDelimitedAndCurrency() {
        XCTAssertEqual(NumberFormatting.delimited(1_234_567).filter(\.isNumber), "1234567")
        XCTAssertEqual(NumberFormatting.delimited(12.7).filter(\.isNumber), "13", "no fraction")
        XCTAssertEqual(NumberFormatting.currency(10, code: "USD").filter(\.isNumber), "10")
        XCTAssertEqual(NumberFormatting.currency(10.5, code: "USD").filter(\.isNumber), "1050")
        XCTAssertEqual(NumberFormatting.currency(10.555, code: "EUR").filter(\.isNumber), "1056", "two places, rounded")
    }
}

final class DateTests: XCTestCase {

    private func utc(_ date: Date?) -> String? {
        guard let date else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    func testTheShapesAPIsSend() {
        XCTAssertEqual(utc(DateParsing.date(from: "2026-09-09T12:00:00Z")), "2026-09-09T12:00:00Z")
        XCTAssertEqual(utc(DateParsing.date(from: "2026-09-09T12:00:00.250Z")), "2026-09-09T12:00:00Z", "fractional seconds read")
        XCTAssertEqual(utc(DateParsing.date(from: "2026-09-09T14:00:00+02:00")), "2026-09-09T12:00:00Z")
        XCTAssertEqual(utc(DateParsing.date(from: "1788915600")), "2026-09-09T01:00:00Z", "ten digits is seconds")
        XCTAssertEqual(utc(DateParsing.date(from: "1788915600000")), "2026-09-09T01:00:00Z", "thirteen is milliseconds")
        XCTAssertNotNil(DateParsing.date(from: "2026-09-09"))
        XCTAssertNotNil(DateParsing.date(from: "20260908131848"))
        XCTAssertNotNil(DateParsing.date(from: "Jul 12, 2026"))
        XCTAssertNotNil(DateParsing.date(from: "Sun, 13 Sep 2026 14:00:00 +0000"))
        XCTAssertNotNil(DateParsing.date(from: "  2026-09-09  "), "trimmed")
    }

    func testWhatIsNotADate() {
        XCTAssertNil(DateParsing.date(from: ""))
        XCTAssertNil(DateParsing.date(from: "   "))
        XCTAssertNil(DateParsing.date(from: "yesterday"))
        XCTAssertNil(DateParsing.date(from: "123456789"), "nine digits is neither seconds nor a date")
        XCTAssertNil(DateParsing.date(from: "42"))
    }

    func testEpochsWithTheMillisecondSwitch() {
        XCTAssertEqual(utc(DateParsing.date(fromEpoch: 1_788_915_600)), "2026-09-09T01:00:00Z")
        XCTAssertEqual(utc(DateParsing.date(fromEpoch: 1_788_915_600_000)), "2026-09-09T01:00:00Z")
        XCTAssertEqual(utc(DateParsing.date(fromEpoch: 0)), "1970-01-01T00:00:00Z")
    }

    func testFormattingUsesThePattern() {
        let date = DateParsing.date(from: "2026-09-13")!
        XCTAssertEqual(DateFormatting.string(date, pattern: "yyyy-MM-dd"), "2026-09-13")
        XCTAssertEqual(DateFormatting.string(date, pattern: "EEE d MMM"), "Sun 13 Sep")
        XCTAssertEqual(DateFormatting.string(date, pattern: ""), "")
    }
}

final class StatusMappingTests: XCTestCase {

    func testEveryModeParses() {
        let rules = StatusRule.parse("live:On Air, =Exact:Only, ~deg:Issues, *:Other")
        XCTAssertEqual(rules.map(\.mode), [.equals, .exact, .contains, .fallback])
        XCTAssertEqual(rules.map(\.match), ["live", "Exact", "deg", ""])
        XCTAssertEqual(rules.map(\.label), ["On Air", "Only", "Issues", "Other"])
    }

    func testMalformedPairsAreSkippedNotFatal() {
        let rules = StatusRule.parse("ok:Fine, garbage, :empty-key, also:this:has:colons")
        XCTAssertEqual(rules.count, 3)
        XCTAssertEqual(rules[1].match, "")
        XCTAssertEqual(rules[2].label, "this:has:colons", "split on the first colon only")
        XCTAssertEqual(StatusRule.parse("").count, 0)
    }

    func testTheFirstMatchWinsAndTheFallbackWaits() {
        let rules = StatusRule.parse("~out:Outage, minor:Minor, *:Unknown")
        XCTAssertEqual(StatusRule.label(for: "minor_outage", rules: rules), "Outage", "contains comes first in the table")
        XCTAssertEqual(StatusRule.label(for: "MINOR", rules: rules), "Minor")
        XCTAssertEqual(StatusRule.label(for: "  minor  ", rules: rules), "Minor", "the value is trimmed")
        XCTAssertEqual(StatusRule.label(for: "fine", rules: rules), "Unknown")
        XCTAssertNil(StatusRule.label(for: "fine", rules: StatusRule.parse("ok:Fine")))
        XCTAssertNil(StatusRule.label(for: "x", rules: []))
    }

    func testExactIsCaseSensitiveAndContainsIsNot() {
        XCTAssertNil(StatusRule.label(for: "Live", rules: StatusRule.parse("=live:On")))
        XCTAssertEqual(StatusRule.label(for: "live", rules: StatusRule.parse("=live:On")), "On")
        XCTAssertEqual(StatusRule.label(for: "DEGRADED", rules: StatusRule.parse("~degrad:Issues")), "Issues")
    }

    func testSerializeRoundTripsAndDropsEmptyRules() {
        let text = "live:On Air, =Exact:Only, ~deg:Issues, *:Other"
        XCTAssertEqual(StatusRule.serialize(StatusRule.parse(text)), text)
        XCTAssertEqual(StatusRule.serialize([StatusRule(mode: .equals, match: "  ", label: "x"), StatusRule(mode: .fallback, label: "F")]), "*:F")
        XCTAssertEqual(StatusRule.serialize([]), "")
    }

    func testLabelOrValue() {
        XCTAssertEqual(StatusMapping.labelOrValue(" 503 ", rules: StatusRule.parse("200:Up")), "503")
        XCTAssertEqual(StatusMapping.labelOrValue("200", rules: StatusRule.parse("200:Up")), "Up")
    }

    func testRulesRoundTripThroughCodable() throws {
        let rules = StatusRule.parse("a:A, ~b:B, =c:C, *:D")
        XCTAssertEqual(try JSONDecoder().decode([StatusRule].self, from: JSONEncoder().encode(rules)), rules)
        for mode in StatusRule.Mode.allCases {
            XCTAssertEqual(try JSONDecoder().decode(StatusRule.Mode.self, from: JSONEncoder().encode(mode)), mode)
        }
        XCTAssertEqual(StatusRule.Mode.allCases.map(\.prefix), ["", "=", "~", ">", ">=", "<", "<=", "", "*"])
        XCTAssertEqual(StatusRule.Mode.allCases.filter { $0.prefix.isEmpty }, [.equals, .range],
                       "equals is the bare default; range is identified by its .. separator rather than a prefix")
    }
}

final class ArithmeticTests: XCTestCase {

    func testEveryOperation() {
        XCTAssertEqual(Arithmetic.apply(.none, to: 10, operand: 3), 10)
        XCTAssertEqual(Arithmetic.apply(.add, to: 10, operand: 3), 13)
        XCTAssertEqual(Arithmetic.apply(.subtract, to: 10, operand: 3), 7)
        XCTAssertEqual(Arithmetic.apply(.multiply, to: 10, operand: 3), 30)
        XCTAssertEqual(Arithmetic.apply(.divide, to: 10, operand: 4), 2.5)
    }

    func testAMissingOrZeroOperand() {
        XCTAssertEqual(Arithmetic.apply(.add, to: 10, operand: nil), 10)
        XCTAssertEqual(Arithmetic.apply(.subtract, to: 10, operand: nil), 10)
        XCTAssertEqual(Arithmetic.apply(.multiply, to: 10, operand: nil), 10)
        XCTAssertEqual(Arithmetic.apply(.divide, to: 10, operand: nil), 10)
        XCTAssertEqual(Arithmetic.apply(.divide, to: 10, operand: 0), 10)
        XCTAssertEqual(Arithmetic.apply(.multiply, to: 10, operand: 0), 0, "multiplying by zero is a real answer")
    }

    func testABooleanStaysABooleanWhenNothingIsDone() {
        let flag = NSNumber(value: true)
        XCTAssertEqual(CFGetTypeID(Arithmetic.apply(.none, to: flag, operand: nil)), CFBooleanGetTypeID())
        XCTAssertNotEqual(CFGetTypeID(Arithmetic.apply(.add, to: flag, operand: 1)), CFBooleanGetTypeID())
    }
}

final class DocumentTests: XCTestCase {

    func testShapes() {
        XCTAssertNotNil(Document.object(#"{"a": 1}"#))
        XCTAssertNil(Document.object("[1]"))
        XCTAssertNotNil(Document.objectArray(#"[{"a": 1}]"#))
        XCTAssertNil(Document.objectArray("[1, 2]"), "scalars are not objects")
        XCTAssertNotNil(Document.scalarArray("[1, 2]"))
        XCTAssertNil(Document.scalarArray("42"), "a bare scalar is not a list")
        XCTAssertNil(Document.object("not json"))
    }

    func testNumberText() {
        XCTAssertEqual(Document.numberText(42), "42")
        XCTAssertEqual(Document.numberText(-42), "-42")
        XCTAssertEqual(Document.numberText(2.5), "2.5")
        XCTAssertEqual(Document.numberText(1e16), "1e+16")
        XCTAssertEqual(Document.numberText(999_999_999_999_999), "999999999999999")
        XCTAssertEqual(Document.numberText(Double.nan), "nan")
    }

    func testTypedConversionKeepsBooleansApartFromNumbers() {
        let typed = Document.typed(["t": true, "one": 1, "s": "x", "n": NSNull(), "l": [false]] as NSDictionary)
        XCTAssertEqual(typed.object?["t"], .bool(true))
        XCTAssertEqual(typed.object?["one"], .number(1))
        XCTAssertEqual(typed.object?["s"], .string("x"))
        XCTAssertEqual(typed.object?["n"], .null)
        XCTAssertEqual(typed.object?["l"], .array([.bool(false)]))
    }
}
