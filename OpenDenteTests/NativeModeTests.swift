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
    func testThermalThresholdRequestsNativeHoldWithoutSMC() {
        settings.nativeChargeLimitEnabled = true
        settings.heatProtectionEnabled = true
        manager.evaluateState(makeBatteryState(percentage: 50, isCharging: true, temperature: 45))
        XCTAssertEqual(helper.calls, [.nativeLimit(50)])
        XCTAssertEqual(manager.mode, .heatProtection)
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
    func testNativeFailureIsVisibleWithoutCallingLegacyChargingControls() async {
        settings.nativeChargeLimitEnabled = true
        helper.shouldFail = true
        manager.evaluateState(battery.batteryState)
        for _ in 0..<10 { await Task.yield() }
        XCTAssertNil(manager.nativeLimitTarget)
        XCTAssertEqual(manager.nativeLimitIssue, "native mock failure")
        XCTAssertEqual(helper.calls, [.nativeLimit(80)])
    }

    func testNativeSleepAndWakeNeverUseLegacyInhibitOrLEDCommands() async {
        settings.nativeChargeLimitEnabled = true
        settings.stopChargingWhenSleeping = true
        manager.evaluateState(battery.batteryState)
        for _ in 0..<10 { await Task.yield() }
        manager.handleWillSleep()
        manager.handleDidWake(battery.batteryState)
        XCTAssertTrue(helper.calls.allSatisfy { if case .nativeLimit = $0 { return true }; return false })
    }

    func testNativeChargeCanPreventIdleSleepAndReleasesItWhenDisabled() async {
        let sleep = MockSleepAssertionControl()
        manager = ChargingManager(settings: settings, helper: helper, battery: battery, sleepAssertion: sleep)
        manager.nativeLimitAvailable = true
        manager.isHelperInstalled = true
        settings.nativeChargeLimitEnabled = true
        settings.disableSleepUntilChargeLimit = true
        manager.evaluateState(battery.batteryState)
        XCTAssertTrue(sleep.isPreventingSleep)
        for _ in 0..<10 { await Task.yield() }
        settings.nativeChargeLimitEnabled = false
        manager.releaseNativeLimitIfDisabled()
        XCTAssertFalse(sleep.isPreventingSleep)
    }

    func testThermalHoldRequestRetainsTopUpAndSurfacesAnUnconfirmedPhysicalStop() async {
        settings.nativeChargeLimitEnabled = true
        settings.heatProtectionTemp = 40
        var clock = Date(timeIntervalSince1970: 1000)
        manager.nativeNow = { clock }
        battery.batteryState = makeBatteryState(percentage: 50, isCharging: true, temperature: 41)
        manager.startTopUp()
        XCTAssertTrue(manager.topUpRequested)
        XCTAssertEqual(manager.mode, .heatProtection)
        XCTAssertEqual(helper.calls, [.nativeLimit(50)])
        for _ in 0..<10 { await Task.yield() }
        clock = clock.addingTimeInterval(91)
        manager.evaluateState(battery.batteryState)
        XCTAssertNotNil(manager.nativePauseWarning)
        XCTAssertEqual(manager.mode, .heatProtection)
        manager.cancelTopUp()
        XCTAssertFalse(manager.topUpRequested)
        XCTAssertEqual(manager.mode, .heatProtection)
    }

    func testDisablingNativeModeRestoresEvenWhenBatteryReadingIsLost() async {
        settings.nativeChargeLimitEnabled = true
        manager.evaluateState(battery.batteryState)
        for _ in 0..<10 { await Task.yield() }
        battery.batteryState = .unknown
        settings.nativeChargeLimitEnabled = false
        manager.releaseNativeLimitIfDisabled()
        XCTAssertEqual(helper.calls, [.nativeLimit(80), .resetToDefaults])
    }

}


extension NativeModeTests {
    func testStorageKeepsUsualSettingsAndUsesDedicatedCommand() async {
        battery.batteryState = makeBatteryState(percentage: 98, isCharging: false)
        manager.startStoragePreparation()
        XCTAssertTrue(manager.isPreparingStorage)
        XCTAssertEqual(settings.chargeLimit, 80); XCTAssertEqual(settings.sailingLowerBound, 70)
        XCTAssertEqual(manager.activeChargeLimit, 50)
        XCTAssertEqual(helper.calls, [.prepareStorage])
        for _ in 0..<10 { await Task.yield() }
        manager.cancelStoragePreparation()
        XCTAssertFalse(manager.isPreparingStorage)
        XCTAssertEqual(helper.calls.last, .nativeLimit(98))
        XCTAssertEqual(settings.chargeLimit, 80)
    }
    func testTopUpAndDailyProfileLeaveStorageMode() async {
        battery.batteryState = makeBatteryState(percentage: 90)
        manager.startStoragePreparation()
        for _ in 0..<10 { await Task.yield() }
        manager.startTopUp()
        XCTAssertFalse(settings.storagePreparationEnabled)
        XCTAssertTrue(manager.topUpRequested)
        XCTAssertEqual(helper.calls.last, .nativeLimit(100))
        settings.storagePreparationEnabled = true
        settings.apply(profile: .everyday)
        XCTAssertFalse(settings.storagePreparationEnabled)
    }
    func testStorageCannotStartWithoutAuthenticatedHelperAndDisablingControlCancelsIt() async {
        manager.isHelperInstalled = false
        manager.startStoragePreparation()
        XCTAssertFalse(settings.storagePreparationEnabled)
        manager.isHelperInstalled = true
        manager.startStoragePreparation()
        for _ in 0..<10 { await Task.yield() }
        settings.nativeChargeLimitEnabled = false
        manager.releaseNativeLimitIfDisabled()
        XCTAssertFalse(settings.storagePreparationEnabled)
        XCTAssertEqual(helper.calls.last, .resetToDefaults)
    }
}


extension NativeModeTests {
    func testStorageAndTopUpActionsCannotEraseThermalCooldown() async {
        let start = Date(timeIntervalSince1970: 1000)
        var now = start
        manager.nativeNow = { now }
        settings.nativeChargeLimitEnabled = true
        settings.heatProtectionEnabled = true
        battery.batteryState = makeBatteryState(percentage: 90, temperature: 45)
        manager.evaluateState(battery.batteryState)
        for _ in 0..<10 { await Task.yield() }
        now = start.addingTimeInterval(60)
        battery.batteryState = makeBatteryState(percentage: 90, temperature: 39)
        manager.startStoragePreparation()
        XCTAssertEqual(manager.mode, .heatProtection)
        XCTAssertFalse(helper.calls.contains(.prepareStorage))
        for _ in 0..<10 { await Task.yield() }
        manager.cancelStoragePreparation()
        XCTAssertEqual(manager.mode, .heatProtection)
        for _ in 0..<10 { await Task.yield() }
        manager.startTopUp()
        XCTAssertEqual(manager.mode, .heatProtection)
        XCTAssertTrue(manager.topUpRequested)
    }
}

extension NativeModeTests {
    func testPersistentReturnToCapWorksOnFirstEvaluationAndCanBeStopped() async {
        settings.nativeChargeLimitEnabled = true
        settings.nativeReturnToLimitEnabled = true
        XCTAssertTrue(AppSettings(defaults: settings.defaults).nativeReturnToLimitEnabled)
        battery.batteryState = makeBatteryState(percentage: 93, isCharging: false)
        manager.evaluateState(battery.batteryState)
        XCTAssertEqual(helper.calls, [.dischargeToLimit(80)])
        XCTAssertEqual(manager.mode, .discharging)
        for _ in 0..<10 { await Task.yield() }
        manager.stopDischarge()
        XCTAssertFalse(settings.nativeReturnToLimitEnabled)
        XCTAssertEqual(helper.calls.last, .nativeLimit(93))
        XCTAssertEqual(settings.chargeLimit, 80)
    }
    func testNativeSleepPreservesCeilingAndWakeResendsWithoutResettingToFull() async {
        settings.nativeChargeLimitEnabled = true
        settings.nativeReturnToLimitEnabled = true
        battery.batteryState = makeBatteryState(percentage: 93, isCharging: false)
        manager.evaluateState(battery.batteryState)
        for _ in 0..<10 { await Task.yield() }
        XCTAssertEqual(manager.nativeLimitTarget, 80)
        helper.clearCalls()
        manager.handleWillSleep()
        XCTAssertTrue(helper.calls.isEmpty)
        XCTAssertEqual(manager.nativeLimitTarget, 80)
        manager.handleDidWake(battery.batteryState)
        XCTAssertEqual(helper.calls, [.dischargeToLimit(80)])
        XCTAssertFalse(helper.calls.contains(.nativeLimit(100)))
        XCTAssertFalse(helper.calls.contains(.resetToDefaults))
    }
    func testTopUpCanOverrideReturnThenCancelResumesReturn() async {
        settings.nativeChargeLimitEnabled = true
        settings.nativeReturnToLimitEnabled = true
        battery.batteryState = makeBatteryState(percentage: 93, isCharging: false)
        manager.evaluateState(battery.batteryState)
        for _ in 0..<10 { await Task.yield() }
        manager.startTopUp()
        XCTAssertEqual(helper.calls.last, .nativeLimit(100))
        for _ in 0..<10 { await Task.yield() }
        manager.cancelTopUp()
        XCTAssertEqual(helper.calls.last, .dischargeToLimit(80))
        XCTAssertTrue(settings.nativeReturnToLimitEnabled)
    }
}
