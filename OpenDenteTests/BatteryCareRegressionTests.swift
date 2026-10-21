import XCTest
@testable import OpenDente

/// Regression coverage for the audited control-flow defects and personal charge profiles.
/// No helper is connected and BatteryService.start() is never called.
@MainActor
final class BatteryCareRegressionTests: XCTestCase {
    private var suiteName: String!
    private var settings: AppSettings!
    private var battery: BatteryService!
    private var helper: MockChargingControl!
    private var manager: ChargingManager!

    override func setUp() {
        super.setUp()
        suiteName = "com.opendente.tests.battery-care.\(UUID().uuidString)"
        settings = AppSettings(defaults: UserDefaults(suiteName: suiteName)!)
        settings.controlMagSafeLED = false
        settings.showNotifications = false
        battery = BatteryService(settings: settings)
        battery.batteryState = makeBatteryState(percentage: 75, temperature: 25)
        helper = MockChargingControl()
        manager = ChargingManager(settings: settings, helper: helper, battery: battery,
                                  sleepAssertion: MockSleepAssertionControl())
        manager.isHelperInstalled = true
        manager.chargingAPI = .tahoe
    }

    override func tearDown() {
        settings.defaults.removePersistentDomain(forName: suiteName)
        manager = nil
        helper = nil
        battery = nil
        settings = nil
        super.tearDown()
    }

    private func evaluate(_ state: BatteryState) {
        battery.batteryState = state
        manager.evaluateState(state)
    }

    private var inhibitCalls: Int {
        helper.calls.filter { $0 == .inhibitCharging }.count
    }

    func testHeatProtectionRetriesWhenHardwareStillChargesWhileHot() {
        let hot = makeBatteryState(percentage: 75, isCharging: true, temperature: 38)
        evaluate(hot)
        XCTAssertEqual(manager.mode, .heatProtection)
        helper.clearCalls()
        manager.lastInhibitTime = Date().addingTimeInterval(-16)

        evaluate(hot)

        XCTAssertEqual(inhibitCalls, 1, "A hot early return must not skip hardware verification")
        XCTAssertEqual(manager.inhibitRetryCount, 1)
    }

    func testHeatProtectionRetriesDuringCooldown() {
        evaluate(makeBatteryState(percentage: 75, isCharging: true, temperature: 38))
        manager.heatProtectionTimer = Date().addingTimeInterval(-30)
        manager.lastInhibitTime = Date().addingTimeInterval(-16)
        helper.clearCalls()

        evaluate(makeBatteryState(percentage: 75, isCharging: true, temperature: 30))

        XCTAssertEqual(manager.mode, .heatProtection)
        XCTAssertEqual(inhibitCalls, 1, "The five-minute cooldown also requires verification")
    }

    func testHeatProtectionDebouncesRetriesBeforeFifteenSeconds() {
        let hot = makeBatteryState(percentage: 75, isCharging: true, temperature: 38)
        evaluate(hot)
        manager.lastInhibitTime = Date().addingTimeInterval(-5)
        helper.clearCalls()

        evaluate(hot)

        XCTAssertEqual(inhibitCalls, 0)
        XCTAssertEqual(manager.inhibitRetryCount, 0)
    }

    func testHeatProtectionReportsExhaustedRetriesWithoutContinuingWrites() {
        let hot = makeBatteryState(percentage: 75, isCharging: true, temperature: 38)
        evaluate(hot)
        manager.inhibitRetryCount = 3
        manager.lastInhibitTime = Date().addingTimeInterval(-16)
        helper.clearCalls()

        evaluate(hot)
        evaluate(hot)

        XCTAssertTrue(manager.didNotifyInhibitExhausted,
                      "Failure feedback must remain reachable in heat protection")
        XCTAssertEqual(inhibitCalls, 0, "Retry exhaustion must bound hardware writes")
    }

    func testHeatProtectionConfirmsStopAndClearsRetryCycle() {
        evaluate(makeBatteryState(percentage: 75, isCharging: true, temperature: 38))
        manager.inhibitRetryCount = 2
        manager.lastInhibitTime = Date().addingTimeInterval(-3)

        evaluate(makeBatteryState(percentage: 75, isCharging: false, temperature: 38))

        XCTAssertEqual(manager.inhibitRetryCount, 0)
        XCTAssertNil(manager.lastInhibitTime)
        XCTAssertNil(manager.firstInhibitTime)
    }

    func testFailedInhibitDoesNotDiscardThermalCooldownOrPendingTopUp() async {
        manager.startTopUp()
        helper.shouldFail = true
        evaluate(makeBatteryState(percentage: 85, isCharging: true, temperature: 38))

        // The real command wrapper dispatches its failure handler to MainActor.
        for _ in 0..<10 { await Task.yield() }

        XCTAssertEqual(manager.mode, .heatProtection,
                       "A failed hardware command must not discard the thermal state")
        XCTAssertTrue(manager.topUpRequested)
        helper.shouldFail = false
        helper.clearCalls()
        manager.heatProtectionTimer = Date().addingTimeInterval(-30)
        evaluate(makeBatteryState(percentage: 85, temperature: 30))
        XCTAssertEqual(manager.mode, .heatProtection)
        XCTAssertFalse(helper.calls.contains(.enableCharging),
                       "Cooling after a failure still requires the complete waiting period")

        manager.heatProtectionTimer = Date().addingTimeInterval(-301)
        evaluate(makeBatteryState(percentage: 85, temperature: 30))
        XCTAssertEqual(manager.mode, .topUp)
        XCTAssertTrue(helper.calls.contains(.enableCharging))
    }

    func testFailedInhibitOutsideThermalPauseStillRunsFailureCallback() async {
        settings.heatProtectionEnabled = false
        helper.shouldFail = true
        evaluate(makeBatteryState(percentage: 90))

        for _ in 0..<10 { await Task.yield() }

        XCTAssertEqual(manager.mode, .idle,
                       "Positive control: the asynchronous failure callback must actually execute")
    }

    func testUnvalidatedHelperReceivesNoMagSafeLEDCommands() {
        manager.isHelperInstalled = false
        manager.helperVersion = HelperConstants.helperVersion
        settings.controlMagSafeLED = true

        evaluate(makeBatteryState(percentage: 90))

        XCTAssertTrue(helper.calls.isEmpty,
                      "LED writes must obey the same helper validation gate as charging writes")
    }

    func testMinimumLimitAndMaximumSailingRangeResumeBeforeBatteryEmpties() {
        settings.chargeLimit = 20
        settings.sailingRange = 25
        XCTAssertEqual(settings.sailingLowerBound, 10)
        evaluate(makeBatteryState(percentage: 20))
        helper.clearCalls()

        evaluate(makeBatteryState(percentage: 9))

        XCTAssertEqual(manager.mode, .charging)
        XCTAssertTrue(helper.calls.contains(.enableCharging))
    }

    func testEveryAllowedLimitAndRangeHasReachablePositiveResumeThreshold() {
        for limit in 20...100 {
            settings.chargeLimit = limit
            for range in 2...25 {
                settings.sailingRange = range
                XCTAssertGreaterThanOrEqual(settings.sailingLowerBound, 10)
                XCTAssertLessThan(settings.sailingLowerBound, limit)
            }
        }
    }

    func testTopUpSurvivesHeatPauseThenResumesAfterCooldown() {
        manager.startTopUp()
        evaluate(makeBatteryState(percentage: 85, isCharging: true, temperature: 38))
        XCTAssertEqual(manager.mode, .heatProtection)
        XCTAssertTrue(manager.topUpRequested)

        manager.heatProtectionTimer = Date().addingTimeInterval(-30)
        evaluate(makeBatteryState(percentage: 85, temperature: 30))
        XCTAssertEqual(manager.mode, .heatProtection)
        XCTAssertTrue(manager.topUpRequested)

        manager.heatProtectionTimer = Date().addingTimeInterval(-301)
        helper.clearCalls()
        evaluate(makeBatteryState(percentage: 85, temperature: 30))

        XCTAssertEqual(manager.mode, .topUp)
        XCTAssertTrue(manager.topUpRequested)
        XCTAssertTrue(helper.calls.contains(.enableCharging))
        XCTAssertEqual(settings.chargeLimit, 80, "A temporary override must preserve the normal limit")
    }

    func testTopUpRemainsRequestedAtOneHundredUntilUnplugged() {
        manager.startTopUp()
        evaluate(makeBatteryState(percentage: 100))
        XCTAssertTrue(manager.topUpRequested)
        XCTAssertEqual(manager.mode, .topUp)

        evaluate(makeBatteryState(percentage: 100, isPluggedIn: false))

        XCTAssertFalse(manager.topUpRequested)
        XCTAssertEqual(manager.mode, .onBattery)
        XCTAssertEqual(settings.chargeLimit, 80)
        evaluate(makeBatteryState(percentage: 99))
        XCTAssertEqual(manager.mode, .paused, "Reconnecting must restore the normal ceiling")
    }

    func testStartingTopUpWhileHotNeverBrieflyEnablesCharging() {
        battery.batteryState = makeBatteryState(percentage: 85, temperature: 38)

        manager.startTopUp()

        XCTAssertEqual(manager.mode, .heatProtection)
        XCTAssertTrue(manager.topUpRequested)
        XCTAssertFalse(helper.calls.contains(.enableCharging))
    }

    func testStartingTopUpDuringCooldownKeepsOriginalThermalPause() {
        evaluate(makeBatteryState(percentage: 75, temperature: 38))
        let cooldown = Date().addingTimeInterval(-30)
        manager.heatProtectionTimer = cooldown
        battery.batteryState = makeBatteryState(percentage: 75, temperature: 30)
        helper.clearCalls()

        manager.startTopUp()

        XCTAssertEqual(manager.mode, .heatProtection)
        XCTAssertTrue(manager.topUpRequested)
        XCTAssertEqual(manager.heatProtectionTimer, cooldown)
        XCTAssertFalse(helper.calls.contains(.enableCharging))
    }

    func testMissingTemperatureCannotReleaseThermalPauseForTopUp() {
        manager.startTopUp()
        evaluate(makeBatteryState(percentage: 85, temperature: 38))
        manager.heatProtectionTimer = Date().addingTimeInterval(-301)
        helper.clearCalls()

        evaluate(makeBatteryState(percentage: 85, temperature: nil))

        XCTAssertEqual(manager.mode, .heatProtection)
        XCTAssertTrue(manager.topUpRequested)
        XCTAssertFalse(helper.calls.contains(.enableCharging))
    }

    func testNonfiniteTemperatureCannotReleaseThermalPause() {
        evaluate(makeBatteryState(percentage: 75, temperature: 38))
        manager.heatProtectionTimer = Date().addingTimeInterval(-301)
        helper.clearCalls()

        for temperature in [Double.nan, Double.infinity, -Double.infinity] {
            evaluate(makeBatteryState(percentage: 75, temperature: temperature))
            XCTAssertEqual(manager.mode, .heatProtection)
        }
        XCTAssertFalse(helper.calls.contains(.enableCharging))
    }

    func testStartingDischargeClearsTopUpIntent() {
        manager.startTopUp()
        manager.startDischarge()
        XCTAssertFalse(manager.topUpRequested)
        XCTAssertEqual(manager.mode, .discharging)
    }

    func testUnpluggingDuringHeatPauseCancelsTopUp() {
        manager.startTopUp()
        evaluate(makeBatteryState(percentage: 85, temperature: 38))

        evaluate(makeBatteryState(percentage: 85, isPluggedIn: false, temperature: 38))

        XCTAssertFalse(manager.topUpRequested)
        XCTAssertEqual(manager.mode, .onBattery)
    }

    func testCancelTopUpDuringHeatPausePreventsLaterResumeToOneHundred() {
        manager.startTopUp()
        evaluate(makeBatteryState(percentage: 85, temperature: 38))

        manager.cancelTopUp()

        XCTAssertFalse(manager.topUpRequested)
        manager.heatProtectionTimer = Date().addingTimeInterval(-301)
        evaluate(makeBatteryState(percentage: 85, temperature: 30))
        XCTAssertEqual(manager.mode, .paused)
        XCTAssertEqual(settings.chargeLimit, 80)
    }

    func testResetClearsTemporaryTopUpIntent() {
        manager.startTopUp()
        manager.resetToDefaults()
        XCTAssertFalse(manager.topUpRequested)
        XCTAssertEqual(manager.mode, .idle)
        XCTAssertTrue(helper.calls.contains(.resetToDefaults))
    }

    func testTerminationResetClearsTemporaryTopUpIntent() {
        manager.startTopUp()
        manager.resetToDefaultsSync()
        XCTAssertFalse(manager.topUpRequested)
        XCTAssertEqual(manager.mode, .idle)
    }

    func testUnavailableHardwareCannotCreateTopUpIntent() {
        manager.isHelperInstalled = false
        manager.startTopUp()
        XCTAssertFalse(manager.topUpRequested)
        XCTAssertTrue(helper.calls.isEmpty)
    }

    func testProfilesConfigureNaturalSailingWithoutForcedDischarge() {
        let expected: [(ChargeProfile, Int, Int)] = [
            (.desk, 70, 60), (.everyday, 80, 70), (.travel, 90, 80)
        ]
        for (profile, limit, resumeAt) in expected {
            settings.automaticDischarge = true
            settings.heatProtectionEnabled = false
            settings.sailingModeEnabled = false

            settings.apply(profile: profile)

            XCTAssertEqual(settings.chargeLimit, limit)
            XCTAssertEqual(settings.sailingLowerBound, resumeAt)
            XCTAssertEqual(profile.chargeLimit, limit)
            XCTAssertEqual(profile.resumeAt, resumeAt)
            XCTAssertTrue(settings.sailingModeEnabled)
            XCTAssertTrue(settings.heatProtectionEnabled)
            XCTAssertFalse(settings.automaticDischarge)
            XCTAssertEqual(settings.selectedProfile, profile)
        }
    }

    func testCustomCeilingDoesNotPretendToMatchPreset() {
        settings.apply(profile: .everyday)
        settings.chargeLimit = 83
        XCTAssertNil(settings.selectedProfile)
    }

    func testCustomSailingRangeDoesNotPretendToMatchPreset() {
        settings.apply(profile: .everyday)
        settings.sailingRange = 5
        XCTAssertNil(settings.selectedProfile)
    }

    func testApplyingProfileDoesNotStartForcedDischargeAboveCeiling() {
        settings.apply(profile: .desk)
        evaluate(makeBatteryState(percentage: 95))
        XCTAssertEqual(manager.mode, .paused)
        XCTAssertFalse(helper.calls.contains(.forceDischarge(enable: true)))
    }
}
