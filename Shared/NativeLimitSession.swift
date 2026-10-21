import Foundation

/// Transaction shared with tests. The helper serializes all calls under its lock.
/// No SMC writes, adapter disconnection, or fabricated recovery defaults.
final class NativeLimitSession {
    struct Snapshot: Codable, Equatable {
        let enabled: Int?
        let limit: Int?
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
