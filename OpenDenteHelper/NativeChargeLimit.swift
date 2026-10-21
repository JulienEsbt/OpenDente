import Foundation
import ObjectiveC
import IOKit.ps

/// Experimental PowerUI backend. Preferences/notification and the agent release
/// mechanism follow MIT-licensed Ampere; see THIRD-PARTY-NOTICES.md.
/// No entitlement changes or powerd policy archive modifications are made.
final class NativeChargeLimit {
    private static var domain: CFString { "com.apple.smartcharging.topoffprotection" as CFString }
    private static var stateKey: CFString { "MCLFeatureState" as CFString }
    private static var limitKey: CFString { "mclLimitValue" as CFString }
    private static let frameworkLoaded = dlopen("/System/Library/PrivateFrameworks/PowerUI.framework/Versions/A/PowerUI", RTLD_NOW) != nil
    private static var clientClass: AnyClass? {
        guard frameworkLoaded, let cls = NSClassFromString("PowerUISmartChargeClient"),
              ["initWithClientName:", "isMCLSupported", "isMCLCurrentlyEnabled:", "enableMCL:", "disableMCL:"]
                .allSatisfy({ class_getInstanceMethod(cls, NSSelectorFromString($0)) != nil }) else { return nil }
        return cls
    }
    static var isAvailable: Bool {
        guard let client = try? makeClient(),
              let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "objc_msgSend") else { return false }
        typealias Supported = @convention(c) (AnyObject, Selector) -> Bool
        return unsafeBitCast(symbol, to: Supported.self)(client, NSSelectorFromString("isMCLSupported"))
    }
    private let path = HelperConstants.stateDirectory + "/native-limit-originals.json"
    var needsRecovery: Bool { FileManager.default.fileExists(atPath: path) }
    var restorationPending: Bool { session.restorationPending }
    private lazy var session = NativeLimitSession(
        load: { try self.load() }, save: { try self.save($0) },
        capture: { try self.capture() }, apply: { try self.write(enabled: 1, limit: $0) },
        restore: { snapshot in
            try Self.disableViaAgent()
            try self.write(enabled: snapshot.enabled, limit: snapshot.limit)
        }, clear: { try FileManager.default.removeItem(atPath: self.path) })

    func setLimit(_ percent: Int) throws {
        guard Self.isAvailable,
              let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
              let capacity = description[kIOPSCurrentCapacityKey] as? Int,
              let maximum = description[kIOPSMaxCapacityKey] as? Int, maximum > 0 else {
            throw NativeLimitSession.Failure(message: "Native charge control or current battery reading unavailable")
        }
        try session.setLimit(percent, currentPercentage: Int(ceil(Double(capacity) * 100 / Double(maximum))))
    }
    func restore() throws { try session.restore() }

    private func validate(_ snapshot: NativeLimitSession.Snapshot) throws {
        guard snapshot.enabled == nil || snapshot.enabled == 0 || snapshot.enabled == 1,
              snapshot.limit == nil || (20...100).contains(snapshot.limit!),
              snapshot.enabled != 1 || snapshot.limit != nil else {
            throw NativeLimitSession.Failure(message: "Invalid native-limit recovery settings; no defaults invented")
        }
    }
    private func load() throws -> NativeLimitSession.Snapshot? {
        guard needsRecovery else { return nil }
        try checkFile()
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        guard data.count < 4096 else { throw NativeLimitSession.Failure(message: "Invalid native-limit journal size") }
        let snapshot = try JSONDecoder().decode(NativeLimitSession.Snapshot.self, from: data)
        try validate(snapshot)
        return snapshot
    }
    private func checkFile() throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              (attributes[.ownerAccountID] as? NSNumber)?.uint32Value == 0 else {
            throw NativeLimitSession.Failure(message: "Unsafe native-limit recovery file")
        }
    }
    private func save(_ snapshot: NativeLimitSession.Snapshot) throws {
        try validate(snapshot)
        try HelperState.ensureDirectory()
        if needsRecovery { try checkFile() }
        try JSONEncoder().encode(snapshot).write(to: URL(fileURLWithPath: path), options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
    }
    private func capture() throws -> NativeLimitSession.Snapshot {
        guard CFPreferencesSynchronize(Self.domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) else {
            throw NativeLimitSession.Failure(message: "Cannot read original macOS charge settings")
        }
        func read(_ key: CFString) throws -> Int? {
            guard let value = CFPreferencesCopyValue(key, Self.domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) else { return nil }
            guard let number = value as? NSNumber, number.doubleValue == Double(number.intValue) else {
                throw NativeLimitSession.Failure(message: "Unexpected macOS charge setting format")
            }
            return number.intValue
        }
        let snapshot = try NativeLimitSession.Snapshot(enabled: read(Self.stateKey), limit: read(Self.limitKey))
        try validate(snapshot)
        return snapshot
    }
    private func write(enabled: Int?, limit: Int?) throws {
        CFPreferencesSetValue(Self.stateKey, enabled.map(NSNumber.init(value:)), Self.domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        CFPreferencesSetValue(Self.limitKey, limit.map(NSNumber.init(value:)), Self.domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        guard CFPreferencesSynchronize(Self.domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost),
              let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "notify_post") else {
            throw NativeLimitSession.Failure(message: "Cannot save native charge settings")
        }
        typealias Post = @convention(c) (UnsafePointer<CChar>) -> UInt32
        let result = "com.apple.smartcharging.defaultschanged".withCString { unsafeBitCast(symbol, to: Post.self)($0) }
        guard result == 0 else { throw NativeLimitSession.Failure(message: "Cannot notify the macOS charge agent") }
        let observed = try capture()
        guard observed == NativeLimitSession.Snapshot(enabled: enabled, limit: limit) else {
            throw NativeLimitSession.Failure(message: "Native charge preference readback mismatch")
        }
    }

    /// Clearing preferences alone does not release an already registered limit.
    /// Ask the agent to disable its policy before restoring the original values.
    private static func makeClient() throws -> AnyObject {
        typealias Alloc = @convention(c) (AnyClass, Selector) -> Unmanaged<AnyObject>
        typealias Init = @convention(c) (AnyObject, Selector, NSString) -> Unmanaged<AnyObject>?
        guard let cls = clientClass, let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "objc_msgSend") else {
            throw NativeLimitSession.Failure(message: "PowerUI release interface unavailable")
        }
        let allocated = unsafeBitCast(symbol, to: Alloc.self)(cls, NSSelectorFromString("alloc")).takeUnretainedValue()
        guard let client = unsafeBitCast(symbol, to: Init.self)(allocated, NSSelectorFromString("initWithClientName:"), "OpenDente")?.takeRetainedValue() else {
            throw NativeLimitSession.Failure(message: "Cannot initialize PowerUI release client")
        }
        return client
    }

    private static func disableViaAgent() throws {
        typealias Query = @convention(c) (AnyObject, Selector, UnsafeMutablePointer<Unmanaged<NSError>?>) -> UInt64
        typealias Action = @convention(c) (AnyObject, Selector, UnsafeMutablePointer<Unmanaged<NSError>?>) -> Bool
        let client = try makeClient()
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "objc_msgSend") else {
            throw NativeLimitSession.Failure(message: "PowerUI release interface unavailable")
        }
        var error: Unmanaged<NSError>?
        let enabled = unsafeBitCast(symbol, to: Query.self)(client, NSSelectorFromString("isMCLCurrentlyEnabled:"), &error)
        guard error == nil else { throw error!.takeUnretainedValue() }
        if enabled == 0 {
            guard unsafeBitCast(symbol, to: Action.self)(client, NSSelectorFromString("enableMCL:"), &error), error == nil else {
                throw NativeLimitSession.Failure(message: "PowerUI could not prepare native limit release")
            }
        }
        guard unsafeBitCast(symbol, to: Action.self)(client, NSSelectorFromString("disableMCL:"), &error), error == nil else {
            throw NativeLimitSession.Failure(message: "PowerUI could not release native limit; journal retained")
        }
    }
}
