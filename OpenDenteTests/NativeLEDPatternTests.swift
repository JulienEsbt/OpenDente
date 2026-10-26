import XCTest
@testable import OpenDente

extension NativeLEDTests {
    func testPatternsUseOnlyKnownCommandsAndNeverErrorSignals() {
        let t = Date(timeIntervalSince1970: 1000)
        XCTAssertEqual(MagSafeLEDChoice.pulsingGreen.output(at: t), 3)
        XCTAssertEqual(MagSafeLEDChoice.pulsingGreen.output(at: t.addingTimeInterval(2)), 1)
        XCTAssertEqual(MagSafeLEDChoice.pulsingOrange.output(at: t), 4)
        XCTAssertEqual(MagSafeLEDChoice.pulsingOrange.output(at: t.addingTimeInterval(2)), 1)
        XCTAssertEqual(MagSafeLEDChoice.alternating.output(at: t), 3)
        XCTAssertEqual(MagSafeLEDChoice.alternating.output(at: t.addingTimeInterval(2)), 4)
        for choice in MagSafeLEDChoice.allCases {
            for second in 0..<12 {
                XCTAssertTrue([UInt8(0),1,3,4].contains(choice.output(at: t.addingTimeInterval(Double(second)))))
            }
        }
    }
    func testPausePulsesOnExistingPollWithoutChangingChargeTargets() async {
        settings.applyDistinctLEDSignals()
        var now = Date(timeIntervalSince1970: 1000)
        manager.nativeNow = { now }
        manager.evaluateState(battery.batteryState); await settle()
        XCTAssertTrue(helper.calls.contains(.setMagSafeLED(color: 3)))
        helper.clearCalls(); now = now.addingTimeInterval(2)
        manager.evaluateState(battery.batteryState); await settle()
        XCTAssertEqual(helper.calls, [.setMagSafeLED(color: 1)])
        helper.clearCalls(); now = now.addingTimeInterval(2)
        manager.evaluateState(battery.batteryState); await settle()
        XCTAssertEqual(helper.calls, [.setMagSafeLED(color: 3)])
        XCTAssertEqual(settings.chargeLimit, 80)
    }
    func testTopUpAndCompletedHundredHaveDistinctFixedSignals() async {
        settings.applyDistinctLEDSignals()
        battery.batteryState = makeBatteryState(percentage: 90, isCharging: true)
        manager.startTopUp(); await settle()
        XCTAssertTrue(helper.calls.contains(.setMagSafeLED(color: 4)))
        helper.clearCalls()
        battery.batteryState = makeBatteryState(percentage: 100, isCharging: false)
        manager.evaluateState(battery.batteryState); await settle()
        XCTAssertTrue(helper.calls.contains(.setMagSafeLED(color: 3)))
        XCTAssertTrue(manager.topUpRequested)
    }
    func testSleepStopsPatternAndWakeRestartsWithoutResettingCeiling() async {
        settings.applyDistinctLEDSignals()
        manager.nativeNow = { Date(timeIntervalSince1970: 1000) }
        manager.evaluateState(battery.batteryState); await settle()
        helper.clearCalls()
        manager.handleWillSleep(); await settle()
        XCTAssertEqual(helper.calls, [.setMagSafeLED(color: 0)])
        helper.clearCalls()
        manager.handleDidWake(battery.batteryState); await settle()
        XCTAssertTrue(helper.calls.contains(.setMagSafeLED(color: 3)))
        XCTAssertFalse(helper.calls.contains(.resetToDefaults))
    }
    func testPreviewCanUsePatternAndExpiryReturnsToChosenRule() async {
        var now = Date(timeIntervalSince1970: 1000)
        manager.nativeNow = { now }
        manager.previewMagSafeLED(.pulsingOrange); await settle()
        XCTAssertEqual(helper.calls, [.setMagSafeLED(color: 4)])
        helper.clearCalls(); now = now.addingTimeInterval(2)
        manager.evaluateState(battery.batteryState); await settle()
        XCTAssertTrue(helper.calls.contains(.setMagSafeLED(color: 1)))
        now = now.addingTimeInterval(10)
        manager.evaluateState(battery.batteryState); await settle()
        XCTAssertFalse(manager.magSafeLEDPreviewActive)
        XCTAssertEqual(helper.calls.last, .setMagSafeLED(color: 0))
    }
}
