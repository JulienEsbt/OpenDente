import Foundation
import os.log
import Security
import CryptoKit

private let log = Logger(subsystem: HelperConstants.machServiceName, category: "Delegate")

/// XPC listener delegate and protocol implementation.
/// Verifies callers via code signing, performs SMC writes, manages state.
final class HelperDelegate: NSObject, NSXPCListenerDelegate, HelperProtocol {

    private let native = NativeChargeLimit()
    private let smc = SMCService.shared
    private let watchdog: Watchdog
    private let lock = NSLock()

    /// Detected charging API for this Mac
    private var chargingAPI: SMCChargingAPI = .unknown

    /// Whether this Mac has a MagSafe LED controllable via ACLC
    private var hasMagSafeLED = false

    // Connections become active only while handling a message authenticated by
    // NSXPCConnection's signing requirement. Merely connecting cannot reset SMC.
    private var connectionGenerations: [ObjectIdentifier: UInt64] = [:]
    private var nextConnectionGeneration: UInt64 = 0
    private var activeClientGeneration: UInt64?
    private var latestActivatedGeneration: UInt64 = 0
    private var hardware: ChargingHardwareController!
    private var led: MagSafeLEDSession!
    private let callerRequirement = HelperDelegate.makeCallerRequirement()

    /// Synced from app — if true, helper inhibits charging independently on sleep.
    /// Accessed under lock (written by XPC, read by IOKit sleep callback).
    private var stopChargingWhenSleeping = false

    /// LED color to set when inhibiting charging on sleep (0xFF = don't touch LED).
    /// Synced from app alongside stopChargingWhenSleeping.
    private var sleepLEDColor: UInt8 = 0xFF

    init(watchdog: Watchdog) {
        self.watchdog = watchdog
        super.init()
        openSMC()
        detectChargingAPI()
        hardware = ChargingHardwareController(
            api: chargingAPI, hasLED: hasMagSafeLED,
            write: { [smc] key, bytes in try smc.writeKey(key, bytes: bytes) },
            read: { [smc] key in try smc.readKey(key).bytes },
            persistRecovery: { required in try HelperState.write(required ? .inhibited : .normal) }
        )
        led = MagSafeLEDSession(needsRecovery: HelperState.wasLEDOverridden(),
            write: { [smc] color in try smc.writeKey("ACLC", bytes: [color]) },
            read: { [smc] in
                let bytes = try smc.readKey("ACLC").bytes
                guard bytes.count == 1, let value = bytes.first else {
                    throw MagSafeLEDSession.Failure(message: "Unsupported MagSafe LED register")
                }
                return value
            }, persist: { try HelperState.writeLEDRecovery($0) })
    }

    // MARK: - SMC Setup

    private func openSMC() {
        do {
            try smc.open()
            log.info("SMC connection opened")
        } catch {
            log.error("Failed to open SMC: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func detectChargingAPI() {
        if smc.keyExists("CHTE") {
            chargingAPI = .tahoe
            log.info("Detected Tahoe charging API (CHTE/CHIE)")
        } else if smc.keyExists("CH0B") {
            chargingAPI = .legacy
            log.info("Detected legacy charging API (CH0B/CH0C)")
        } else {
            chargingAPI = .unknown
            log.info("No charging control keys detected")
        }

        // Check for MagSafe LED control (not all Macs have MagSafe)
        hasMagSafeLED = smc.keyExists("ACLC")
        log.info("MagSafe LED (ACLC): \(self.hasMagSafeLED ? "available" : "not found", privacy: .public)")

        // Diagnostic: log all charging-related key availability with current values
        let diagnosticKeys = ["CHTE", "CHIE", "CH0B", "CH0C", "CH0I", "CH0J", "ACLC"]
        for key in diagnosticKeys {
            if let info = smc.keyInfo(key) {
                if let value = smc.readKeyOptional(key) {
                    let hex = hexString(value.bytes)
                    log.info("SMC key \(key, privacy: .public): type=\(info.type, privacy: .public) size=\(info.size, privacy: .public) value=[\(hex, privacy: .public)]")
                } else {
                    log.info("SMC key \(key, privacy: .public): type=\(info.type, privacy: .public) size=\(info.size, privacy: .public) value=<unreadable>")
                }
            } else {
                log.info("SMC key \(key, privacy: .public): not found")
            }
        }
    }

    // MARK: - Verification

    /// Format bytes array as hex string for logging (e.g. "01 00 00 00")
    private func hexString(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    // MARK: - NSXPCListenerDelegate

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        guard let callerRequirement else {
            log.error("Rejecting XPC: helper must be signed with the same certificate as the app")
            return false
        }
        // Public since macOS 13. Foundation checks the peer on incoming messages;
        // no PID lookup, private auditToken API, or DEBUG authentication bypass.
        connection.setCodeSigningRequirement(callerRequirement)
        connection.exportedInterface = NSXPCInterface(with: HelperProtocol.self)
        connection.exportedObject = self

        let identifier = ObjectIdentifier(connection)
        lock.lock()
        nextConnectionGeneration += 1
        let generation = nextConnectionGeneration
        connectionGenerations[identifier] = generation
        lock.unlock()

        connection.invalidationHandler = { [weak self] in
            self?.handleClientDisconnect(identifier: identifier, generation: generation)
        }
        connection.interruptionHandler = { log.info("XPC connection interrupted") }
        connection.resume()
        return true
    }

    // MARK: - Caller Verification

    /// Pin the installed helper's signing certificate, not a publisher-controlled
    /// identifier alone. This also supports a local signing certificate; ad-hoc
    /// signatures have no certificate and are deliberately rejected.
    private static func makeCallerRequirement() -> String? {
        var ownCode: SecCode?
        guard SecCodeCopySelf([], &ownCode) == errSecSuccess, let ownCode,
              SecCodeCheckValidity(ownCode, [], nil) == errSecSuccess else { return nil }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(ownCode, [], &staticCode) == errSecSuccess, let staticCode,
              SecStaticCodeCheckValidity(staticCode, [], nil) == errSecSuccess else { return nil }
        var information: CFDictionary?
        guard SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
              let info = information as? [String: Any],
              let certificates = info[kSecCodeInfoCertificates as String] as? [SecCertificate],
              let leaf = certificates.first else { return nil }
        // Apple's requirement language uses a SHA-1 certificate fingerprint.
        // This selects an existing certificate; it is not a password hash.
        let data = SecCertificateCopyData(leaf) as Data
        let fingerprint = Insecure.SHA1.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let text = "identifier \"\(HelperConstants.appBundleID)\" and certificate leaf = H\"\(fingerprint)\""
        var compiled: SecRequirement?
        guard SecRequirementCreateWithString(text as CFString, [], &compiled) == errSecSuccess else { return nil }
        return text
    }

    /// Called under lock, directly from an exported XPC method. Foundation has
    /// already enforced the requirement before invoking that method.
    private func activateCurrentClientLocked() -> Bool {
        guard let connection = NSXPCConnection.current(),
              let generation = connectionGenerations[ObjectIdentifier(connection)],
              generation >= latestActivatedGeneration else { return false }
        if activeClientGeneration != generation {
            stopChargingWhenSleeping = false
            sleepLEDColor = 0xFF
            activeClientGeneration = generation
            latestActivatedGeneration = generation
        }
        watchdog.receivedHeartbeat()
        return true
    }

    private func clearSleepPolicyLocked() {
        stopChargingWhenSleeping = false
        sleepLEDColor = 0xFF
    }

    private func handleClientDisconnect(identifier: ObjectIdentifier, generation: UInt64) {
        lock.lock()
        defer { lock.unlock() }
        if connectionGenerations[identifier] == generation {
            connectionGenerations.removeValue(forKey: identifier)
        }
        // A refused connection or an obsolete client's callback must not affect
        // the current authenticated client or its battery state.
        guard activeClientGeneration == generation else { return }
        activeClientGeneration = nil
        clearSleepPolicyLocked()
        watchdog.resume()
        _ = resetChargingDirectLocked()
    }

    // MARK: - HelperProtocol

    private func perform(_ reply: (Bool, String?) -> Void, action: () throws -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard activateCurrentClientLocked() else {
            reply(false, "No active authenticated client")
            return
        }
        do {
            try action()
            reply(true, nil)
        } catch {
            log.error("Charging operation failed: \(error.localizedDescription, privacy: .public)")
            reply(false, error.localizedDescription)
        }
    }

    func setNativeChargeLimit(percent: Int, reply: @escaping (Bool, String?) -> Void) {
        perform(reply) {
            guard chargingAPI == .unknown, NativeChargeLimit.isAvailable else {
                throw NativeLimitSession.Failure(message: "Native limit unavailable on this backend")
            }
            try native.setLimit(percent)
        }
    }

    func prepareStorage(reply: @escaping (Bool, String?) -> Void) {
        perform(reply) {
            guard chargingAPI == .unknown, NativeChargeLimit.isAvailable else {
                throw NativeLimitSession.Failure(message: "Native storage preparation unavailable")
            }
            try native.prepareStorage()
        }
    }

    func dischargeToLimit(percent: Int, reply: @escaping (Bool, String?) -> Void) {
        perform(reply) {
            guard chargingAPI == .unknown, NativeChargeLimit.isAvailable else {
                throw NativeLimitSession.Failure(message: "Native return to cap unavailable on this backend")
            }
            try native.dischargeToLimit(percent)
        }
    }

    func enableCharging(reply: @escaping (Bool, String?) -> Void) {
        perform(reply) { try hardware.restoreDefaults(resetLED: false) }
    }

    func inhibitCharging(reply: @escaping (Bool, String?) -> Void) {
        perform(reply) { try hardware.inhibitCharging() }
    }

    func forceDischarge(enable: Bool, reply: @escaping (Bool, String?) -> Void) {
        perform(reply) { try hardware.forceDischarge(enable: enable) }
    }

    func resetToDefaults(reply: @escaping (Bool, String?) -> Void) {
        perform(reply) {
            clearSleepPolicyLocked()
            try restoreAllDefaultsLocked()
        }
    }

    func heartbeat(reply: @escaping (Bool) -> Void) {
        lock.lock()
        let accepted = activateCurrentClientLocked()
        lock.unlock()
        reply(accepted)
    }

    func suspendWatchdog(reply: @escaping (Bool) -> Void) {
        lock.lock()
        let accepted = activateCurrentClientLocked()
        if accepted { watchdog.suspend() }
        lock.unlock()
        reply(accepted)
    }

    func getVersion(reply: @escaping (String) -> Void) {
        lock.lock()
        let accepted = activateCurrentClientLocked()
        lock.unlock()
        reply(accepted ? HelperConstants.helperVersion : "")
    }

    func getChargingAPI(reply: @escaping (String) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard activateCurrentClientLocked() else { reply("unknown"); return }
        switch chargingAPI {
        case .legacy: reply("legacy")
        case .tahoe: reply("tahoe")
        case .unknown: reply(NativeChargeLimit.isAvailable ? "native" : "unknown")
        }
    }

    func syncSleepSettings(stopChargingWhenSleeping: Bool, sleepLEDColor: UInt8, reply: @escaping (Bool) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard activateCurrentClientLocked(), Self.allowedLEDColors.contains(sleepLEDColor) || sleepLEDColor == 0xFF else {
            reply(false)
            return
        }
        self.stopChargingWhenSleeping = stopChargingWhenSleeping
        self.sleepLEDColor = sleepLEDColor
        reply(true)
    }

    private static let allowedLEDColors = MagSafeLEDSession.allowed

    func setMagSafeLED(color: UInt8, reply: @escaping (Bool, String?) -> Void) {
        perform(reply) {
            guard hasMagSafeLED, Self.allowedLEDColors.contains(color) else {
                throw ChargingHardwareController.Failure(message: "Unavailable MagSafe LED or unsupported color")
            }
            try led.set(color)
            log.info("MagSafe LED confirmed: \(color, privacy: .public)")
        }
    }

    // MARK: - Sleep and Recovery

    func inhibitChargingOnSleep() {
        lock.lock()
        defer { lock.unlock() }
        // Native and legacy LED ownership is independent of charge-key support.
        do { try led.restore() }
        catch {
            log.error("LED sleep restoration pending: \(error.localizedDescription, privacy: .public)")
        }
        guard activeClientGeneration != nil, stopChargingWhenSleeping else { return }
        do {
            try hardware.inhibitCharging()
            if hasMagSafeLED && sleepLEDColor != 0xFF {
                try led.set(sleepLEDColor)
            }
        } catch {
            log.error("Sleep inhibition failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    var needsRecovery: Bool {
        lock.lock()
        defer { lock.unlock() }
        return native.needsRecovery || led.needsRecovery || hardware.recoveryRequired || HelperState.wasChargingInhibited()
    }

    var hasPendingRestoration: Bool {
        lock.lock()
        defer { lock.unlock() }
        return native.restorationPending || led.restorationPending || hardware.restorationPending
    }

    /// A live client's pending LED recovery must not release its native ceiling.
    /// Disconnect and heartbeat timeout still restore every owned subsystem.
    func retryPendingRestoration() {
        lock.lock()
        defer { lock.unlock() }
        if native.restorationPending {
            do { try native.restore() }
            catch {
                log.error("Native recovery pending: \(error.localizedDescription, privacy: .public)")
            }
        }
        if hardware.restorationPending {
            do { try hardware.restoreDefaults(resetLED: false) }
            catch {
                log.error("Charge recovery pending: \(error.localizedDescription, privacy: .public)")
            }
        }
        if led.restorationPending {
            do { try led.restore() }
            catch {
                log.error("LED recovery pending: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Watchdog, signal and restart paths also discard the departed app's policy.
    func resetChargingDirect() {
        lock.lock()
        defer { lock.unlock() }
        clearSleepPolicyLocked()
        _ = resetChargingDirectLocked()
    }

    private func restoreAllDefaultsLocked() throws {
        var failures: [String] = []
        do { try native.restore() } catch { failures.append(error.localizedDescription) }
        if chargingAPI != .unknown {
            do { try hardware.restoreDefaults(resetLED: false) } catch { failures.append(error.localizedDescription) }
        }
        do { try led.restore() } catch { failures.append(error.localizedDescription) }
        guard failures.isEmpty else { throw NativeLimitSession.Failure(message: failures.joined(separator: "; ")) }
    }

    private func resetChargingDirectLocked() -> Bool {
        do {
            try restoreAllDefaultsLocked()
            log.info("Safe defaults restored")
            return true
        } catch {
            log.error("Safe-default recovery remains pending: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
