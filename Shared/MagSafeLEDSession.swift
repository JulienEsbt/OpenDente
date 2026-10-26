import Foundation

/// LED ownership is recovered independently of charging API availability.
/// Persist before overriding. Zero is an action, not a latched readback value: the
/// firmware may immediately expose its current green/orange system color instead.
final class MagSafeLEDSession {
    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }
    static let allowed: Set<UInt8> = [0, 1, 3, 4]
    private(set) var needsRecovery: Bool
    private(set) var restorationPending = false
    private let write: (UInt8) throws -> Void
    private let read: () throws -> UInt8
    private let persist: (Bool) throws -> Void

    init(needsRecovery: Bool, write: @escaping (UInt8) throws -> Void,
         read: @escaping () throws -> UInt8, persist: @escaping (Bool) throws -> Void) {
        self.needsRecovery = needsRecovery; self.write = write
        self.read = read; self.persist = persist
    }
    func set(_ color: UInt8) throws {
        guard Self.allowed.contains(color) else { throw Failure(message: "Unsupported MagSafe LED color") }
        if color == 0 { try restore(force: true); return }
        if restorationPending { try restore() }
        if !needsRecovery {
            try persist(true)
            needsRecovery = true
        }
        do {
            try write(color)
            var actual = try read()
            // The cable/firmware can apply the write after the SMC call returns.
            for _ in 0..<6 where actual != color {
                Thread.sleep(forTimeInterval: 0.05)
                actual = try read()
            }
            guard actual == color else {
                throw Failure(message: "Voyant non confirmé (couleur demandée \(color), lue \(actual)).")
            }
        } catch {
            let original = error.localizedDescription
            do { try restore() }
            catch { throw Failure(message: "\(original). LED restoration pending: \(error.localizedDescription)") }
            throw Failure(message: "\(original). System LED control restored.")
        }
    }
    func restore(force: Bool = false) throws {
        guard needsRecovery || force else { return }
        restorationPending = true
        try write(0)
        // Successful write acknowledges release. Reading ACLC then reports the
        // system's visible color (observed 4), so equality with zero is invalid.
        let actual = try read()
        guard Self.allowed.contains(actual) else {
            throw Failure(message: "Réponse du voyant inconnue après retour au système : \(actual).")
        }
        try persist(false)
        needsRecovery = false
        restorationPending = false
    }
}
