//
//  BandTests.swift
//  JSONPath
//
//  The numeric comparison modes, and the band that shows their label beside
//  the value instead of in place of it.
//

import XCTest
@testable import JSONPath

private func extract(_ body: String, _ query: Extraction) -> Extraction.Result {
    JSONPath.extract(query, from: body)
}

/// The US air quality scale, the case the band was built for: ascending
/// thresholds read as the bands between them, and `*` takes the top.
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

    func testAReversedRangeBandsTheSameSpan() {
        XCTAssertEqual(StatusRule.label(for: "75", rules: StatusRule.parse("100..51:Moderate")), "Moderate")
    }

    func testANumericRuleNeverMatchesAWord() {
        let rules = StatusRule.parse("<=50:Good, *:Unknown")
        XCTAssertEqual(StatusRule.label(for: "offline", rules: rules), "Unknown", "text falls to the fallback, not into a band")
        XCTAssertNil(StatusRule.label(for: "offline", rules: StatusRule.parse("<=50:Good")))
    }

    func testAMalformedBoundMatchesNothingRatherThanEverything() {
        XCTAssertNil(StatusRule.label(for: "5", rules: StatusRule.parse("<=abc:Good")))
        XCTAssertNil(StatusRule.label(for: "5", rules: StatusRule.parse("1..abc:Good")))
        XCTAssertNil(StatusRule.label(for: "5", rules: StatusRule.parse("1..2..3:Good")))
    }

    func testAscendingThresholdsReadAsTheBandsBetweenThem() {
        let rules = StatusRule.parse(airQuality)
        XCTAssertEqual(StatusRule.label(for: "29", rules: rules), "Good")
        XCTAssertEqual(StatusRule.label(for: "78", rules: rules), "Moderate")
        XCTAssertEqual(StatusRule.label(for: "134", rules: rules), "Unhealthy for Sensitive Groups")
        XCTAssertEqual(StatusRule.label(for: "174", rules: rules), "Unhealthy")
        XCTAssertEqual(StatusRule.label(for: "250", rules: rules), "Very Unhealthy")
        XCTAssertEqual(StatusRule.label(for: "500", rules: rules), "Hazardous", "the fallback takes the top band")
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

final class BandTests: XCTestCase {

    func testABandShowsTheLabelBesideTheValueNotInsteadOfIt() {
        let query = Extraction(path: "aqi", bandRules: StatusRule.parse(airQuality), bandPosition: .suffix)
        XCTAssertEqual(extract(#"{"aqi": 174}"#, query).display, "174 Unhealthy")
        XCTAssertEqual(extract(#"{"aqi": 29}"#, query).display, "29 Good")
    }

    func testThePositionIsSettable() {
        let rules = StatusRule.parse(airQuality)
        XCTAssertEqual(extract(#"{"aqi": 174}"#, Extraction(path: "aqi", bandRules: rules, bandPosition: .prefix)).display, "Unhealthy 174")
        XCTAssertEqual(extract(#"{"aqi": 174}"#, Extraction(path: "aqi", bandRules: rules, bandPosition: .none)).display, "174",
                       "rules with nowhere to go show nothing")
    }

    func testTheSeparatorIsSettableAndDefaultsToASpace() {
        let rules = StatusRule.parse(airQuality)
        XCTAssertEqual(Extraction(path: "a").bandSeparator, " ")
        XCTAssertEqual(extract(#"{"aqi": 174}"#, Extraction(path: "aqi", bandRules: rules, bandPosition: .suffix, bandSeparator: " · ")).display, "174 · Unhealthy")
    }

    func testABandSitsOutsideTheSuffix() {
        let query = Extraction(path: "aqi", suffix: " AQI", bandRules: StatusRule.parse(airQuality), bandPosition: .suffix, bandSeparator: " · ")
        XCTAssertEqual(extract(#"{"aqi": 174}"#, query).display, "174 AQI · Unhealthy")
    }

    func testABandReadsTheRawValueNotTheFormattedOne() {
        /// Shown as money, banded on the number underneath it. The currency
        /// symbol is the machine's, so only the label is pinned here.
        let query = Extraction(path: "cents", mathOperation: .divide, mathValue: "100", format: .currency(code: "USD"),
                               bandRules: StatusRule.parse(">=100:Expensive, *:Cheap"), bandPosition: .suffix)
        let expensive = extract(#"{"cents": 24999}"#, query)
        XCTAssertEqual(expensive.rawValue, "249.99")
        XCTAssertTrue(expensive.display.hasSuffix(" Expensive"), "banded after the math — got \(expensive.display)")
        XCTAssertTrue(extract(#"{"cents": 500}"#, query).display.hasSuffix(" Cheap"))
    }

    func testABandMatchesANumberTheFormattedTextCouldNot() {
        /// `1,234,567` does not read as a number; a band that matches proves
        /// the rules saw the value and not the display string
        let query = Extraction(path: "n", format: .delimited,
                               bandRules: StatusRule.parse(">=1000000:Millions"), bandPosition: .suffix)
        XCTAssertTrue(extract(#"{"n": 1234567}"#, query).display.hasSuffix(" Millions"))
    }

    func testABandFollowsAnArrayOperationsAggregate() {
        let query = Extraction(path: "readings[~]", arrayOperation: .average,
                               bandRules: StatusRule.parse(airQuality), bandPosition: .suffix)
        XCTAssertEqual(extract(#"{"readings": [76, 80, 160]}"#, query).display, "105 Unhealthy for Sensitive Groups",
                       "the average, then the band on it")
    }

    func testNoValueMeansNoLabel() {
        let query = Extraction(path: "missing", bandRules: StatusRule.parse(airQuality), bandPosition: .suffix)
        XCTAssertEqual(extract(#"{"aqi": 174}"#, query).display, "", "nothing found is nothing to describe")
        XCTAssertNil(extract(#"{"aqi": 174}"#, query).rawValue)
    }

    func testAnUnmatchedValueKeepsTheValueAlone() {
        let query = Extraction(path: "aqi", bandRules: StatusRule.parse("<=50:Good"), bandPosition: .suffix)
        XCTAssertEqual(extract(#"{"aqi": 174}"#, query).display, "174", "no rule matched and no fallback given")
    }

    func testABandLeavesTheRawValueAlone() {
        /// Trend, alerts and history follow the number, which the label must not disturb
        let query = Extraction(path: "aqi", bandRules: StatusRule.parse(airQuality), bandPosition: .suffix)
        XCTAssertEqual(extract(#"{"aqi": 174}"#, query).rawValue, "174.0")
    }

    func testABandWorksAlongsideASecondValue() {
        let query = Extraction(path: "aqi", bandRules: StatusRule.parse(airQuality), bandPosition: .suffix,
                               secondaryPath: "city", separator: " · ")
        XCTAssertEqual(extract(#"{"aqi": 174, "city": "Bangkok"}"#, query).display, "174 · Bangkok Unhealthy")
    }

    func testABandOnText() {
        /// The rules are the same rules, so a text table bands too
        let query = Extraction(path: "state", format: .raw, bandRules: StatusRule.parse("live:🔴, *:⚪️"), bandPosition: .prefix)
        XCTAssertEqual(extract(#"{"state": "live"}"#, query).display, "🔴 live")
    }

    func testAQueryEncodedBeforeTheBandExistedStillDecodes() throws {
        let old = #"{"path": "n", "arrayOperation": "none", "mathOperation": "none", "mathValue": "", "prefix": "", "suffix": "", "secondaryPath": "", "separator": "", "format": {"number": {"decimals": null}}}"#
        let decoded = try JSONDecoder().decode(Extraction.self, from: Data(old.utf8))
        XCTAssertEqual(decoded.path, "n")
        XCTAssertEqual(decoded.bandRules, [])
        XCTAssertEqual(decoded.bandPosition, .none)
        XCTAssertEqual(decoded.bandSeparator, " ")
    }

    func testABandRoundTripsThroughCoding() throws {
        let query = Extraction(path: "aqi", bandRules: StatusRule.parse(airQuality), bandPosition: .suffix, bandSeparator: " · ")
        XCTAssertEqual(try JSONDecoder().decode(Extraction.self, from: JSONEncoder().encode(query)), query)
    }

    func testTheDefaultsStillDoNothing() {
        let extraction = Extraction(path: "n")
        XCTAssertEqual(extraction.bandPosition, .none)
        XCTAssertTrue(extraction.bandRules.isEmpty)
        XCTAssertEqual(extract(#"{"n": 7.9}"#, extraction).display, "8")
    }
}
