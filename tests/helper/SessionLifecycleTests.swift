import Foundation

// macOS boundaries only. The delegate/controller under test are the production
// source; signing implementation is omitted from this portable lifecycle probe.
protocol NSXPCListenerDelegate {}
protocol HelperProtocol {}
final class NSXPCListener {}
final class NSXPCInterface { init(with type: Any.Type) {} }
final class NSXPCConnection {
    nonisolated(unsafe) static var requestConnection: NSXPCConnection?
    static func current() -> NSXPCConnection? { requestConnection }
    var exportedInterface: NSXPCInterface?
    var exportedObject: AnyObject?
    var invalidationHandler: (() -> Void)?
    var interruptionHandler: (() -> Void)?
    var events: [String] = []
    func setCodeSigningRequirement(_ text: String) { events.append("requirement") }
    func resume() { events.append("resume") }
}
final class Watchdog {
    func receivedHeartbeat() {}
    func suspend() {}
    func resume() {}
}
enum HelperState {
    enum ChargingState { case normal, inhibited }
    nonisolated(unsafe) static var state: ChargingState = .normal
    static func write(_ state: ChargingState) throws { self.state = state }
    static func wasChargingInhibited() -> Bool { state == .inhibited }
    nonisolated(unsafe) static var ledOwned = false
    static func wasLEDOverridden() -> Bool { ledOwned }
    static func writeLEDRecovery(_ value: Bool) throws { ledOwned = value }
}
struct SMCValue { let bytes: [UInt8] }
final class NativeChargeLimit {
    static let isAvailable = false
    nonisolated(unsafe) static var restores = 0
    var needsRecovery = false
    var restorationPending = false
    func restore() throws { Self.restores += 1 }
    func setLimit(_ percent: Int) throws {}
    func prepareStorage() throws {}
}

final class SMCService {
    nonisolated(unsafe) static var shared = SMCService()
    var keys: [String: [UInt8]] = ["CHIE": [0], "CHTE": [0, 0, 0, 0], "ACLC": [0]]
    var writes: [String] = []
    var failAuto = false
    func open() throws {}
    func keyExists(_ key: String) -> Bool { keys[key] != nil }
    func keyInfo(_ key: String) -> (type: String, size: UInt32)? {
        keys[key].map { ("test", UInt32($0.count)) }
    }
    func readKeyOptional(_ key: String) -> SMCValue? { keys[key].map { SMCValue(bytes: $0) } }
    func readKey(_ key: String) throws -> SMCValue { SMCValue(bytes: keys[key]!) }
    func writeKey(_ key: String, bytes: [UInt8]) throws {
        writes.append(key)
        if failAuto && key == "ACLC" && bytes == [0] { throw ChargingHardwareController.Failure(message: "LED unavailable") }
        keys[key] = bytes
    }
}

private func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw ChargingHardwareController.Failure(message: message) }
}
private func withRequest(_ connection: NSXPCConnection, _ body: () -> Void) {
    NSXPCConnection.requestConnection = connection
    defer { NSXPCConnection.requestConnection = nil }
    body()
}
private func connected(_ helper: HelperDelegate) -> NSXPCConnection {
    let connection = NSXPCConnection()
    precondition(helper.listener(NSXPCListener(), shouldAcceptNewConnection: connection))
    return connection
}
private func activate(_ helper: HelperDelegate, _ connection: NSXPCConnection) {
    withRequest(connection) { helper.heartbeat { precondition($0) } }
}
private func setSleep(_ helper: HelperDelegate, _ connection: NSXPCConnection) {
    withRequest(connection) {
        helper.syncSleepSettings(stopChargingWhenSleeping: true, sleepLEDColor: 0x03) { precondition($0) }
    }
}

@main
struct SessionLifecycleTests {
    static func main() throws {
        var count = 0
        func test(_ name: String, nativeOnly: Bool = false, _ body: (HelperDelegate, SMCService) throws -> Void) throws {
            SMCService.shared = SMCService()
            HelperState.state = .normal
            HelperState.ledOwned = false
            NativeChargeLimit.restores = 0
            if nativeOnly { SMCService.shared.keys = ["ACLC": [0]] }
            let helper = HelperDelegate(watchdog: Watchdog())
            try body(helper, SMCService.shared)
            count += 1
            print("PASS \(name)")
        }
        try test("connection requirement is configured before resume") { helper, _ in
            let c = connected(helper)
            try require(c.events == ["requirement", "resume"], "unprotected resume order")
        }
        try test("connecting and invalidating without an authenticated request cannot change hardware") { helper, smc in
            let c = connected(helper)
            c.invalidationHandler?()
            helper.inhibitChargingOnSleep()
            try require(smc.writes.isEmpty, "unauthenticated lifecycle affected battery")
        }
        try test("unregistered request cannot invoke privileged methods") { helper, smc in
            var result = true
            withRequest(NSXPCConnection()) { helper.inhibitCharging { value, _ in result = value } }
            try require(!result && smc.writes.isEmpty, "unregistered caller changed battery")
        }
        try test("disconnect restores defaults and prevents later sleep inhibition") { helper, smc in
            let c = connected(helper)
            activate(helper, c)
            setSleep(helper, c)
            helper.inhibitChargingOnSleep()
            try require(smc.keys["CHTE"] == [1, 0, 0, 0], "positive control did not inhibit")
            c.invalidationHandler?()
            try require(smc.keys["CHTE"] == [0, 0, 0, 0], "disconnect did not recover")
            smc.writes = []
            helper.inhibitChargingOnSleep()
            try require(smc.writes.isEmpty, "departed app's sleep policy still executed")
        }
        try test("old invalidation cannot reset a newer client's hardware or sleep policy") { helper, smc in
            let old = connected(helper)
            activate(helper, old)
            let current = connected(helper)
            activate(helper, current)
            setSleep(helper, current)
            smc.writes = []
            old.invalidationHandler?()
            try require(smc.writes.isEmpty, "obsolete callback reset newer client")
            helper.inhibitChargingOnSleep()
            try require(smc.keys["CHTE"] == [1, 0, 0, 0], "obsolete callback cleared newer policy")
        }
        try test("old queued requests cannot retake ownership from newer client") { helper, smc in
            let old = connected(helper)
            activate(helper, old)
            let current = connected(helper)
            activate(helper, current)
            var accepted = true
            withRequest(old) { helper.inhibitCharging { value, _ in accepted = value } }
            try require(!accepted && smc.writes.isEmpty, "obsolete request retook ownership")
        }
        try test("explicit reset clears sleep inhibition until settings are synced again") { helper, smc in
            let c = connected(helper)
            activate(helper, c)
            setSleep(helper, c)
            withRequest(c) { helper.resetToDefaults { value, _ in precondition(value) } }
            smc.writes = []
            helper.inhibitChargingOnSleep()
            try require(smc.writes.isEmpty, "reset preserved sleep inhibition policy")
        }
        try test("LED values outside the supported allowlist are rejected") { helper, smc in
            let c = connected(helper)
            var accepted = true
            withRequest(c) { helper.setMagSafeLED(color: 255) { value, _ in accepted = value } }
            try require(!accepted && smc.writes.isEmpty, "invalid LED byte written")
        }
        try test("native-only backend restores owned LED on reset", nativeOnly: true) { helper, smc in
            let c = connected(helper)
            withRequest(c) { helper.setMagSafeLED(color: 3) { ok, _ in precondition(ok) } }
            try require(helper.needsRecovery && HelperState.ledOwned, "LED ownership was not journaled")
            helper.resetChargingDirect()
            try require(smc.keys["ACLC"] == [0] && !HelperState.ledOwned, "native reset left LED overridden")
            try require(smc.writes == ["ACLC", "ACLC"], "LED recovery touched unsupported charge keys")
        }
        try test("native-only LED is restored when client disconnects", nativeOnly: true) { helper, smc in
            let c = connected(helper)
            withRequest(c) { helper.setMagSafeLED(color: 4) { ok, _ in precondition(ok) } }
            c.invalidationHandler?()
            try require(smc.keys["ACLC"] == [0] && !helper.needsRecovery, "disconnect did not release LED")
        }
        try test("native-only sleep releases LED without a charge sleep policy", nativeOnly: true) { helper, smc in
            let c = connected(helper)
            withRequest(c) { helper.setMagSafeLED(color: 1) { ok, _ in precondition(ok) } }
            helper.inhibitChargingOnSleep()
            try require(smc.keys["ACLC"] == [0], "sleep retained custom LED")
        }
        try test("unregistered LED request cannot acquire ownership", nativeOnly: true) { helper, smc in
            var ok = true
            withRequest(NSXPCConnection()) { helper.setMagSafeLED(color: 3) { value, _ in ok = value } }
            try require(!ok && !HelperState.ledOwned && smc.writes.isEmpty, "unregistered LED request succeeded")
        }
        try test("pending LED retry never restores active native charging", nativeOnly: true) { helper, smc in
            let c = connected(helper)
            withRequest(c) { helper.setMagSafeLED(color: 3) { ok, _ in precondition(ok) } }
            smc.failAuto = true
            helper.inhibitChargingOnSleep()
            try require(helper.hasPendingRestoration, "positive control did not leave LED recovery pending")
            helper.retryPendingRestoration()
            try require(NativeChargeLimit.restores == 0, "LED failure reset native charge policy")
            smc.failAuto = false
            helper.retryPendingRestoration()
            try require(!helper.hasPendingRestoration && !HelperState.ledOwned, "LED retry did not finish")
            try require(NativeChargeLimit.restores == 0, "successful LED recovery reset native charge policy")
        }
        print("\(count) lifecycle tests passed; no real XPC, signature or hardware tested.")
    }
}
