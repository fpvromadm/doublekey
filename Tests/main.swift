// Plain assertions, no XCTest needed. Run with ./build.sh test
import Darwin
let ms: UInt64 = 1_000_000
var failures = 0

func check(_ ok: Bool, _ what: String, line: Int = #line) {
    if !ok { failures += 1; print("FAIL line \(line): \(what)") }
}

// Chatter right after release is dropped, together with its keyUp.
do {
    var d = Debouncer(thresholdMs: 40)
    check(d.keyDown(14, at: 0), "first press passes")
    check(d.keyUp(14, at: 90 * ms), "first release passes")
    check(!d.keyDown(14, at: 100 * ms), "bounce 10 ms after release is dropped")
    check(!d.keyUp(14, at: 105 * ms), "bounce release is dropped")
    check(d.blocked == 1, "blocked counter")
}

// A burst of several bounces is fully swallowed.
do {
    var d = Debouncer(thresholdMs: 40)
    _ = d.keyDown(14, at: 0)
    _ = d.keyUp(14, at: 80 * ms)
    check(!d.keyDown(14, at: 85 * ms), "bounce 1")
    check(!d.keyUp(14, at: 90 * ms), "bounce 1 up")
    check(!d.keyDown(14, at: 110 * ms), "bounce 2, 20 ms after bounce 1 up")
    check(!d.keyUp(14, at: 112 * ms), "bounce 2 up")
    check(d.keyDown(14, at: 300 * ms), "real press later passes")
}

// Deliberate double tap of the same key passes.
do {
    var d = Debouncer(thresholdMs: 40)
    _ = d.keyDown(14, at: 0)
    _ = d.keyUp(14, at: 80 * ms)
    check(d.keyDown(14, at: 150 * ms), "second tap 70 ms after release passes")
    check(d.keyUp(14, at: 230 * ms), "its release passes")
}

// Another key in between means it is real typing, not chatter.
do {
    var d = Debouncer(thresholdMs: 40)
    _ = d.keyDown(14, at: 0)
    _ = d.keyDown(15, at: 50 * ms)
    _ = d.keyUp(14, at: 60 * ms)
    _ = d.keyUp(15, at: 70 * ms)
    check(d.keyDown(14, at: 80 * ms), "e r e rollover passes")
}

// Different keys never affect each other.
do {
    var d = Debouncer(thresholdMs: 40)
    _ = d.keyDown(0, at: 0)
    _ = d.keyUp(0, at: 50 * ms)
    check(d.keyDown(1, at: 55 * ms), "other key right after passes")
}

// Threshold can change at runtime.
do {
    var d = Debouncer(thresholdMs: 40)
    d.thresholdNs = 80 * ms
    _ = d.keyDown(14, at: 0)
    _ = d.keyUp(14, at: 50 * ms)
    check(!d.keyDown(14, at: 110 * ms), "60 ms gap dropped with 80 ms threshold")
}

print(failures == 0 ? "All tests passed" : "\(failures) failure(s)")
if failures > 0 { exit(1) }
