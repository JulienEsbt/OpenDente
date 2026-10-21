// Inert boundaries for the extracted production code. These never open IOKit,
// connect to XPC, change a battery, or register services.
protocol ObservableObject {}
struct InertPublisher { func send() {} }
extension ObservableObject {
    var objectWillChange: InertPublisher { InertPublisher() }
}

struct SMCValue { let bytes: [UInt8] }
final class SMCService: @unchecked Sendable {
    static let shared = SMCService()
    func readKeyOptional(_ key: String) -> SMCValue? { nil }
}

@MainActor
final class BatteryService {
    var batteryState = BatteryState.unknown
}

@MainActor
protocol SleepAssertionControl: AnyObject {
    func preventSleep(reason: String) -> Bool
    func allowSleep()
    var isPreventingSleep: Bool { get }
}
@MainActor
final class SleepAssertionManager: SleepAssertionControl {
    var isPreventingSleep = false
    func preventSleep(reason: String) -> Bool { isPreventingSleep = true; return true }
    func allowSleep() { isPreventingSleep = false }
}

@MainActor
final class NotificationService {
    enum Event { case inhibitFailed, systemChargeLimitConflict }
    static let shared = NotificationService()
    var sent: [Event] = []
    func send(_ event: Event, settings: AppSettings) { sent.append(event) }
}

final class RecordingController: ChargingControl, @unchecked Sendable {
    enum Call: Equatable {
        case enable, inhibit, forceDischarge(Bool), reset, led(UInt8)
    }
    var calls: [Call] = []
    var failInhibit = false
    var inhibitCount: Int { calls.filter { $0 == .inhibit }.count }
    func enableCharging(completion: (@Sendable (Bool, String?) -> Void)?) {
        calls.append(.enable); completion?(true, nil)
    }
    func inhibitCharging(completion: (@Sendable (Bool, String?) -> Void)?) {
        calls.append(.inhibit)
        completion?(!failInhibit, failInhibit ? "injected inhibit failure" : nil)
    }
    func forceDischarge(enable: Bool, completion: (@Sendable (Bool, String?) -> Void)?) {
        calls.append(.forceDischarge(enable)); completion?(true, nil)
    }
    func resetToDefaults(completion: (@Sendable (Bool, String?) -> Void)?) {
        calls.append(.reset); completion?(true, nil)
    }
    func setMagSafeLED(color: UInt8, completion: (@Sendable (Bool, String?) -> Void)?) {
        calls.append(.led(color)); completion?(true, nil)
    }
    nonisolated func resetToDefaultsSync(timeout: TimeInterval) { calls.append(.reset) }
}

func state(_ percentage: Int = 75, charging: Bool = false,
           plugged: Bool = true, temperature: Double? = 25) -> BatteryState {
    BatteryState(percentage: percentage, hardwarePercentage: nil, isCharging: charging,
        isPluggedIn: plugged, currentCapacity: nil, maxCapacity: nil, designCapacity: nil,
        cycleCount: nil, temperature: temperature, voltage: nil, amperage: nil,
        systemPower: nil, adapterPower: plugged ? 60 : nil, adapterInfo: nil,
        batteryPower: nil, notChargingReason: nil, chargerInhibitReason: nil,
        timeToEmpty: nil, timeToFull: nil)
}

@MainActor
final class Scenario {
    let name = "com.opendente.portable.\(UUID().uuidString)"
    let settings: AppSettings
    let battery = BatteryService()
    let controller = RecordingController()
    let manager: ChargingManager
    init() {
        settings = AppSettings(defaults: UserDefaults(suiteName: name)!)
        settings.controlMagSafeLED = false
        battery.batteryState = state()
        manager = ChargingManager(settings: settings, helper: controller, battery: battery,
                                  sleepAssertion: SleepAssertionManager())
        manager.chargingAPI = .tahoe
        manager.isHelperInstalled = true
        NotificationService.shared.sent = []
    }
    func evaluate(_ snapshot: BatteryState) {
        battery.batteryState = snapshot
        manager.evaluateState(snapshot)
    }
    func clearDefaults() { settings.defaults.removePersistentDomain(forName: name) }
}

struct FailedAssertion: Error, CustomStringConvertible { let description: String }
func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw FailedAssertion(description: message) }
}

// Service registration is not exercised by the portable state-machine tests.
enum SMAppService { enum Status: Sendable { case notRegistered } }
