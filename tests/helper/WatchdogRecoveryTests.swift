import Foundation

private final class RecoveryFixture: @unchecked Sendable {
    var keys: [String: [UInt8]] = ["CHIE": [0], "CHTE": [0, 0, 0, 0]]
    var marker = false
    var injectFailure = false
    var restores = 0
    var pendingRetries = 0
    lazy var controller = ChargingHardwareController(api: .tahoe, hasLED: false,
        write: { key, value in
            if self.injectFailure && ((key == "CHIE" && value == [0]) || (key == "CHTE" && value.first == 1)) {
                throw ChargingHardwareController.Failure(message: "injected partial write/reset failure")
            }
            self.keys[key] = value
        }, read: { key in self.keys[key]! }, persistRecovery: { self.marker = $0 })
}

private func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw ChargingHardwareController.Failure(message: message) }
}

@main
struct WatchdogRecoveryTests {
    static func main() throws {
        let f = RecoveryFixture()
        let watchdog = Watchdog(needsRecovery: { f.controller.recoveryRequired },
                                hasPendingRestoration: { f.controller.restorationPending }) {
            f.restores += 1
            try? f.controller.restoreDefaults()
        }
        try f.controller.inhibitCharging()
        watchdog.receivedHeartbeat()
        watchdog.runCheckForTesting()
        try require(f.restores == 0, "fresh heartbeat failed to preserve intentional inhibition")
        print("PASS watchdog preserves normal inhibition with live heartbeat")

        try f.controller.restoreDefaults()
        f.injectFailure = true
        do { try f.controller.forceDischarge(enable: true) } catch { }
        try require(f.keys["CHIE"] == [8] && f.controller.restorationPending && f.marker,
                    "positive control did not leave the failed adapter restoration pending")
        watchdog.receivedHeartbeat()
        watchdog.runCheckForTesting()
        try require(f.restores == 1 && f.controller.restorationPending,
                    "failed restoration was not retried while app was alive")
        print("PASS watchdog retries a failed restore despite live heartbeat")

        f.injectFailure = false
        watchdog.receivedHeartbeat()
        watchdog.runCheckForTesting()
        try require(f.restores == 2 && f.keys["CHIE"] == [0] && !f.controller.restorationPending && !f.marker,
                    "live-heartbeat retry did not recover after hardware became available")
        watchdog.receivedHeartbeat()
        watchdog.runCheckForTesting()
        try require(f.restores == 2, "watchdog continued restoration after success")
        print("PASS watchdog clears pending recovery only after successful retry")
        let separate = RecoveryFixture()
        let isolated = Watchdog(needsRecovery: { true }, hasPendingRestoration: { true },
            retryPendingRestoration: { separate.pendingRetries += 1 }) { separate.restores += 1 }
        isolated.receivedHeartbeat()
        isolated.runCheckForTesting()
        try require(separate.pendingRetries == 1 && separate.restores == 0,
                    "pending LED recovery released an active charge session")
        print("PASS pending recovery has a separate action while client remains alive")
        isolated.runCheckForTesting(stale: true)
        try require(separate.restores == 1 && separate.pendingRetries == 1,
                    "pending LED recovery prevented full restoration after heartbeat timeout")
        print("PASS heartbeat timeout restores all controls even with pending LED recovery")
        print("5 watchdog tests passed; real check logic, no hardware or wall-clock waiting.")
    }
}
