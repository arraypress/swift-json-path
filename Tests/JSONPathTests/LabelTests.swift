//
//  LabelTests.swift
//  JSONPath
//
//  The numeric comparison modes, and the label they put beside
//  the value instead of in place of it.
//

import XCTest
@testable import JSONPath

private func extract(_ body: String, _ query: Extraction) -> Extraction.Result {
    JSONPath.extract(query, from: body)
}

/// The US air quality scale, the case this was built for: ascending
/// thresholds read as the ranges between them, and `*` takes the top.
private let airQuality = "<=50:Good, <=100:Moderate, <=150:Unhealthy for Sensitive Groups, <=200:Unhealthy, <=300:Very Unhealthy, *:Hazardous"

final class NumericModeTests: XCTestCase {

    func testEachPrefixPicksItsMode() {
        let rules = StatusRule.parse(">10:a, >=20:b, <30:c, <=40:d, 50..60:e, =x:f, ~y:g, *:h")
        XCTAssertEqual(rules.map(\.mode), [.above, .atLeast, .below, .atMost, .range, .exact, .contains, .fallback])
        XCTAssertEqual(rules.map(\.match), ["10", "20", "30", "40", "50..60", "x", "y", ""])
    }

    func testTheTwoCharacterComparisonsWinOverTheOneCharacterOnes() {
        /// `>=151` must not read as an exact match on the literal `>151`
        let rules = StatusRule.parse(">=151:Unhealthy, <=50:Good")
        XCTAssertEqual(rules.map(\.mode), [.atLeast, .atMost])
        XCTAssertEqual(rules.map(\.match), ["151", "50"])
    }

    func testATextPrefixWinsOverTheRangeSeparator() {
        let rules = StatusRule.parse("~1..2:Loading, =3..4:Exact")
        XCTAssertEqual(rules.map(\.mode), [.contains, .exact], "a dotted match behind ~ or = is still text")
    }

    func testComparisons() {
        XCTAssertEqual(StatusRule.label(for: "11", rules: StatusRule.parse(">10:over")), "over")
        XCTAssertNil(StatusRule.label(for: "10", rules: StatusRule.parse(">10:over")), "above is strict")
        XCTAssertEqual(StatusRule.label(for: "10", rules: StatusRule.parse(">=10:over")), "over")
        XCTAssertEqual(StatusRule.label(for: "9", rules: StatusRule.parse("<10:under")), "under")
        XCTAssertNil(StatusRule.label(for: "10", rules: StatusRule.parse("<10:under")), "below is strict")
        XCTAssertEqual(StatusRule.label(for: "10", rules: StatusRule.parse("<=10:under")), "under")
    }

    func testRangesIncludeBothEnds() {
        let rules = StatusRule.parse("51..100:Moderate")
        XCTAssertEqual(StatusRule.label(for: "51", rules: rules), "Moderate")
        XCTAssertEqual(StatusRule.label(for: "100", rules: rules), "Moderate")
        XCTAssertEqual(StatusRule.label(for: "75.5", rules: rules), "Moderate")
        XCTAssertNil(StatusRule.label(for: "50.9", rules: rules))
        XCTAssertNil(StatusRule.label(for: "100.1", rules: rules))
    }

    func testARangeOverNegativeNumbers() {
        /// The separator is `..` precisely so this reads
        XCTAssertEqual(StatusRule.label(for: "-7", rules: StatusRule.parse("-10..-5:Freezing")), "Freezing")
        XCTAssertNil(StatusRule.label(for: "-2", rules: StatusRule.parse("-10..-5:Freezing")))
    }

    func testAReversedRangeCoversTheSameSpan() {
        XCTAssertEqual(StatusRule.label(for: "75", rules: StatusRule.parse("100..51:Moderate")), "Moderate")
    }

    func testANumericRuleNeverMatchesAWord() {
        let rules = StatusRule.parse("<=50:Good, *:Unknown")
        XCTAssertEqual(StatusRule.label(for: "offline", rules: rules), "Unknown", "text falls to the fallback, not into a range")
        XCTAssertNil(StatusRule.label(for: "offline", rules: StatusRule.parse("<=50:Good")))
    }

    func testAMalformedBoundMatchesNothingRatherThanEverything() {
        XCTAssertNil(StatusRule.label(for: "5", rules: StatusRule.parse("<=abc:Good")))
        XCTAssertNil(StatusRule.label(for: "5", rules: StatusRule.parse("1..abc:Good")))
        XCTAssertNil(StatusRule.label(for: "5", rules: StatusRule.parse("1..2..3:Good")))
    }

    func testAscendingThresholdsReadAsTheRangesBetweenThem() {
        let rules = StatusRule.parse(airQuality)
        XCTAssertEqual(StatusRule.label(for: "29", rules: rules), "Good")
        XCTAssertEqual(StatusRule.label(for: "78", rules: rules), "Moderate")
        XCTAssertEqual(StatusRule.label(for: "134", rules: rules), "Unhealthy for Sensitive Groups")
        XCTAssertEqual(StatusRule.label(for: "174", rules: rules), "Unhealthy")
        XCTAssertEqual(StatusRule.label(for: "250", rules: rules), "Very Unhealthy")
        XCTAssertEqual(StatusRule.label(for: "500", rules: rules), "Hazardous", "the fallback takes the top range")
    }

    func testTheTextModesAreUnchanged() {
        XCTAssertEqual(StatusRule.label(for: "LIVE", rules: StatusRule.parse("live:On Air")), "On Air")
        XCTAssertNil(StatusRule.label(for: "LIVE", rules: StatusRule.parse("=live:On Air")))
        XCTAssertEqual(StatusRule.label(for: "degraded_performance", rules: StatusRule.parse("~degraded:Issues")), "Issues")
    }

    func testEveryModeRoundTripsThroughTheTextForm() {
        let text = ">10:a, >=20:b, <30:c, <=40:d, 50..60:e, =x:f, ~y:g, *:h"
        XCTAssertEqual(StatusRule.serialize(StatusRule.parse(text)), text)
        XCTAssertEqual(StatusRule.Mode.allCases.filter(\.isNumeric), [.above, .atLeast, .below, .atMost, .range])
    }
}

final class LabelTests: XCTestCase {

    func testALabelShowsBesideTheValueNotInsteadOfIt() {
        let query = Extraction(path: "aqi", labelRules: StatusRule.parse(airQuality), labelPosition: .suffix)
        XCTAssertEqual(extract(#"{"aqi": 174}"#, query).display, "174 Unhealthy")
        XCTAssertEqual(extract(#"{"aqi": 29}"#, query).display, "29 Good")
    }

    func testThePositionIsSettable() {
        let rules = StatusRule.parse(airQuality)
        XCTAssertEqual(extract(#"{"aqi": 174}"#, Extraction(path: "aqi", labelRules: rules, labelPosition: .prefix)).display, "Unhealthy 174")
        XCTAssertEqual(extract(#"{"aqi": 174}"#, Extraction(path: "aqi", labelRules: rules, labelPosition: .none)).display, "174",
                       "rules with nowhere to go show nothing")
    }

    func testTheSeparatorIsSettableAndDefaultsToASpace() {
        let rules = StatusRule.parse(airQuality)
        XCTAssertEqual(Extraction(path: "a").labelSeparator, " ")
        XCTAssertEqual(extract(#"{"aqi": 174}"#, Extraction(path: "aqi", labelRules: rules, labelPosition: .suffix, labelSeparator: " · ")).display, "174 · Unhealthy")
    }

    func testALabelSitsOutsideTheSuffix() {
        let query = Extraction(path: "aqi", suffix: " AQI", labelRules: StatusRule.parse(airQuality), labelPosition: .suffix, labelSeparator: " · ")
        XCTAssertEqual(extract(#"{"aqi": 174}"#, query).display, "174 AQI · Unhealthy")
    }

    func testALabelReadsTheRawValueNotTheFormattedOne() {
        /// Shown as money, labelled on the number underneath it. The currency
        /// symbol is the machine's, so only the label is pinned here.
        let query = Extraction(path: "cents", mathOperation: .divide, mathValue: "100", format: .currency(code: "USD"),
                               labelRules: StatusRule.parse(">=100:Expensive, *:Cheap"), labelPosition: .suffix)
        let expensive = extract(#"{"cents": 24999}"#, query)
        XCTAssertEqual(expensive.rawValue, "249.99")
        XCTAssertTrue(expensive.display.hasSuffix(" Expensive"), "labelled after the math — got \(expensive.display)")
        XCTAssertTrue(extract(#"{"cents": 500}"#, query).display.hasSuffix(" Cheap"))
    }

    func testALabelMatchesANumberTheFormattedTextCouldNot() {
        /// `1,234,567` does not read as a number; a rule that matches proves
        /// the rules saw the value and not the display string
        let query = Extraction(path: "n", format: .delimited,
                               labelRules: StatusRule.parse(">=1000000:Millions"), labelPosition: .suffix)
        XCTAssertTrue(extract(#"{"n": 1234567}"#, query).display.hasSuffix(" Millions"))
    }

    func testALabelFollowsAnArrayOperationsAggregate() {
        let query = Extraction(path: "readings[~]", arrayOperation: .average,
                               labelRules: StatusRule.parse(airQuality), labelPosition: .suffix)
        XCTAssertEqual(extract(#"{"readings": [76, 80, 160]}"#, query).display, "105 Unhealthy for Sensitive Groups",
                       "the average, then the label on it")
    }

    func testNoValueMeansNoLabel() {
        let query = Extraction(path: "missing", labelRules: StatusRule.parse(airQuality), labelPosition: .suffix)
        XCTAssertEqual(extract(#"{"aqi": 174}"#, query).display, "", "nothing found is nothing to describe")
        XCTAssertNil(extract(#"{"aqi": 174}"#, query).rawValue)
    }

    func testAnUnmatchedValueKeepsTheValueAlone() {
        let query = Extraction(path: "aqi", labelRules: StatusRule.parse("<=50:Good"), labelPosition: .suffix)
        XCTAssertEqual(extract(#"{"aqi": 174}"#, query).display, "174", "no rule matched and no fallback given")
    }

    func testALabelLeavesTheRawValueAlone() {
        /// Trend, alerts and history follow the number, which the label must not disturb
        let query = Extraction(path: "aqi", labelRules: StatusRule.parse(airQuality), labelPosition: .suffix)
        XCTAssertEqual(extract(#"{"aqi": 174}"#, query).rawValue, "174.0")
    }

    func testALabelWorksAlongsideASecondValue() {
        let query = Extraction(path: "aqi", labelRules: StatusRule.parse(airQuality), labelPosition: .suffix,
                               secondaryPath: "city", separator: " · ")
        XCTAssertEqual(extract(#"{"aqi": 174, "city": "Bangkok"}"#, query).display, "174 · Bangkok Unhealthy")
    }

    func testALabelOnText() {
        /// The rules are the same rules, so a text table labels too
        let query = Extraction(path: "state", format: .raw, labelRules: StatusRule.parse("live:🔴, *:⚪️"), labelPosition: .prefix)
        XCTAssertEqual(extract(#"{"state": "live"}"#, query).display, "🔴 live")
    }

    func testAQueryEncodedBeforeTheLabelExistedStillDecodes() throws {
        let old = #"{"path": "n", "arrayOperation": "none", "mathOperation": "none", "mathValue": "", "prefix": "", "suffix": "", "secondaryPath": "", "separator": "", "format": {"number": {"decimals": null}}}"#
        let decoded = try JSONDecoder().decode(Extraction.self, from: Data(old.utf8))
        XCTAssertEqual(decoded.path, "n")
        XCTAssertEqual(decoded.labelRules, [])
        XCTAssertEqual(decoded.labelPosition, .none)
        XCTAssertEqual(decoded.labelSeparator, " ")
    }

    func testALabelRoundTripsThroughCoding() throws {
        let query = Extraction(path: "aqi", labelRules: StatusRule.parse(airQuality), labelPosition: .suffix, labelSeparator: " · ")
        XCTAssertEqual(try JSONDecoder().decode(Extraction.self, from: JSONEncoder().encode(query)), query)
    }

    func testTheDefaultsStillDoNothing() {
        let extraction = Extraction(path: "n")
        XCTAssertEqual(extraction.labelPosition, .none)
        XCTAssertTrue(extraction.labelRules.isEmpty)
        XCTAssertEqual(extract(#"{"n": 7.9}"#, extraction).display, "8")
    }
}
