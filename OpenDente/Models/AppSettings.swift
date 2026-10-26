import Foundation
import SwiftUI

/// All user-configurable settings, backed by UserDefaults.
/// Production uses `.standard` via `AppSettings.shared`.
/// Tests pass an isolated suite to avoid polluting real settings.
@MainActor
final class AppSettings: ObservableObject {

    static let shared = AppSettings()

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Charging

    var chargingEnabled: Bool {
        get { defaults.object(forKey: "chargingEnabled") as? Bool ?? true }
        set { objectWillChange.send(); defaults.set(newValue, forKey: "chargingEnabled") }
    }

    /// Charge limit percentage (20-100), clamped on set
    var chargeLimit: Int {
        get {
            let v = defaults.integer(forKey: "chargeLimit")
            return v == 0 ? 80 : min(100, max(20, v))
        }
        set {
            objectWillChange.send()
            defaults.set(min(100, max(20, newValue)), forKey: "chargeLimit")
        }
    }

    // MARK: - Sailing Mode

    var sailingModeEnabled: Bool {
        get { defaults.object(forKey: "sailingModeEnabled") as? Bool ?? true }
        set { objectWillChange.send(); defaults.set(newValue, forKey: "sailingModeEnabled") }
    }

    /// Sailing range percentage (2-90), clamped on set
    var sailingRange: Int {
        get {
            let v = defaults.integer(forKey: "sailingRange")
            return v == 0 ? 10 : min(90, max(2, v))
        }
        set {
            objectWillChange.send()
            defaults.set(min(90, max(2, newValue)), forKey: "sailingRange")
        }
    }

    // MARK: - Heat Protection

    var heatProtectionEnabled: Bool {
        get { defaults.object(forKey: "heatProtectionEnabled") as? Bool ?? true }
        set { objectWillChange.send(); defaults.set(newValue, forKey: "heatProtectionEnabled") }
    }

    /// Heat protection temperature threshold in Celsius (30-45), clamped on get/set
    var heatProtectionTemp: Double {
        get {
            let v = defaults.double(forKey: "heatProtectionTemp")
            return (v == 0 ? 40.0 : v).clamped(to: 30...45)
        }
        set {
            objectWillChange.send()
            defaults.set(newValue.clamped(to: 30...45), forKey: "heatProtectionTemp")
        }
    }

    // MARK: - Discharge

    var automaticDischarge: Bool {
        get { defaults.bool(forKey: "automaticDischarge") }
        set { objectWillChange.send(); defaults.set(newValue, forKey: "automaticDischarge") }
    }

    // MARK: - Sleep

    var stopChargingWhenSleeping: Bool {
        get { defaults.bool(forKey: "stopChargingWhenSleeping") }
        set { objectWillChange.send(); defaults.set(newValue, forKey: "stopChargingWhenSleeping") }
    }

    var disableSleepUntilChargeLimit: Bool {
        get { defaults.bool(forKey: "disableSleepUntilChargeLimit") }
        set { objectWillChange.send(); defaults.set(newValue, forKey: "disableSleepUntilChargeLimit") }
    }

    // MARK: - Status Bar Display

    var compactStatusBar: Bool {
        get { defaults.object(forKey: "compactStatusBar") as? Bool ?? true }
        set { objectWillChange.send(); defaults.set(newValue, forKey: "compactStatusBar") }
    }

    var statusBarShowPercentage: Bool {
        get { defaults.object(forKey: "statusBarShowPercentage") as? Bool ?? true }
        set { objectWillChange.send(); defaults.set(newValue, forKey: "statusBarShowPercentage") }
    }

    var statusBarShowTemperature: Bool {
        get { defaults.bool(forKey: "statusBarShowTemperature") }
        set { objectWillChange.send(); defaults.set(newValue, forKey: "statusBarShowTemperature") }
    }

    var statusBarShowPower: Bool {
        get { defaults.bool(forKey: "statusBarShowPower") }
        set { objectWillChange.send(); defaults.set(newValue, forKey: "statusBarShowPower") }
    }

    var statusBarShowMode: Bool {
        get { defaults.object(forKey: "statusBarShowMode") as? Bool ?? true }
        set { objectWillChange.send(); defaults.set(newValue, forKey: "statusBarShowMode") }
    }

    // MARK: - Power Flow

    var showPowerFlow: Bool {
        get { defaults.object(forKey: "showPowerFlow") as? Bool ?? true }
        set { objectWillChange.send(); defaults.set(newValue, forKey: "showPowerFlow") }
    }

    // MARK: - MagSafe LED

    var nativeMagSafeLEDEnabled: Bool {
        get { defaults.bool(forKey: "nativeMagSafeLEDEnabled") }
        set { objectWillChange.send(); defaults.set(newValue, forKey: "nativeMagSafeLEDEnabled") }
    }
    var nativeLEDChargingColor: MagSafeLEDChoice {
        get { MagSafeLEDChoice(rawValue: defaults.object(forKey: "nativeLEDChargingColor") as? Int ?? 4) ?? .orange }
        set { objectWillChange.send(); defaults.set(newValue.rawValue, forKey: "nativeLEDChargingColor") }
    }
    var nativeLEDPausedColor: MagSafeLEDChoice {
        get { MagSafeLEDChoice(rawValue: defaults.object(forKey: "nativeLEDPausedColor") as? Int ?? 3) ?? .green }
        set { objectWillChange.send(); defaults.set(newValue.rawValue, forKey: "nativeLEDPausedColor") }
    }
    var nativeLEDStorageColor: MagSafeLEDChoice {
        get { MagSafeLEDChoice(rawValue: defaults.object(forKey: "nativeLEDStorageColor") as? Int ?? 4) ?? .orange }
        set { objectWillChange.send(); defaults.set(newValue.rawValue, forKey: "nativeLEDStorageColor") }
    }
    var nativeLEDThermalColor: MagSafeLEDChoice {
        get { MagSafeLEDChoice(rawValue: defaults.object(forKey: "nativeLEDThermalColor") as? Int ?? 1) ?? .off }
        set { objectWillChange.send(); defaults.set(newValue.rawValue, forKey: "nativeLEDThermalColor") }
    }

    var nativeLEDTopUpColor: MagSafeLEDChoice {
        get { MagSafeLEDChoice(rawValue: defaults.object(forKey: "nativeLEDTopUpColor") as? Int ?? 4) ?? .orange }
        set { objectWillChange.send(); defaults.set(newValue.rawValue, forKey: "nativeLEDTopUpColor") }
    }
    var nativeLEDCompleteColor: MagSafeLEDChoice {
        get { MagSafeLEDChoice(rawValue: defaults.object(forKey: "nativeLEDCompleteColor") as? Int ?? 3) ?? .green }
        set { objectWillChange.send(); defaults.set(newValue.rawValue, forKey: "nativeLEDCompleteColor") }
    }
    func applyDistinctLEDSignals() {
        nativeMagSafeLEDEnabled = true
        nativeLEDChargingColor = .pulsingOrange
        nativeLEDPausedColor = .pulsingGreen
        nativeLEDStorageColor = .alternating
        nativeLEDThermalColor = .off
        nativeLEDTopUpColor = .orange
        nativeLEDCompleteColor = .green
    }

    var controlMagSafeLED: Bool {
        get { defaults.object(forKey: "controlMagSafeLED") as? Bool ?? true }
        set { objectWillChange.send(); defaults.set(newValue, forKey: "controlMagSafeLED") }
    }

    var magSafeLEDOffWhenInactive: Bool {
        get { defaults.bool(forKey: "magSafeLEDOffWhenInactive") }
        set { objectWillChange.send(); defaults.set(newValue, forKey: "magSafeLEDOffWhenInactive") }
    }

    // MARK: - General

    /// Opt-in: private PowerUI implementation with firmware-controlled hysteresis.
    /// Explicit opt-in: drain on external power only when above the usual cap.
    var nativeReturnToLimitEnabled: Bool {
        get { defaults.bool(forKey: "nativeReturnToLimitEnabled") }
        set { objectWillChange.send(); defaults.set(newValue, forKey: "nativeReturnToLimitEnabled") }
    }

    var storagePreparationEnabled: Bool {
        get { defaults.bool(forKey: "storagePreparationEnabled") }
        set { objectWillChange.send(); defaults.set(newValue, forKey: "storagePreparationEnabled") }
    }

    var nativeChargeLimitEnabled: Bool {
        get { defaults.bool(forKey: "nativeChargeLimitEnabled") }
        set { objectWillChange.send(); defaults.set(newValue, forKey: "nativeChargeLimitEnabled") }
    }

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: "launchAtLogin") }
        set { objectWillChange.send(); defaults.set(newValue, forKey: "launchAtLogin") }
    }

    var useHardwareBatteryPercentage: Bool {
        get { defaults.bool(forKey: "useHardwareBatteryPercentage") }
        set { objectWillChange.send(); defaults.set(newValue, forKey: "useHardwareBatteryPercentage") }
    }

    var showNotifications: Bool {
        get { defaults.object(forKey: "showNotifications") as? Bool ?? true }
        set { objectWillChange.send(); defaults.set(newValue, forKey: "showNotifications") }
    }

    var notifyChargeLimitReached: Bool {
        get { defaults.object(forKey: "notifyChargeLimitReached") as? Bool ?? true }
        set { objectWillChange.send(); defaults.set(newValue, forKey: "notifyChargeLimitReached") }
    }

    var notifyTopUpComplete: Bool {
        get { defaults.object(forKey: "notifyTopUpComplete") as? Bool ?? true }
        set { objectWillChange.send(); defaults.set(newValue, forKey: "notifyTopUpComplete") }
    }

    var notifyHeatProtection: Bool {
        get { defaults.object(forKey: "notifyHeatProtection") as? Bool ?? true }
        set { objectWillChange.send(); defaults.set(newValue, forKey: "notifyHeatProtection") }
    }

    var notifyDischargeComplete: Bool {
        get { defaults.object(forKey: "notifyDischargeComplete") as? Bool ?? true }
        set { objectWillChange.send(); defaults.set(newValue, forKey: "notifyDischargeComplete") }
    }

    // MARK: - Popover Detail Items

    /// Ordered list of enabled detail items in the popover
    var popoverDetailItems: [PopoverDetailItem] {
        get {
            guard let data = defaults.data(forKey: "popoverDetailItems"),
                  let items = try? JSONDecoder().decode([PopoverDetailItem].self, from: data)
            else {
                return PopoverDetailItem.defaultItems
            }
            return items
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                objectWillChange.send()
                defaults.set(data, forKey: "popoverDetailItems")
            }
        }
    }

    // MARK: - Computed

    /// Keep a usable reserve even when a wide range accompanies a low ceiling.
    var sailingLowerBound: Int {
        max(10, chargeLimit - sailingRange)
    }

    /// Profiles describe the charging policy, not a promise about battery lifespan.
    var selectedProfile: ChargeProfile? {
        guard sailingModeEnabled, heatProtectionEnabled, !automaticDischarge else { return nil }
        return ChargeProfile.allCases.first {
            $0.chargeLimit == chargeLimit && $0.resumeAt == sailingLowerBound
        }
    }

    func apply(profile: ChargeProfile) {
        // Selecting a daily profile explicitly ends the temporary storage mode.
        storagePreparationEnabled = false
        // Subscribers evaluate on the next run loop, after the complete policy is saved.
        chargeLimit = profile.chargeLimit
        sailingRange = profile.chargeLimit - profile.resumeAt
        sailingModeEnabled = true
        heatProtectionEnabled = true
        automaticDischarge = false
    }
}


/// Convenient starting points; the ceiling remains freely adjustable afterwards.
enum ChargeProfile: String, CaseIterable, Identifiable {
    case desk, everyday, travel

    var id: String { rawValue }

    var title: String {
        switch self {
        case .desk: "Bureau"
        case .everyday: "Quotidien"
        case .travel: "Mobilité"
        }
    }

    var chargeLimit: Int {
        switch self {
        case .desk: 70
        case .everyday: 80
        case .travel: 90
        }
    }

    var resumeAt: Int { chargeLimit - 10 }
}
