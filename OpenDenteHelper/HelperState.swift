import Foundation
import os.log

private let log = Logger(subsystem: HelperConstants.machServiceName, category: "State")

/// Atomic state file for crash recovery.
/// On restart, the helper checks this file — if charging was inhibited when
/// the helper last crashed/exited, it re-enables charging immediately.
enum HelperState {
    private static let dir = HelperConstants.stateDirectory
    private static let path = HelperConstants.stateFilePath

    enum ChargingState: String {
        case normal = "normal"
        case inhibited = "inhibited"
    }

    /// Ensure the state directory exists with root-only permissions (0700)
    static func ensureDirectory() throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: dir) {
            try fm.createDirectory(
                atPath: dir,
                withIntermediateDirectories: false,
                attributes: [.posixPermissions: 0o700]
            )
        }
        // Do not chmod or write through an existing user-owned directory/symlink.
        let attributes = try fm.attributesOfItem(atPath: dir)
        guard attributes[.type] as? FileAttributeType == .typeDirectory,
              (attributes[.ownerAccountID] as? NSNumber)?.uint32Value == 0,
              let permissions = attributes[.posixPermissions] as? NSNumber,
              permissions.intValue & 0o022 == 0 else {
            throw ChargingHardwareController.Failure(message: "Unsafe helper state directory")
        }
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir)
    }

    /// Write the current charging state atomically
    static func write(_ state: ChargingState) throws {
        try ensureDirectory()
        if let attributes = try? FileManager.default.attributesOfItem(atPath: path) {
            guard attributes[.type] as? FileAttributeType == .typeRegular,
                  (attributes[.ownerAccountID] as? NSNumber)?.uint32Value == 0 else {
                throw ChargingHardwareController.Failure(message: "Unsafe helper state file")
            }
        }
        try state.rawValue.write(toFile: path, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
        log.info("State written: \(state.rawValue, privacy: .public)")
    }

    /// Read the last known charging state (returns nil if file doesn't exist)
    static func read() -> ChargingState? {
        guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else {
            return nil
        }
        return ChargingState(rawValue: contents.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Check if the helper previously had charging inhibited (crash recovery)
    static func wasChargingInhibited() -> Bool {
        // An existing unreadable/corrupt marker must not silently skip recovery.
        FileManager.default.fileExists(atPath: path) && read() != .normal
    }

    /// Clear the state file (set to normal)
    static func clear() throws {
        try write(.normal)
    }
}
