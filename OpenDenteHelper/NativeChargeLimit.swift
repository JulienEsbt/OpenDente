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
              ["initWithClientName:", "isMCLSupported", "setMCLLimit:error:", "getMCLLimitWithError:"]
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
        capture: { try self.capture() }, apply: { try self.apply($0) },
        restore: { snapshot in
            try Self.setLimitViaAgent(100)
            try self.restorePreferences(snapshot)
        }, clear: { try FileManager.default.removeItem(atPath: self.path) })

    func setLimit(_ percent: Int) throws {
        let reading = try currentReading()
        try session.setLimit(percent, currentPercentage: reading.percentage)
    }

    func prepareStorage() throws {
        let reading = try currentReading()
        guard reading.description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue else {
            throw NativeLimitSession.Failure(message: "Storage discharge requires connected external power")
        }
        try session.setStorageLimit(currentPercentage: reading.percentage)
    }

    func dischargeToLimit(_ percent: Int) throws {
        let reading = try currentReading()
        guard reading.description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue else {
            throw NativeLimitSession.Failure(message: "Le retour au plafond nécessite un chargeur branché.")
        }
        try session.setDischargeLimit(percent, currentPercentage: reading.percentage)
    }

    private func currentReading() throws -> InternalBatteryReading {
        guard Self.isAvailable,
              let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            throw NativeLimitSession.Failure(message: "Native charge control or current battery reading unavailable")
        }
        let descriptions = sources.compactMap {
            IOPSGetPowerSourceDescription(info, $0)?.takeUnretainedValue() as? [String: Any]
        }
        return try InternalBatteryReading.read(descriptions)
    }
    func restore() throws { try session.restore() }

    private func validate(_ snapshot: NativeLimitSession.Snapshot) throws {
        guard snapshot.enabled == nil || (0...2).contains(snapshot.enabled!),
              snapshot.limit == nil || (20...100).contains(snapshot.limit!),
              snapshot.enabled != 2 || snapshot.limit != nil else {
            throw NativeLimitSession.Failure(message: "État de recharge Apple non pris en charge ; aucun réglage modifié (état \(snapshot.enabled.map(String.init) ?? "absent")).")
        }
        if let data = snapshot.preferences {
            let values = try NativeLimitPreferences.decode(data)
            guard (values["MCLFeatureState"] as? NSNumber)?.intValue == snapshot.enabled,
                  (values["mclLimitValue"] as? NSNumber)?.intValue == snapshot.limit else {
                throw NativeLimitSession.Failure(message: "Inconsistent native charge recovery journal")
            }
        }
    }
    private func load() throws -> NativeLimitSession.Snapshot? {
        guard needsRecovery else { return nil }
        try checkFile()
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        guard data.count < 32768 else { throw NativeLimitSession.Failure(message: "Invalid native-limit journal size") }
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
        let preferences = try NativeLimitPreferences.encode(readPreferences())
        let snapshot = try NativeLimitSession.Snapshot(enabled: read(Self.stateKey), limit: read(Self.limitKey), preferences: preferences)
        try validate(snapshot)
        return snapshot
    }
    private func readPreferences() -> [String: Any] {
        let keys = CFPreferencesCopyKeyList(Self.domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? [String] ?? []
        var values: [String: Any] = [:]
        for key in keys where key.lowercased().hasPrefix("mcl") {
            if let value = CFPreferencesCopyValue(key as CFString, Self.domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) {
                values[key] = value
            }
        }
        return values
    }

    private func reloadPreferences() throws {
        guard CFPreferencesSynchronize(Self.domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost),
              let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "notify_post") else {
            throw NativeLimitSession.Failure(message: "Cannot save native charge settings")
        }
        typealias Post = @convention(c) (UnsafePointer<CChar>) -> UInt32
        let result = "com.apple.smartcharging.defaultschanged".withCString { unsafeBitCast(symbol, to: Post.self)($0) }
        guard result == 0 else { throw NativeLimitSession.Failure(message: "Cannot notify the macOS charge agent") }
    }

    private func apply(_ percent: Int) throws {
        // The agent owns its feature-state enumeration (disabled is 1 on the
        // tested macOS 27.2). Never presume that writing 1 enables the feature.
        // Its setter accepts 80...100; calling it below 80 is unsafe. For a lower
        // target, first activate 80 (above our freshly checked current level),
        // then replace only the target preference, retaining the agent's state.
        try Self.setLimitViaAgent(max(80, percent))
        if percent < 80 {
            CFPreferencesSetValue(Self.limitKey, NSNumber(value: percent), Self.domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
            try reloadPreferences()
        }
        let observed = try capture()
        guard observed.limit == percent else {
            throw NativeLimitSession.Failure(message: "Native charge target readback mismatch")
        }
    }

    private func restorePreferences(_ snapshot: NativeLimitSession.Snapshot) throws {
        if let data = snapshot.preferences {
            let originals = try NativeLimitPreferences.decode(data)
            for key in Set(readPreferences().keys).union(originals.keys) {
                CFPreferencesSetValue(key as CFString, originals[key] as CFPropertyList?, Self.domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
            }
            try reloadPreferences()
            guard NSDictionary(dictionary: readPreferences()).isEqual(to: originals) else {
                throw NativeLimitSession.Failure(message: "Native charge restoration readback mismatch")
            }
        } else {
            // Legacy helper 1.5.0 journals contain only these two values.
            CFPreferencesSetValue(Self.stateKey, snapshot.enabled.map(NSNumber.init(value:)), Self.domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
            CFPreferencesSetValue(Self.limitKey, snapshot.limit.map(NSNumber.init(value:)), Self.domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
            try reloadPreferences()
            let observed = try capture()
            guard observed.enabled == snapshot.enabled, observed.limit == snapshot.limit else {
                throw NativeLimitSession.Failure(message: "Legacy native charge restoration readback mismatch")
            }
        }
    }

    private static func setLimitViaAgent(_ percent: Int) throws {
        guard (80...100).contains(percent) else { throw NativeLimitSession.Failure(message: "Unsafe PowerUI setter target") }
        typealias Setter = @convention(c) (AnyObject, Selector, UInt8, UnsafeMutablePointer<Unmanaged<NSError>?>) -> Bool
        typealias Getter = @convention(c) (AnyObject, Selector, UnsafeMutablePointer<Unmanaged<NSError>?>) -> UInt8
        let client = try makeClient()
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "objc_msgSend") else {
            throw NativeLimitSession.Failure(message: "PowerUI target interface unavailable")
        }
        var error: Unmanaged<NSError>?
        guard unsafeBitCast(symbol, to: Setter.self)(client, NSSelectorFromString("setMCLLimit:error:"), UInt8(percent), &error), error == nil else {
            throw NativeLimitSession.Failure(message: error?.takeUnretainedValue().localizedDescription ?? "PowerUI rejected the target")
        }
        let readback = unsafeBitCast(symbol, to: Getter.self)(client, NSSelectorFromString("getMCLLimitWithError:"), &error)
        guard error == nil, readback == UInt8(percent) else {
            throw NativeLimitSession.Failure(message: "PowerUI target acknowledgement mismatch")
        }
    }

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

}
