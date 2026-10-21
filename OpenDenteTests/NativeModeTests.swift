import XCTest
@testable import OpenDente

@MainActor
final class NativeModeTests: XCTestCase {
    private var suite: String!
    private var settings: AppSettings!
    private var helper: MockChargingControl!
    private var battery: BatteryService!
    private var manager: ChargingManager!
    override func setUp() async throws {
        try await super.setUp()
        suite = "com.opendente.tests.native.\(UUID().uuidString)"
        settings = AppSettings(defaults: UserDefaults(suiteName: suite)!)
        settings.chargeLimit = 80
        settings.showNotifications = false
        battery = BatteryService(settings: settings)
        battery.batteryState = makeBatteryState(percentage: 50, isCharging: true)
        helper = MockChargingControl()
        manager = ChargingManager(settings: settings, helper: helper, battery: battery,
                                  sleepAssertion: MockSleepAssertionControl())
        manager.nativeLimitAvailable = true
        manager.isHelperInstalled = true
    }
    override func tearDown() async throws {
        settings.defaults.removePersistentDomain(forName: suite)
        manager = nil; helper = nil; battery = nil; settings = nil
        try await super.tearDown()
    }
    func testOptInIsRequiredAndLegacyControlsRemainUnavailable() {
        manager.evaluateState(battery.batteryState)
        manager.startTopUp()
        manager.startDischarge()
        manager.pauseCharging()
        XCTAssertFalse(manager.chargeControlAvailable)
        XCTAssertTrue(helper.calls.isEmpty)
    }
    func testNativeCeilingDoesNotCallSMCLEDOrInhibit() {
        settings.nativeChargeLimitEnabled = true
        manager.evaluateState(battery.batteryState)
        XCTAssertEqual(helper.calls, [.nativeLimit(80)])
        XCTAssertTrue(manager.chargeControlAvailable)
        XCTAssertEqual(manager.mode, .charging)
    }
    func testLowerProfileHoldsCurrentLevelWithoutForcedDrain() {
        settings.nativeChargeLimitEnabled = true
        settings.chargeLimit = 70
        battery.batteryState = makeBatteryState(percentage: 95, isCharging: false)
        manager.evaluateState(battery.batteryState)
        XCTAssertEqual(helper.calls, [.nativeLimit(95)])
    }
    func testThermalThresholdDoesNotClaimNativeThermalInhibition() {
        settings.nativeChargeLimitEnabled = true
        settings.heatProtectionEnabled = true
        manager.evaluateState(makeBatteryState(percentage: 50, isCharging: true, temperature: 45))
        XCTAssertEqual(helper.calls, [.nativeLimit(80)])
        XCTAssertNotEqual(manager.mode, .heatProtection)
    }
    func testTopUpRestoresUsualTargetAtUnplugWithoutChangingSettings() async {
        settings.nativeChargeLimitEnabled = true
        manager.startTopUp()
        XCTAssertTrue(manager.topUpRequested)
        XCTAssertEqual(helper.calls, [.nativeLimit(100)])
        XCTAssertEqual(settings.chargeLimit, 80)
        await Task.yield()
        manager.evaluateState(makeBatteryState(percentage: 60, isPluggedIn: false))
        XCTAssertFalse(manager.topUpRequested)
        XCTAssertEqual(manager.mode, .onBattery)
    }
    func testDisablingModeRequestsOriginalSettingsRestoration() async {
        settings.nativeChargeLimitEnabled = true
        manager.evaluateState(battery.batteryState)
        await Task.yield()
        settings.nativeChargeLimitEnabled = false
        manager.releaseNativeLimitIfDisabled()
        XCTAssertEqual(helper.calls, [.nativeLimit(80), .resetToDefaults])
    }
    func testRepeatedPollDoesNotSpamAgent() async {
        settings.nativeChargeLimitEnabled = true
        manager.evaluateState(battery.batteryState)
        await Task.yield()
        manager.evaluateState(battery.batteryState)
        XCTAssertEqual(helper.calls, [.nativeLimit(80)])
    }
}
