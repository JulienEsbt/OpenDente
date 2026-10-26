import Foundation

/// Serialised by HelperDelegate's lock. Persistence and SMC are injected so failure
/// recovery is exercised without privileged writes or a real battery.
final class ChargingHardwareController {
    private let api: SMCChargingAPI
    private let hasLED: Bool
    private let write: (String, [UInt8]) throws -> Void
    private let read: (String) throws -> [UInt8]
    private let persistRecovery: (Bool) throws -> Void
    private(set) var recoveryRequired = false
    /// Unlike normal inhibition, a failed restore must be retried even while the
    /// app is alive and continues sending heartbeat messages.
    private(set) var restorationPending = false

    init(api: SMCChargingAPI, hasLED: Bool,
         write: @escaping (String, [UInt8]) throws -> Void,
         read: @escaping (String) throws -> [UInt8],
         persistRecovery: @escaping (Bool) throws -> Void) {
        self.api = api
        self.hasLED = hasLED
        self.write = write
        self.read = read
        self.persistRecovery = persistRecovery
    }

    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private var chargeKeys: [(String, [UInt8])] {
        switch api {
        case .legacy: return [("CH0B", [0]), ("CH0C", [0])]
        case .tahoe: return [("CHTE", [0, 0, 0, 0])]
        case .unknown: return []
        }
    }

    private var adapterKey: String { api == .legacy ? "CH0I" : "CHIE" }

    private func requireAPI() throws {
        guard api != .unknown else { throw Failure(message: "No charging API detected") }
    }

    private func writeVerified(_ key: String, _ value: [UInt8]) throws {
        try write(key, value)
        guard try read(key) == value else {
            throw Failure(message: "SMC readback mismatch for \(key)")
        }
    }

    /// The recovery marker must reach disk BEFORE the first restrictive write.
    private func restrict(_ action: () throws -> Void) throws {
        try requireAPI()
        if restorationPending { try restoreDefaults() }
        try persistRecovery(true)
        recoveryRequired = true
        do {
            try action()
        } catch {
            let original = error.localizedDescription
            do {
                try restoreDefaults()
            } catch {
                throw Failure(message: "\(original). Recovery incomplete: \(error.localizedDescription)")
            }
            throw Failure(message: "\(original). Safe defaults restored.")
        }
    }

    func inhibitCharging() throws {
        try restrict {
            for (key, zeroes) in chargeKeys {
                var value = zeroes
                value[0] = api == .legacy ? 0x02 : 0x01
                try writeVerified(key, value)
            }
        }
    }

    func forceDischarge(enable: Bool) throws {
        if !enable {
            try requireAPI()
            do {
                try writeVerified(adapterKey, [0])
            } catch {
                let original = error.localizedDescription
                do { try restoreDefaults() }
                catch { throw Failure(message: "\(original). Recovery incomplete: \(error.localizedDescription)") }
                throw Failure(message: "\(original). Safe defaults restored.")
            }
            // Charging may still be inhibited; keep the recovery marker.
            return
        }
        try restrict {
            try writeVerified(adapterKey, [api == .legacy ? 0x01 : 0x08])
            for (key, zeroes) in chargeKeys {
                var value = zeroes
                value[0] = api == .legacy ? 0x02 : 0x01
                try writeVerified(key, value)
            }
        }
    }

    /// All safety writes are attempted, even if an earlier write fails. A failed
    /// restore stays pending in memory and on disk for the watchdog/restart path.
    func restoreDefaults(resetLED: Bool = true) throws {
        try requireAPI()
        recoveryRequired = true
        restorationPending = true
        var failures: [String] = []
        do { try persistRecovery(true) }
        catch { failures.append("Recovery marker: \(error.localizedDescription)") }

        var keys = [(adapterKey, [UInt8(0)])] + chargeKeys
        if resetLED && hasLED { keys.append(("ACLC", [0])) }
        for (key, value) in keys {
            do { try writeVerified(key, value) }
            catch { failures.append("\(key): \(error.localizedDescription)") }
        }
        guard failures.isEmpty else { throw Failure(message: failures.joined(separator: "; ")) }
        try persistRecovery(false)
        recoveryRequired = false
        restorationPending = false
    }
}
