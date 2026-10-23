// Decides which key events are switch chatter and should be dropped.
//
// A keyDown is chatter when the same key was released less than `threshold`
// ago and no other key was pressed in between. The keyUp that belongs to a
// dropped keyDown is dropped as well, so apps never see half a keystroke.
struct Debouncer {
    var thresholdNs: UInt64
    private(set) var blocked = 0

    private var lastUp = [UInt64](repeating: 0, count: 256)
    private var swallowUp = [Bool](repeating: false, count: 256)
    private var lastDown = -1

    init(thresholdMs: Int) {
        thresholdNs = UInt64(thresholdMs) * 1_000_000
    }

    /// Returns true if the event should reach the system.
    mutating func keyDown(_ code: Int, at t: UInt64) -> Bool {
        let k = code & 0xFF
        if k == lastDown, lastUp[k] != 0, t >= lastUp[k], t - lastUp[k] < thresholdNs {
            swallowUp[k] = true
            blocked += 1
            return false
        }
        lastDown = k
        return true
    }

    /// Returns true if the event should reach the system.
    mutating func keyUp(_ code: Int, at t: UInt64) -> Bool {
        let k = code & 0xFF
        // Track the swallowed release too, so a burst of several bounces is caught.
        lastUp[k] = t
        if swallowUp[k] {
            swallowUp[k] = false
            return false
        }
        return true
    }
}
