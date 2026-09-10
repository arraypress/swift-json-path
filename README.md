# Swift JSON Path

One value out of a JSON response, by path — summed, averaged or counted across a list, put through math, and shown as a number, a currency, a date or a status label — as typed values, on any Apple platform.

```swift
import JSONPath

JSONPath.value(at: "data.total", in: body)              // .number(42)
JSONPath.value(at: "orders[+].price", in: body)         // .number(9) — the list, summed
JSONPath.value(at: "results[0].name", in: body)         // .string("Antonelli")

let cents = Extraction(path: "balance", mathOperation: .divide, mathValue: "100",
                       format: .currency(code: "USD"))
JSONPath.extract(cents, from: #"{"balance": 4250}"#)
// display "$42.50", rawValue "42.5" — dollars, which is what the alert should compare against

let status = Extraction(path: "status.indicator",
                        format: .status(rules: StatusRule.parse("none:Operational, ~outage:Outage, *:Issues")))
JSONPath.extract(status, from: statusPage).display     // "Operational"
```

## Why

This is the engine behind MetricBar's menu bar and Powercuts' "Get Value from URL" action, extracted so the two cannot drift. What it replaces is the way people read an API by hand, and where that goes wrong:

| Question | The wrong answer, and why it is tempting |
|---|---|
| The price in `data.items[0].price` | Get Dictionary Value, then Get Item from List, then Get Dictionary Value again. One path, one call. |
| The total of every order | A Repeat loop with a variable. `orders[+].price` sums; `[#]` counts, `[~]` averages, `[^]` and `[v]` take the largest and smallest. |
| A path that finds nothing | The whole body, shown as the value and recorded as history. Here it is nothing — a nil raw value — so the caller keeps its last good reading. |
| Cents into dollars | Dividing after formatting, or showing 4250. Math runs on the number, then the format, and the raw value is the post-math number the alerts compare against. |
| `0.1` as a percentage | `0.1%`. It is `10%`. |
| `true` as a status | The word "true" in a menu bar. A rule table maps it: `true:Up, false:Down`, and a status page's `minor` becomes `Minor Outage`. |

## Installation

```swift
.package(url: "https://github.com/arraypress/swift-json-path.git", from: "0.1.0")
```

Foundation only. No dependencies, every Apple platform, macOS 14+.

## The path

```swift
"total"                      // a key
"data.total"                 // a dotted key path
"results[0].price"           // an index into a list of objects
"prices[2]"                  // an index into a list of scalars
"orders[+].price"            // a marker: an operation over a list
"[#]"                        // a top-level list, counted
"[1].name"                   // a top-level list, indexed
"outcomePrices[0]"           // a string that is itself JSON is decoded and walked into
```

The grammar is decided by the first bracket and the first dot: `a.b[0].c` has the root `a.b`, walked as a key path, and the key `c`. Keys are matched as written — `@id` and `città` are keys, and a key that literally contains brackets is found before `[1]` is read as an index. A hop that lands on a string, a number or `null` finds nothing, rather than raising.

A body that is not JSON is the value itself, trimmed, through the same math and format — so a HEAD probe's bare `200` can be status-mapped to `Up`.

## Operations over a list

| Marker | Operation | |
|---|---|---|
| `[+]` | sum | `orders[+].price` |
| `[#]` | count | `orders[#]` — the list, no key needed |
| `[~]` | average | |
| `[^]` `[v]` | max, min | |
| `[<]` `[>]` | first, last | |
| `[=]` | median | the mean of the middle two when even |
| `[-]` | range | largest minus smallest |

The marker in the path and ``Extraction/arrayOperation`` must agree; a path that says sum with a query that says average extracts nothing rather than guessing. Items without the key are skipped for every operation but count, which counts the list. Math runs per item, before the aggregate.

## Math

`add`, `subtract`, `multiply`, `divide`, with the operand as text — `100` to turn cents into dollars. A missing operand adds nothing and leaves multiply and divide alone; a zero divisor leaves the value alone, because an infinity in the menu bar helps nobody. Numbers carried as strings (`"250"`) are numbers.

## Formats

| `Format` | `1234.5` becomes |
|---|---|
| `.raw` | `1234.5` |
| `.number(decimals: 2)` | `1,234.50` |
| `.compact` | `1.2k` (`2m`, `3.5b`) |
| `.delimited` | `1,235` |
| `.percentage` | `123450%` — a ratio: `0.1` is `10%`, truncated |
| `.currency(code: "USD")` | `$1,234.50`; a whole amount has no pence |
| `.bytes` | `1 KB` |
| `.duration` | `20m 34s` |
| `.date(pattern:)` | epoch seconds, or milliseconds when the number is too big to be seconds; a string is read as a date first — ISO 8601, then fifty API shapes |
| `.status(rules:)` | a label from the rule table |

Numbers, grouping and month names are written in the system locale, because this is display. Parsing never uses the locale, so `42.0` reads as forty-two on a comma-decimal machine.

A string has no percentage or byte form and shows as itself. That is how a name sits next to a number as the second value.

## Status rules

```swift
StatusRule.parse("none:Operational, minor:Minor Outage, ~outage:Outage, =OK:Fine, *:Issues")
```

Comma-separated `match:label`. A bare match is a case-insensitive equal; `=` is exact and case-sensitive; `~` matches anywhere; `*` alone is the fallback. The first matching rule wins, the fallback only when nothing else did, and a value no rule names shows as itself. A JSON boolean matches `true` and `false`; a number matches its own form, so `200:OK` works on a status code.

## Two values

```swift
Extraction(path: "home", suffix: " FT", secondaryPath: "away", separator: " – ")
// "2 – 1 FT", rawValue "2.0"
```

The second value takes the same format and no math, and the raw value stays the first value's, so trend arrows and history follow the score you asked about. A missing second value leaves no separator behind.

## Tested

118 tests: every behaviour MetricBar's suite pinned, on the same fixtures — nineteen recorded API responses from F1, MLB, Open-Meteo, Wayback, Steam, the App Store, CoinGecko, Polymarket and three status pages — plus every operation on lists of objects and of scalars, every format at zero, negative and huge, every status mode and its precedence, the second value's raw-value rule, embedded JSON, null, `@` keys, a ten-thousand-row list, and each Support function on its own.

## Licence

MIT.
