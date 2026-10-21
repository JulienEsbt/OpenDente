import Foundation

/// LED ownership is recovered independently of charging API availability.
/// Persist before overriding; only clear ownership after verified system control.
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
        try persist(true)
        needsRecovery = true
        do {
            try write(color)
            guard try read() == color else { throw Failure(message: "MagSafe LED readback mismatch") }
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
        guard try read() == 0 else { throw Failure(message: "Cannot confirm system MagSafe LED control") }
        try persist(false)
        needsRecovery = false
        restorationPending = false
    }
}
