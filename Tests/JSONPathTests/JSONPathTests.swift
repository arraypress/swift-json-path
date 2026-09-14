//
//  JSONPathTests.swift
//  JSONPath
//
//  Every test is a fixed body and a fixed query with one right display
//  string — the behaviour MetricBar's suite pinned, plus the edges around it.
//  Recorded API responses live in Fixtures/.
//

import XCTest
@testable import JSONPath

/// A query in the shape a saved metric stores.
private func query(
    _ path: String,
    operation: ArrayOperation = .none,
    format: Format = .number(decimals: nil),
    math: MathOperation = .none,
    mathValue: String = "",
    prefix: String = "",
    suffix: String = "",
    secondary: String = "",
    separator: String = ""
) -> Extraction {
    Extraction(path: path, arrayOperation: operation, mathOperation: math, mathValue: mathValue,
               format: format, prefix: prefix, suffix: suffix, secondaryPath: secondary, separator: separator)
}

private func extract(_ body: String, _ query: Extraction) -> Extraction.Result {
    JSONPath.extract(query, from: body)
}

private func fixture(_ name: String) throws -> String {
    let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"), "missing fixture \(name)")
    return try String(contentsOf: url, encoding: .utf8)
}

private let orders = #"{"orders": [{"price": 1.5}, {"price": 2.5}, {"price": 5}]}"#

final class KeyPathAndMathTests: XCTestCase {

    func testADottedKeyPath() {
        XCTAssertEqual(extract(#"{"data": {"total": 42}}"#, query("data.total")).display, "42")
        XCTAssertEqual(extract(#"{"data": {"total": 42}}"#, query("data.total")).rawValue, "42.0")
    }

    func testCentsIntoDollars() {
        let result = extract(#"{"balance": 4250}"#, query("balance", format: .number(decimals: 2), math: .divide, mathValue: "100"))
        XCTAssertEqual(result.display, "42.50")
        XCTAssertEqual(result.rawValue, "42.5", "the raw value is the post-math number — what alerts and charts track")
    }

    func testEveryMathOperation() {
        XCTAssertEqual(extract(#"{"n": 10}"#, query("n", math: .add, mathValue: "5")).display, "15")
        XCTAssertEqual(extract(#"{"n": 10}"#, query("n", math: .subtract, mathValue: "4")).display, "6")
        XCTAssertEqual(extract(#"{"n": 10}"#, query("n", math: .multiply, mathValue: "3")).display, "30")
        XCTAssertEqual(extract(#"{"n": 10}"#, query("n", format: .number(decimals: 1), math: .divide, mathValue: "4")).display, "2.5")
    }

    func testDivisionByZeroLeavesTheValueAlone() {
        XCTAssertEqual(extract(#"{"balance": 4250}"#, query("balance", math: .divide, mathValue: "0")).display, "4,250")
        XCTAssertEqual(extract(#"{"balance": 4250}"#, query("balance", math: .divide, mathValue: "")).display, "4,250")
    }

    func testANonNumericOperandLeavesMultiplyAloneAndAddsNothing() {
        XCTAssertEqual(extract(#"{"n": 10}"#, query("n", math: .multiply, mathValue: "lots")).display, "10")
        XCTAssertEqual(extract(#"{"n": 10}"#, query("n", math: .add, mathValue: "lots")).display, "10")
    }

    func testMathAppliesToANumberCarriedAsAString() {
        let result = extract(#"{"n": "250"}"#, query("n", format: .number(decimals: 1), math: .divide, mathValue: "100"))
        XCTAssertEqual(result.display, "2.5")
        XCTAssertEqual(result.rawValue, "2.5")
    }

    func testANegativeNumber() {
        XCTAssertEqual(extract(#"{"n": -12.75}"#, query("n", format: .number(decimals: 2))).display, "-12.75")
        XCTAssertEqual(extract(#"{"n": -12.75}"#, query("n")).display, "-13")
    }

    func testAKeyThatStartsWithAnAtSign() {
        XCTAssertEqual(extract(#"{"@id": 7, "meta": {"@count": 3}}"#, query("@id")).display, "7")
        XCTAssertEqual(extract(#"{"@id": 7, "meta": {"@count": 3}}"#, query("meta.@count")).display, "3")
    }

    func testAHopThroughANonObjectFindsNothing() {
        let result = extract(#"{"data": "text"}"#, query("data.total"))
        XCTAssertNil(result.rawValue)
        XCTAssertEqual(result.display, "")
    }

    func testNullIsNothing() {
        let result = extract(#"{"total": null}"#, query("total", prefix: "$"))
        XCTAssertNil(result.rawValue)
        XCTAssertEqual(result.display, "$")
    }

    func testABooleanIsANumberToTheNumberFormat() {
        XCTAssertEqual(extract(#"{"ok": true}"#, query("ok")).display, "1")
        XCTAssertEqual(extract(#"{"ok": false}"#, query("ok", format: .raw)).display, "0")
    }
}

final class ArrayOperationTests: XCTestCase {

    func testEveryOperationOverAListOfObjects() {
        XCTAssertEqual(extract(orders, query("orders[+].price", operation: .sum)).display, "9")
        XCTAssertEqual(extract(orders, query("orders[#].price", operation: .count)).display, "3")
        XCTAssertEqual(extract(orders, query("orders[~].price", operation: .average)).display, "3")
        XCTAssertEqual(extract(orders, query("orders[^].price", operation: .max)).display, "5")
        XCTAssertEqual(extract(orders, query("orders[v].price", operation: .min, format: .number(decimals: 1))).display, "1.5")
        XCTAssertEqual(extract(orders, query("orders[<].price", operation: .first, format: .number(decimals: 1))).display, "1.5")
        XCTAssertEqual(extract(orders, query("orders[>].price", operation: .last)).display, "5")
        XCTAssertEqual(extract(orders, query("orders[=].price", operation: .median, format: .number(decimals: 1))).display, "2.5")
        XCTAssertEqual(extract(orders, query("orders[-].price", operation: .range, format: .number(decimals: 1))).display, "3.5")
    }

    func testTheAggregateIsTheRawValue() {
        XCTAssertEqual(extract(orders, query("orders[+].price", operation: .sum)).rawValue, "9.0")
        XCTAssertEqual(extract(orders, query("orders[#].price", operation: .count)).rawValue, "3.0")
    }

    func testAnIndexAddressesOneElement() {
        XCTAssertEqual(extract(orders, query("orders[1].price", format: .number(decimals: 1))).display, "2.5")
        XCTAssertEqual(extract(orders, query("orders[0].price", format: .number(decimals: 1))).display, "1.5")
        XCTAssertNil(extract(orders, query("orders[3].price")).rawValue, "past the end is nothing")
    }

    func testTheQueryAndThePathMustAgree() {
        // The path says sum, the query says average: nothing, rather than a guess.
        XCTAssertNil(extract(#"[{"a": 1}, {"a": 2}]"#, query("[+].a", operation: .average)).rawValue)
        // A sum over a path with no marker: the direct lookup fails, the
        // operation route runs on whatever list is at the root.
        XCTAssertEqual(extract(orders, query("orders.price", operation: .sum)).display, "9")
    }

    func testMathAppliesPerItemBeforeTheAggregate() {
        // Each price divided by 100, then summed: 0.09.
        XCTAssertEqual(extract(orders, query("orders[+].price", operation: .sum, format: .number(decimals: 2), math: .divide, mathValue: "100")).display, "0.09")
    }

    func testAnEvenMedianIsTheMeanOfTheMiddleTwo() {
        let four = #"{"v": [{"n": 1}, {"n": 2}, {"n": 3}, {"n": 10}]}"#
        XCTAssertEqual(extract(four, query("v[=].n", operation: .median, format: .number(decimals: 1))).display, "2.5")
    }

    func testItemsWithoutTheKeyAreSkipped() {
        let mixed = #"{"v": [{"n": 1}, {"other": 2}, {"n": 3}]}"#
        XCTAssertEqual(extract(mixed, query("v[+].n", operation: .sum)).display, "4")
        XCTAssertEqual(extract(mixed, query("v[#].n", operation: .count)).display, "3", "count is the list, not the values")
        XCTAssertEqual(extract(mixed, query("v[~].n", operation: .average)).display, "2")
    }

    func testAnEmptyListGivesNothingExceptACount() {
        let empty = #"{"v": []}"#
        XCTAssertEqual(extract(empty, query("v[+].n", operation: .sum)).display, "0")
        XCTAssertNil(extract(empty, query("v[~].n", operation: .average)).rawValue)
        XCTAssertNil(extract(empty, query("v[<].n", operation: .first)).rawValue)
        XCTAssertNil(extract(empty, query("v[=].n", operation: .median)).rawValue)
        XCTAssertNil(extract(empty, query("v[-].n", operation: .range)).rawValue)
        XCTAssertEqual(extract(empty, query("v[#]", operation: .count)).display, "0")
    }

    func testANestedRootIsWalkedAsAKeyPath() {
        let nested = #"{"data": {"items": [{"n": 2}, {"n": 3}]}}"#
        XCTAssertEqual(extract(nested, query("data.items[+].n", operation: .sum)).display, "5")
        XCTAssertEqual(extract(nested, query("data.items[1].n")).display, "3")
    }
}

final class TopLevelAndScalarArrayTests: XCTestCase {

    func testATopLevelListOfObjects() {
        XCTAssertEqual(extract(#"[{"a": 1}, {"a": 2}]"#, query("[#]", operation: .count)).display, "2")
        XCTAssertEqual(extract(#"[{"a": 1}, {"a": 2}]"#, query("[+].a", operation: .sum)).display, "3")
        XCTAssertEqual(extract(#"[{"a": 1}, {"a": 2}]"#, query("[1].a")).display, "2")
        XCTAssertNil(extract(#"[{"a": 1}, {"a": 2}]"#, query("a")).rawValue, "a bare key on a list addresses nothing")
        XCTAssertNil(extract(#"[{"a": 1}, {"a": 2}]"#, query("[5].a")).rawValue)
    }

    func testAnIndexIsTheRealPosition() {
        // The second element has no `a`; [1].a must not become "the second one that does".
        XCTAssertNil(extract(#"[{"a": 1}, {"b": 2}, {"a": 3}]"#, query("[1].a")).rawValue)
        XCTAssertEqual(extract(#"[{"a": 1}, {"b": 2}, {"a": 3}]"#, query("[2].a")).display, "3")
    }

    func testAListOfScalars() {
        XCTAssertEqual(extract("[1.5, 2.5]", query("[+]", operation: .sum)).display, "4")
        XCTAssertEqual(extract("[1.5, 2.5]", query("[1]", format: .number(decimals: 1))).display, "2.5")
        XCTAssertEqual(extract("[1.5, 2.5]", query("[#]", operation: .count)).display, "2")
        XCTAssertEqual(extract("[3, 1, 2]", query("[^]", operation: .max)).display, "3")
        XCTAssertEqual(extract(#"["a", "b"]"#, query("[0]")).display, "a")
        XCTAssertNil(extract("[1.5, 2.5]", query("[2]")).rawValue)
    }

    func testAScalarListInsideAnObject() {
        let body = #"{"prices": [1, 2, 3]}"#
        XCTAssertEqual(extract(body, query("prices[+]", operation: .sum)).display, "6")
        XCTAssertEqual(extract(body, query("prices[2]")).display, "3")
        XCTAssertEqual(extract(body, query("prices[#]", operation: .count)).display, "3")
    }

    func testAStringThatIsJSONIsWalkedInto() {
        let body = #"{"outcomePrices": "[\"0.31\", \"0.69\"]", "meta": "{\"nested\": {\"n\": 7}}", "plain": "[not json"}"#
        XCTAssertEqual(extract(body, query("outcomePrices[0]", format: .number(decimals: 2))).display, "0.31")
        XCTAssertEqual(extract(body, query("meta.nested.n")).display, "7")
        XCTAssertEqual(extract(body, query("plain")).display, "[not json", "a string that only looks like it starts JSON stays a string")
    }
}

final class MissAndPlainTextTests: XCTestCase {

    func testAMissedPathExtractsNothingRatherThanTheBody() {
        let result = extract(#"{"data": {"total": 42}}"#, query("data.missing", prefix: "$", suffix: " total"))
        XCTAssertNil(result.rawValue, "nothing extracted — the caller keeps its prior reading")
        XCTAssertEqual(result.display, "$ total")
    }

    func testPlainTextIsTheValue() {
        let result = extract("  42 rpm\n", query("anything"))
        XCTAssertEqual(result.display, "42 rpm")
        XCTAssertEqual(result.rawValue, "42 rpm")
    }

    func testABareNumberGetsItsDecimals() {
        let result = extract("3.14159", query("", format: .number(decimals: 2)))
        XCTAssertEqual(result.display, "3.14")
        XCTAssertEqual(result.rawValue, "3.14159")
    }

    func testAnEmptyBodyIsNothing() {
        let result = extract("   \n", query("x", prefix: "[", suffix: "]"))
        XCTAssertNil(result.rawValue)
        XCTAssertEqual(result.display, "[]")
    }

    func testAHeadProbeStatusCodeIsStatusMapped() {
        let rules = StatusRule.parse("200:Up, 204:Up, 301:Up, 302:Up, 304:Up")
        XCTAssertEqual(extract("200", query("", format: .status(rules: rules))).display, "Up")
        XCTAssertEqual(extract("503", query("", format: .status(rules: rules))).display, "503", "an unmapped code shows as itself")
    }

    func testPlainTextThroughMath() {
        XCTAssertEqual(extract("250", query("", format: .number(decimals: 1), math: .divide, mathValue: "100")).display, "2.5")
    }

    func testAJSONScalarBodyIsPlainText() {
        // `"live"` is valid JSON, but it is not an object or a list; the trimmed body is the value.
        XCTAssertEqual(extract("\"live\"", query("x")).display, "\"live\"")
    }
}

final class FormatTests: XCTestCase {

    func testEveryNumberFormat() {
        XCTAssertEqual(extract(#"{"n": 1500}"#, query("n", format: .compact)).display, "1.5k")
        XCTAssertEqual(extract(#"{"n": 2000000}"#, query("n", format: .compact)).display, "2m")
        XCTAssertEqual(extract(#"{"n": 3500000000}"#, query("n", format: .compact)).display, "3.5b")
        XCTAssertEqual(extract(#"{"n": 999}"#, query("n", format: .compact)).display, "999")
        XCTAssertEqual(extract(#"{"n": 0.1}"#, query("n", format: .percentage)).display, "10%")
        XCTAssertEqual(extract(#"{"n": 0.999}"#, query("n", format: .percentage)).display, "99%", "truncated, not rounded")
        XCTAssertEqual(extract(#"{"n": 1048576}"#, query("n", format: .bytes)).display, "1 MB")
        XCTAssertEqual(extract(#"{"n": 3661}"#, query("n", format: .duration)).display, "1h 1m")
        XCTAssertEqual(extract(#"{"n": 1234567}"#, query("n", format: .delimited)).display.filter(\.isNumber), "1234567")
        XCTAssertTrue(extract(#"{"n": 1234567}"#, query("n", format: .delimited)).display.count > 7, "grouping separators are inserted")
        XCTAssertEqual(extract(#"{"n": 1234.5}"#, query("n", format: .raw)).display, "1234.5")
        XCTAssertEqual(extract(#"{"n": 1234.567}"#, query("n", format: .number(decimals: 2))).display.filter { $0.isNumber || $0 == "." }, "1234.57")
    }

    func testCurrencyCarriesTheSymbolAndTwoPlacesOnlyWhenNeeded() {
        let fractional = extract(#"{"n": 1234.5}"#, query("n", format: .currency(code: "USD"))).display
        XCTAssertEqual(fractional.filter(\.isNumber), "123450")
        XCTAssertNotEqual(fractional, "1234.5", "a currency has a symbol")
        let whole = extract(#"{"n": 1200}"#, query("n", format: .currency(code: "USD"))).display
        XCTAssertEqual(whole.filter(\.isNumber), "1200", "a whole amount has no pence")
    }

    func testStatusLabels() {
        XCTAssertEqual(extract(#"{"ok": true}"#, query("ok", format: .status(rules: StatusRule.parse("true:Up, false:Down")))).display, "Up")
        XCTAssertEqual(extract(#"{"ok": false}"#, query("ok", format: .status(rules: StatusRule.parse("true:Up, false:Down")))).display, "Down")
        XCTAssertEqual(extract(#"{"code": 200}"#, query("code", format: .status(rules: StatusRule.parse("200:OK, 500:Down")))).display, "OK")
        XCTAssertEqual(extract(#"{"state": "live"}"#, query("state", format: .status(rules: StatusRule.parse("live:On Air")))).display, "On Air")
        XCTAssertEqual(extract(#"{"state": "LIVE"}"#, query("state", format: .status(rules: StatusRule.parse("live:On Air")))).display, "On Air", "a bare match ignores case")
        XCTAssertEqual(extract(#"{"state": "degraded_performance"}"#, query("state", format: .status(rules: StatusRule.parse("~degraded:Issues, *:Unknown")))).display, "Issues")
        XCTAssertEqual(extract(#"{"state": "weird"}"#, query("state", format: .status(rules: StatusRule.parse("ok:Fine, *:Unknown")))).display, "Unknown")
        XCTAssertEqual(extract(#"{"state": "weird"}"#, query("state", format: .status(rules: StatusRule.parse("ok:Fine")))).display, "weird", "no fallback: the value itself")
        XCTAssertEqual(extract(#"{"state": "Live"}"#, query("state", format: .status(rules: StatusRule.parse("=live:On Air")))).display, "Live", "= is case-sensitive")
    }

    func testDates() {
        XCTAssertEqual(extract(#"{"at": 1788915600}"#, query("at", format: .date(pattern: "yyyy"))).display, "2026")
        XCTAssertEqual(extract(#"{"at": 1788915600000}"#, query("at", format: .date(pattern: "yyyy"))).display, "2026", "thirteen digits is milliseconds")
        XCTAssertEqual(extract(#"{"at": "2026-09-09T12:00:00Z"}"#, query("at", format: .date(pattern: "yyyy-MM-dd"))).display, "2026-09-09")
        XCTAssertEqual(extract(#"{"at": "20260908131848"}"#, query("at", format: .date(pattern: "yyyy"))).display, "2026", "digits that are a date are read as one before the epoch lookup")
        XCTAssertEqual(extract(#"{"at": "20260908131848"}"#, query("at", format: .date(pattern: "yyyy"))).rawValue, "20260908131848")
        XCTAssertEqual(extract(#"{"at": "not a date"}"#, query("at", format: .date(pattern: "yyyy"))).display, "not a date", "text that is not a date shows as itself")
    }

    func testAStringHasNoPercentageFormAndShowsAsItself() {
        XCTAssertEqual(extract(#"{"name": "Arsenal"}"#, query("name", format: .percentage)).display, "Arsenal")
        XCTAssertEqual(extract(#"{"name": "Arsenal"}"#, query("name", format: .bytes)).display, "Arsenal")
        XCTAssertEqual(extract(#"{"name": "Arsenal"}"#, query("name", format: .compact)).display, "Arsenal")
        XCTAssertEqual(extract(#"{"name": "Arsenal"}"#, query("name", format: .currency(code: "GBP"))).display, "Arsenal")
    }

    func testUnicodeSurvives() {
        XCTAssertEqual(extract(#"{"name": "São Paulo ✓ 東京"}"#, query("name", prefix: "→ ")).display, "→ São Paulo ✓ 東京")
    }

    func testAHugeNumber() {
        XCTAssertEqual(extract(#"{"n": 1e21}"#, query("n", format: .percentage)).display.hasSuffix("%"), true)
        XCTAssertEqual(extract(#"{"n": 1e21}"#, query("n", format: .compact)).display.hasSuffix("b"), true)
    }
}

final class TwoValueTests: XCTestCase {

    func testPrefixSuffixAndASecondValue() {
        let score = extract(#"{"home": 2, "away": 1}"#, query("home", prefix: "Arsenal ", suffix: " FT", secondary: "away", separator: " – "))
        XCTAssertEqual(score.display, "Arsenal 2 – 1 FT")
        XCTAssertEqual(score.rawValue, "2.0", "trend and history follow the first value")
    }

    func testAMissingSecondValueLeavesNoSeparator() {
        let result = extract(#"{"home": 2}"#, query("home", suffix: " FT", secondary: "away", separator: " – "))
        XCTAssertEqual(result.display, "2 FT")
        XCTAssertEqual(result.rawValue, "2.0")
    }

    func testTheSecondValueTakesNoMath() {
        let result = extract(#"{"used": 1200, "total": 5000}"#, query("used", math: .divide, mathValue: "100", secondary: "total", separator: " / "))
        XCTAssertEqual(result.display, "12 / 5,000")
        XCTAssertEqual(result.rawValue, "12.0")
    }

    func testTheSecondValueOnAListBody() {
        XCTAssertEqual(extract(#"[{"h": 3, "a": 1}]"#, query("[0].h", secondary: "[0].a", separator: "-")).display, "3-1")
    }

    func testAWhitespaceOnlySecondPathIsNoSecondValue() {
        XCTAssertEqual(extract(#"{"home": 2, "away": 1}"#, query("home", secondary: "  ", separator: " – ")).display, "2")
    }

    func testTheSecondValueIsFormattedTheSameWay() {
        let result = extract(#"{"a": 0.5, "b": 0.25}"#, query("a", format: .percentage, secondary: "b", separator: " vs "))
        XCTAssertEqual(result.display, "50% vs 25%")
    }
}

final class RecordedResponseTests: XCTestCase {

    private func status(_ rules: String) -> Format {
        .status(rules: StatusRule.parse(rules))
    }

    func testTheReadingsMetricBarPins() throws {
        XCTAssertEqual(extract(try fixture("f1_drivers"), query("MRData.StandingsTable.StandingsLists[0].DriverStandings[0].Driver.familyName", suffix: " pts", secondary: "MRData.StandingsTable.StandingsLists[0].DriverStandings[0].points", separator: " · ")).display, "Antonelli · 267 pts")
        XCTAssertEqual(extract(try fixture("f1_next"), query("MRData.RaceTable.Races[0].raceName", format: .date(pattern: "EEE d MMM"), secondary: "MRData.RaceTable.Races[0].date", separator: " · ")).display, "Spanish Grand Prix · Sun 13 Sep")
        XCTAssertEqual(extract(try fixture("mlb_schedule"), query("totalGames", suffix: " live", secondary: "totalGamesInProgress", separator: " games · ")).display, "15 games · 0 live")
        XCTAssertEqual(extract(try fixture("meteo"), query("daily.sunrise[0]", format: .date(pattern: "HH:mm"))).display, "06:24")
        XCTAssertEqual(extract(try fixture("meteo"), query("daily.precipitation_probability_max[0]", suffix: "%")).display, "100%")
        XCTAssertEqual(extract(try fixture("wayback"), query("archived_snapshots.closest.timestamp", format: .date(pattern: "d MMM yyyy"))).display, "8 Sep 2026")
        XCTAssertEqual(extract(try fixture("steam_players"), query("response.player_count", format: .delimited)).display.filter(\.isNumber), "625434")
        XCTAssertEqual(extract(try fixture("itunes"), query("results[0].averageUserRating", format: .number(decimals: 2), suffix: " ★")).display, "4.53 ★")
        XCTAssertEqual(extract(try fixture("cg_global"), query("data.market_cap_percentage.btc", format: .number(decimals: 1), suffix: "%")).display, "58.4%")
        XCTAssertEqual(extract(try fixture("pm_market"), query("[0].outcomePrices[0]", format: .number(decimals: 1), math: .multiply, mathValue: "100", suffix: "%")).display, "30.5%",
                       "the Yes price lives inside a JSON string — decoded and walked")
        XCTAssertEqual(extract(try fixture("pm_event"), query("[0].markets[0].lastTradePrice", format: .percentage, secondary: "[0].markets[0].groupItemTitle", separator: " · ")).display, "35% · BV Borussia 09 Dortmund")
        let page = "none:Operational, minor:Minor Outage, major:Major Outage, critical:Major Outage, maintenance:Maintenance, *:Issues"
        XCTAssertEqual(extract(try fixture("st_anthropic"), query("status.indicator", format: status(page))).display, "Operational")
        XCTAssertEqual(extract(try fixture("st_cloudflare"), query("status.indicator", format: status(page))).display, "Minor Outage")
        XCTAssertEqual(extract(try fixture("st_slack"), query("status", format: status("ok:Operational, active:Incident, *:Issues"))).display, "Incident")
        XCTAssertEqual(extract(try fixture("head_200"), query("", format: status("200:Up, 204:Up, 301:Up, 302:Up, 304:Up"))).display, "Up", "a HEAD's bare status code is status-mapped")
        XCTAssertEqual(extract(try fixture("fx"), query("rates.EUR", format: .number(decimals: 4))).display, "0.8610")
        XCTAssertEqual(extract(try fixture("fng"), query("data[0].value", secondary: "data[0].value_classification", separator: " · ")).display, "69 · Greed")
        XCTAssertEqual(extract(try fixture("quakes"), query("metadata.count")).display, "14")
        XCTAssertEqual(extract(try fixture("astros"), query("number")).display, "12")
        XCTAssertEqual(extract(try fixture("nba_scoreboard"), query("scoreboard.games[#].gameId", operation: .count, suffix: " games")).display, "2 games")
    }

    func testEveryRecordingExtractsARawValue() throws {
        let readings: [(String, Extraction)] = [
            ("astros", query("number")), ("cg_global", query("data.market_cap_percentage.btc")),
            ("f1_drivers", query("MRData.StandingsTable.StandingsLists[0].DriverStandings[0].points")),
            ("fng", query("data[0].value")), ("fx", query("rates.EUR")), ("head_200", query("")),
            ("itunes", query("results[0].averageUserRating")), ("meteo", query("daily.sunrise[0]", format: .date(pattern: "HH:mm"))),
            ("mlb_schedule", query("totalGames")), ("nba_scoreboard", query("scoreboard.games[#].gameId", operation: .count)),
            ("pm_event", query("[0].markets[0].lastTradePrice")), ("pm_market", query("[0].outcomePrices[0]")),
            ("quakes", query("metadata.count")), ("st_anthropic", query("status.indicator")),
            ("steam_players", query("response.player_count")), ("wayback", query("archived_snapshots.closest.timestamp")),
        ]
        for (name, extraction) in readings {
            XCTAssertNotNil(extract(try fixture(name), extraction).rawValue, "\(name): nothing at \(extraction.path)")
        }
    }
}

final class TypedValueTests: XCTestCase {

    func testParseGivesTypedValues() throws {
        let value = try JSONPath.parse(#"{"a": 1, "b": "x", "c": true, "d": null, "e": [1, 2.5], "f": {"g": false}}"#)
        XCTAssertEqual(value.object?["a"], .number(1))
        XCTAssertEqual(value.object?["b"], .string("x"))
        XCTAssertEqual(value.object?["c"], .bool(true))
        XCTAssertEqual(value.object?["d"], .null)
        XCTAssertEqual(value.object?["e"], .array([.number(1), .number(2.5)]))
        XCTAssertEqual(value.object?["f"]?.object?["g"], .bool(false))
        XCTAssertEqual(try JSONPath.parse("42"), .number(42), "a bare scalar is JSON")
        XCTAssertEqual(try JSONPath.parse("\"x\""), .string("x"))
    }

    func testParseRefusesWhatIsNotJSON() {
        XCTAssertThrowsError(try JSONPath.parse("42 rpm")) { error in
            guard case .invalidJSON(let reason)? = error as? JSONPathError else { return XCTFail("\(error)") }
            XCTAssertFalse(reason.isEmpty)
            XCTAssertTrue(error.localizedDescription.hasPrefix("not JSON: "))
        }
        XCTAssertThrowsError(try JSONPath.parse(""))
        XCTAssertThrowsError(try JSONPath.parse("{\"a\": }"))
        // Foundation forgives a trailing comma, so `{"a": 1,}` is NOT refused here; that is the parser's rule, not ours.
        XCTAssertNoThrow(try JSONPath.parse("{\"a\": 1,}"))
    }

    func testAccessors() {
        XCTAssertEqual(JSONValue.number(42).text, "42")
        XCTAssertEqual(JSONValue.number(2.5).text, "2.5")
        XCTAssertEqual(JSONValue.string("42").number, nil, "a string is not converted")
        XCTAssertEqual(JSONValue.bool(true).text, "true")
        XCTAssertNil(JSONValue.null.text)
        XCTAssertTrue(JSONValue.null.isNull)
        XCTAssertNil(JSONValue.array([]).text)
        XCTAssertEqual(JSONValue.array([.number(1)]).array?.count, 1)
        XCTAssertEqual(JSONValue.object(["a": .null]).object?.count, 1)
        XCTAssertEqual(JSONValue.bool(false).bool, false)
    }

    func testDescriptionIsCompactJSONWithSortedKeys() {
        let value = JSONValue.object(["b": .array([.number(1), .string("x\"y"), .null]), "a": .bool(true)])
        XCTAssertEqual(value.description, #"{"a":true,"b":[1,"x\"y",null]}"#)
        XCTAssertEqual(JSONValue.number(1e16).description, "1e+16")
    }

    func testValuesRoundTripThroughCodable() throws {
        let value = try JSONPath.parse(#"{"a": [1, "two", true, null, {"b": 2.5}]}"#)
        let data = try JSONEncoder().encode(value)
        XCTAssertEqual(try JSONDecoder().decode(JSONValue.self, from: data), value)
    }

    func testValueAtAPath() {
        let body = #"{"data": {"total": 42, "name": "x", "ok": true, "list": [1, 2, 3], "items": [{"n": 2}, {"n": 5}]}}"#
        XCTAssertEqual(JSONPath.value(at: "data.total", in: body), .number(42))
        XCTAssertEqual(JSONPath.value(at: "data.name", in: body), .string("x"))
        XCTAssertEqual(JSONPath.value(at: "data.ok", in: body), .bool(true))
        XCTAssertEqual(JSONPath.value(at: "data.list", in: body), .array([.number(1), .number(2), .number(3)]))
        XCTAssertEqual(JSONPath.value(at: "data.list[1]", in: body), .number(2))
        XCTAssertEqual(JSONPath.value(at: "data.list[+]", in: body), .number(6))
        XCTAssertEqual(JSONPath.value(at: "data.list[#]", in: body), .number(3))
        XCTAssertEqual(JSONPath.value(at: "data.items[1].n", in: body), .number(5))
        XCTAssertEqual(JSONPath.value(at: "data.items[^].n", in: body), .number(5))
        XCTAssertEqual(JSONPath.value(at: "data.items[~].n", in: body), .number(3.5))
        XCTAssertEqual(JSONPath.value(at: "data", in: body)?.object?.count, 5)
        XCTAssertNil(JSONPath.value(at: "data.missing", in: body), "a miss is nil, never the body")
        XCTAssertNil(JSONPath.value(at: "data.list[9]", in: body))
    }

    func testValueAtAPathOnListsAndText() {
        XCTAssertEqual(JSONPath.value(at: "[#]", in: #"[{"a": 1}, {"a": 2}]"#), .number(2))
        XCTAssertEqual(JSONPath.value(at: "[+].a", in: #"[{"a": 1}, {"a": 2}]"#), .number(3))
        XCTAssertEqual(JSONPath.value(at: "[1].a", in: #"[{"a": 1}, {"a": 2}]"#), .number(2))
        XCTAssertEqual(JSONPath.value(at: "[1]", in: "[1.5, 2.5]"), .number(2.5))
        XCTAssertEqual(JSONPath.value(at: "[+]", in: "[1.5, 2.5]"), .number(4))
        XCTAssertEqual(JSONPath.value(at: "anything", in: "  42 rpm\n"), .string("42 rpm"))
        XCTAssertNil(JSONPath.value(at: "anything", in: "   "))
        XCTAssertEqual(JSONPath.value(at: "outcomePrices[0]", in: #"{"outcomePrices": "[\"0.31\", \"0.69\"]"}"#), .string("0.31"), "embedded JSON is walked, and the element is what it was")
    }
}

final class ModelTests: XCTestCase {

    func testAnExtractionRoundTripsThroughCodable() throws {
        let extraction = query("a[+].b", operation: .sum, format: .status(rules: [StatusRule(mode: .contains, match: "x", label: "X")]),
                               math: .divide, mathValue: "100", prefix: "<", suffix: ">", secondary: "c", separator: " · ")
        let data = try JSONEncoder().encode(extraction)
        XCTAssertEqual(try JSONDecoder().decode(Extraction.self, from: data), extraction)
        for format: Format in [.raw, .number(decimals: 2), .number(decimals: nil), .date(pattern: "yyyy"), .compact, .delimited, .percentage, .currency(code: "GBP"), .bytes, .duration, .status(rules: [])] {
            XCTAssertEqual(try JSONDecoder().decode(Format.self, from: JSONEncoder().encode(format)), format)
        }
        let result = Extraction.Result(display: "x", rawValue: nil)
        XCTAssertEqual(try JSONDecoder().decode(Extraction.Result.self, from: JSONEncoder().encode(result)), result)
    }

    func testTheDefaultsAreADoNothingQuery() {
        let extraction = Extraction(path: "n")
        XCTAssertEqual(extraction.arrayOperation, .none)
        XCTAssertEqual(extraction.mathOperation, .none)
        XCTAssertEqual(extraction.format, .number(decimals: nil))
        XCTAssertEqual(extraction.prefix + extraction.suffix + extraction.secondaryPath + extraction.separator + extraction.mathValue, "")
        XCTAssertEqual(extract(#"{"n": 7.9}"#, extraction).display, "8")
    }

    func testOperationSymbolsRoundTrip() {
        XCTAssertEqual(ArrayOperation.allCases.map(\.symbol), ["", "+", "#", "~", "^", "v", "<", ">", "=", "-"])
        for operation in ArrayOperation.allCases where operation != .none {
            XCTAssertEqual(ArrayOperation(symbol: operation.symbol), operation)
        }
        XCTAssertNil(ArrayOperation(symbol: "?"))
        XCTAssertEqual(MathOperation.allCases.map(\.symbol), ["", "+", "-", "*", "/"])
        for operation in ArrayOperation.allCases {
            XCTAssertEqual(try JSONDecoder().decode(ArrayOperation.self, from: JSONEncoder().encode(operation)), operation)
        }
        for operation in MathOperation.allCases {
            XCTAssertEqual(try JSONDecoder().decode(MathOperation.self, from: JSONEncoder().encode(operation)), operation)
        }
    }
}
