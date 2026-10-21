import Foundation

/// Transaction shared with tests. The helper serializes all calls under its lock.
/// No SMC writes, adapter disconnection, or fabricated recovery defaults.
final class NativeLimitSession {
    struct Snapshot: Codable, Equatable {
        let enabled: Int?
        let limit: Int?
        /// Entire MCL preference subset, including temporary override dates.
        /// Nil supports recovery journals created by helper 1.5.0.
        let preferences: Data?

        init(enabled: Int?, limit: Int?, preferences: Data? = nil) {
            self.enabled = enabled; self.limit = limit; self.preferences = preferences
        }
    }
    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }
    private let load: () throws -> Snapshot?
    private let save: (Snapshot) throws -> Void
    private let capture: () throws -> Snapshot
    private let apply: (Int) throws -> Void
    private let restoreOriginals: (Snapshot) throws -> Void
    private let clear: () throws -> Void
    private(set) var restorationPending = false

    init(load: @escaping () throws -> Snapshot?, save: @escaping (Snapshot) throws -> Void,
         capture: @escaping () throws -> Snapshot, apply: @escaping (Int) throws -> Void,
         restore: @escaping (Snapshot) throws -> Void, clear: @escaping () throws -> Void) {
        self.load = load; self.save = save; self.capture = capture
        self.apply = apply; self.restoreOriginals = restore; self.clear = clear
    }

    func setLimit(_ percent: Int, currentPercentage: Int) throws {
        guard (20...100).contains(percent), (0...100).contains(currentPercentage),
              percent >= currentPercentage else {
            throw Failure(message: "Native limit rejected: invalid target or target below the current level")
        }
        try applyWithRecovery(percent)
    }

    /// Explicit one-shot preparation intent, fixed at Apple's approximate storage
    /// level. Ordinary profiles retain their no-drain invariant.
    func setStorageLimit(currentPercentage: Int) throws {
        guard (50...100).contains(currentPercentage) else {
            throw Failure(message: "Storage preparation rejected: invalid or already lower battery level")
        }
        try applyWithRecovery(50)
    }

    /// Separate explicit intent: below-current targets are never accepted by setLimit.
    func setDischargeLimit(_ percent: Int, currentPercentage: Int) throws {
        guard (20...100).contains(percent), (0...100).contains(currentPercentage),
              percent <= currentPercentage else {
            throw Failure(message: "Retour au plafond refusé : cible ou niveau courant incohérent.")
        }
        try applyWithRecovery(percent)
    }

    private func applyWithRecovery(_ percent: Int) throws {
        if restorationPending { try restore() }
        if try load() == nil { try save(capture()) }
        do { try apply(percent) }
        catch {
            let message = error.localizedDescription
            do { try restore() }
            catch { throw Failure(message: "\(message). Restoration pending: \(error.localizedDescription)") }
            throw Failure(message: "\(message). Original macOS limit restored.")
        }
    }

    func restore() throws {
        guard let snapshot = try load() else { restorationPending = false; return }
        restorationPending = true
        try restoreOriginals(snapshot)
        try clear()
        restorationPending = false
    }
}

/// Bounded property-list storage preserves Date/Data values without constructing
/// archived classes. Only the charge-limit namespace may be restored.
enum NativeLimitPreferences {
    static func encode(_ values: [String: Any]) throws -> Data {
        guard values.count <= 64, values.keys.allSatisfy({ $0.lowercased().hasPrefix("mcl") }) else {
            throw NativeLimitSession.Failure(message: "Invalid native charge preference namespace")
        }
        let data = try PropertyListSerialization.data(fromPropertyList: values, format: .binary, options: 0)
        guard data.count <= 16384 else { throw NativeLimitSession.Failure(message: "Native charge preference journal too large") }
        return data
    }

    static func decode(_ data: Data) throws -> [String: Any] {
        guard data.count <= 16384,
              let values = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            throw NativeLimitSession.Failure(message: "Invalid native charge preference journal")
        }
        _ = try encode(values)
        return values
    }
}
