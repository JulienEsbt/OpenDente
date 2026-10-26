import XCTest
@testable import OpenDente

@MainActor
final class NativeLEDTests: XCTestCase {
    var settings: AppSettings!
    var helper: MockChargingControl!
    var battery: BatteryService!
    var manager: ChargingManager!
    var suite: String!
    override func setUp() async throws {
        suite = "com.opendente.tests.led.\(UUID().uuidString)"
        settings = AppSettings(defaults: UserDefaults(suiteName: suite)!)
        settings.nativeChargeLimitEnabled = true
        settings.showNotifications = false
        helper = MockChargingControl()
        battery = BatteryService(settings: settings)
        battery.batteryState = makeBatteryState(percentage: 90, isCharging: false)
        manager = ChargingManager(settings: settings, helper: helper, battery: battery, sleepAssertion: MockSleepAssertionControl())
        manager.nativeLimitAvailable = true; manager.isHelperInstalled = true
        manager.helperVersion = "1.6.0"; manager.nativeLEDHardwareAvailable = true
    }
    override func tearDown() async throws {
        settings.defaults.removePersistentDomain(forName: suite)
        manager = nil; battery = nil; helper = nil; settings = nil
    }
    func settle() async { for _ in 0..<10 { await Task.yield() } }
    func testLegacyDefaultDoesNotEnableNativeLED() {
        XCTAssertTrue(settings.controlMagSafeLED)
        XCTAssertFalse(settings.nativeMagSafeLEDEnabled)
        manager.evaluateState(battery.batteryState)
        XCTAssertEqual(helper.calls, [.nativeLimit(90)])
    }
    func testRequestedPauseKeepsChargingColorUntilMeasuredStop() async {
        settings.nativeMagSafeLEDEnabled = true
        battery.batteryState = makeBatteryState(percentage: 90, isCharging: true)
        manager.evaluateState(battery.batteryState)
        XCTAssertTrue(helper.calls.contains(.setMagSafeLED(color: 4)))
        XCTAssertFalse(helper.calls.contains(.setMagSafeLED(color: 3)))
        await settle()
        battery.batteryState = makeBatteryState(percentage: 90, isCharging: false)
        manager.evaluateState(battery.batteryState)
        XCTAssertEqual(helper.calls.last, .setMagSafeLED(color: 3))
    }
    func testPreviewExpiresAndReleasesLEDWithoutChangingChargeSettings() async {
        let start = Date(timeIntervalSince1970: 1000)
        var now = start; manager.nativeNow = { now }
        manager.previewMagSafeLED(.green)
        XCTAssertEqual(helper.calls, [.setMagSafeLED(color: 3)])
        await settle()
        now = start.addingTimeInterval(11)
        manager.evaluateState(battery.batteryState)
        let ledCalls = helper.calls.filter { if case .setMagSafeLED = $0 { return true }; return false }
        XCTAssertEqual(ledCalls.last, .setMagSafeLED(color: 0))
        XCTAssertFalse(manager.magSafeLEDPreviewActive)
        XCTAssertEqual(settings.chargeLimit, 80)
    }
    func testSleepRestoresSystemLEDAndWakeReappliesRule() async {
        settings.nativeMagSafeLEDEnabled = true
        manager.evaluateState(battery.batteryState); await settle()
        manager.handleWillSleep()
        XCTAssertEqual(helper.calls.last, .setMagSafeLED(color: 0))
        await settle()
        manager.handleDidWake(battery.batteryState)
        XCTAssertTrue(helper.calls.suffix(2).contains(.setMagSafeLED(color: 3)))
    }
    func testSystemButtonRequestsAutomaticEvenAfterFailedPreview() async {
        helper.shouldFailLED = true
        manager.previewMagSafeLED(.green); await settle()
        XCTAssertEqual(manager.nativeLEDIssue, "LED mock failure")
        helper.shouldFailLED = false
        manager.useSystemMagSafeLED(); await settle()
        XCTAssertEqual(helper.calls.last, .setMagSafeLED(color: 0))
        XCTAssertNil(manager.nativeLEDIssue)
    }
}
