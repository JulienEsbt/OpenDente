import Foundation

private struct InjectedFailure: LocalizedError {
    let errorDescription: String? = "injected failure"
}

private final class Fixture {
    var keys: [String: [UInt8]]
    var recoveryMarker = false
    var writes: [String] = []
    var events: [String] = []
    var failedWrites = Set<String>()
    var failWriteNumber: Int?
    var failMark = false
    var failClear = false
    var ignoredWrites = Set<String>()
    let api: SMCChargingAPI

    init(_ api: SMCChargingAPI) {
        self.api = api
        keys = ["CHIE": [0], "CHTE": [0, 0, 0, 0], "CH0I": [0],
                "CH0B": [0], "CH0C": [0], "ACLC": [0]]
    }

    func controller() -> ChargingHardwareController {
        ChargingHardwareController(api: api, hasLED: true, write: { key, value in
            self.writes.append(key)
            self.events.append("write:\(key)")
            if self.failedWrites.contains(key) || self.failWriteNumber == self.writes.count {
                throw InjectedFailure()
            }
            if !self.ignoredWrites.contains(key) { self.keys[key] = value }
        }, read: { key in self.keys[key]! }, persistRecovery: { needed in
            self.events.append(needed ? "mark" : "clear")
            if (needed && self.failMark) || (!needed && self.failClear) { throw InjectedFailure() }
            self.recoveryMarker = needed
        })
    }

    var restored: Bool {
        keys.values.allSatisfy { $0.allSatisfy { $0 == 0 } }
    }
}

private func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw ChargingHardwareController.Failure(message: message) }
}

private func mustFail(_ operation: () throws -> Void) throws {
    var failed = false
    do { try operation() } catch { failed = true }
    try require(failed, "operation incorrectly reported success")
}

@main
struct HardwareRecoveryTests {
    static func main() throws {
        var count = 0
        func test(_ name: String, _ body: () throws -> Void) throws {
            try body()
            count += 1
            print("PASS \(name)")
        }
        for (api, name) in [(SMCChargingAPI.legacy, "legacy"), (.tahoe, "tahoe")] {
            try test("\(name): marker failure prevents all restrictive hardware writes") {
                let f = Fixture(api)
                f.failMark = true
                let c = f.controller()
                try mustFail { try c.forceDischarge(enable: true) }
                try require(f.writes.isEmpty, "hardware changed without durable recovery intent")
            }
            try test("\(name): partial forced discharge rolls back adapter and charge") {
                let f = Fixture(api)
                f.failWriteNumber = 2
                let c = f.controller()
                try mustFail { try c.forceDischarge(enable: true) }
                try require(f.events.first == "mark", "marker was not written first")
                try require(f.restored, "partial discharge left hardware restricted")
                try require(!f.recoveryMarker && !c.recoveryRequired, "successful rollback stayed pending")
            }
            try test("\(name): reset attempts later keys after adapter failure and remains pending") {
                let f = Fixture(api)
                let c = f.controller()
                try c.forceDischarge(enable: true)
                let adapter = api == .legacy ? "CH0I" : "CHIE"
                f.failedWrites.insert(adapter)
                f.writes = []
                try mustFail { try c.restoreDefaults() }
                let expected = api == .legacy ? ["CH0I", "CH0B", "CH0C", "ACLC"] : ["CHIE", "CHTE", "ACLC"]
                try require(f.writes == expected, "reset abandoned remaining safe-default writes")
                try require(f.recoveryMarker && c.recoveryRequired && c.restorationPending, "failed recovery was forgotten")
                f.failedWrites = []
                try c.restoreDefaults()
                try require(f.restored && !f.recoveryMarker && !c.recoveryRequired && !c.restorationPending, "retry did not recover")
            }
            try test("\(name): accepted but ignored inhibit write is failure") {
                let f = Fixture(api)
                f.ignoredWrites.insert(api == .legacy ? "CH0B" : "CHTE")
                let c = f.controller()
                try mustFail { try c.inhibitCharging() }
                try require(f.restored, "readback mismatch did not restore defaults")
            }
            try test("\(name): clear-marker failure stays pending after hardware recovery") {
                let f = Fixture(api)
                let c = f.controller()
                try c.forceDischarge(enable: true)
                f.failClear = true
                try mustFail { try c.restoreDefaults() }
                try require(f.restored, "hardware defaults were not attempted")
                try require(f.recoveryMarker && c.recoveryRequired, "failed marker clear reported full success")
            }
            try test("\(name): stopping forced discharge retains charge recovery intent") {
                let f = Fixture(api)
                let c = f.controller()
                try c.forceDischarge(enable: true)
                try c.forceDischarge(enable: false)
                try require(f.keys[api == .legacy ? "CH0I" : "CHIE"] == [0], "adapter remained disconnected")
                try require(f.recoveryMarker && c.recoveryRequired, "charge inhibition lost recovery intent")
                try c.restoreDefaults(resetLED: false)
                try require(f.restored && !f.recoveryMarker, "enabling did not recover")
            }
            try test("\(name): LED reset error does not suppress charge restore") {
                let f = Fixture(api)
                let c = f.controller()
                try c.forceDischarge(enable: true)
                f.failedWrites = ["ACLC"]
                try mustFail { try c.restoreDefaults() }
                try require(f.keys[api == .legacy ? "CH0I" : "CHIE"] == [0], "LED failure blocked adapter")
                try require(f.keys[api == .legacy ? "CH0B" : "CHTE"]?.first == 0, "LED failure blocked charging")
                try require(f.recoveryMarker && c.recoveryRequired, "LED failure falsely reported complete restore")
            }
        }
        try test("legacy: second inhibit-key failure rolls back first key") {
            let f = Fixture(.legacy)
            f.failWriteNumber = 2
            let c = f.controller()
            try mustFail { try c.inhibitCharging() }
            try require(f.restored && !f.recoveryMarker, "legacy partial inhibition not recovered")
        }
        try test("unknown API refuses changes") {
            let f = Fixture(.unknown)
            let c = f.controller()
            try mustFail { try c.inhibitCharging() }
            try mustFail { try c.forceDischarge(enable: true) }
            try mustFail { try c.restoreDefaults() }
            try require(f.writes.isEmpty && f.events.isEmpty, "unknown API wrote state or hardware")
        }
        try test("normal inhibition is distinguished from a failed restore") {
            let f = Fixture(.tahoe)
            let c = f.controller()
            try c.inhibitCharging()
            try require(c.recoveryRequired && !c.restorationPending, "normal policy would be reset by watchdog")
            f.failedWrites = ["CHIE"]
            try mustFail { try c.restoreDefaults() }
            try require(c.restorationPending, "failed restore would wait for a heartbeat timeout")
        }
        print("\(count) hardware recovery tests passed; no hardware accessed.")
    }
}
