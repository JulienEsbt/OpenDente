import XCTest
@testable import OpenDente

@MainActor
final class NativeReturnToLimitTests: XCTestCase {
    func testOptInReturnsToUpperLimitThenHoldsWithoutForcedCycles() {
        var policy = NativeChargingPolicy()
        func step(_ level: Int) -> NativeChargingPolicy.Decision {
            policy.evaluate(makeBatteryState(percentage: level, isCharging: false), limit: 80,
                resumeAt: 70, heatLimit: 40, topUp: false, now: Date(), returnToLimit: true)
        }
        let first = step(93)
        XCTAssertEqual(first.mode, .discharging)
        XCTAssertEqual(first.target, 80)
        XCTAssertTrue(first.allowsLimitDrain)
        XCTAssertEqual(step(80).mode, .paused)
        XCTAssertEqual(step(79).mode, .sailing)
        XCTAssertFalse(step(75).allowsLimitDrain)
        XCTAssertEqual(step(69).mode, .charging)
        XCTAssertEqual(step(75).mode, .charging)
        XCTAssertEqual(step(80).mode, .paused)
    }
    func testTopUpThermalAndStorageHavePriorityOverReturnToLimit() {
        var p = NativeChargingPolicy()
        let s = makeBatteryState(percentage: 93, isCharging: false)
        let top = p.evaluate(s, limit: 80, resumeAt: 70, heatLimit: 40, topUp: true, now: Date(), returnToLimit: true)
        XCTAssertEqual(top.target, 100); XCTAssertFalse(top.allowsLimitDrain)
        let storage = p.evaluate(s, limit: 80, resumeAt: 70, heatLimit: 40, topUp: false, now: Date(), storage: true, returnToLimit: true)
        XCTAssertEqual(storage.target, 50); XCTAssertTrue(storage.allowsStorageDrain)
        let hot = p.evaluate(makeBatteryState(percentage: 93, temperature: 45), limit: 80,
            resumeAt: 70, heatLimit: 40, topUp: false, now: Date(), returnToLimit: true)
        XCTAssertEqual(hot.mode, .heatProtection); XCTAssertEqual(hot.target, 93)
        XCTAssertFalse(hot.allowsLimitDrain)
    }
    func testNoDrainWhileUnpluggedAndLegacyDefaultRemainsOptIn() {
        var p = NativeChargingPolicy()
        let state = makeBatteryState(percentage: 93, isPluggedIn: false)
        let decision = p.evaluate(state, limit: 80, resumeAt: 70, heatLimit: 40,
            topUp: false, now: Date(), returnToLimit: true)
        XCTAssertEqual(decision.mode, .onBattery)
        XCTAssertFalse(decision.allowsLimitDrain)
        XCTAssertEqual(p.evaluate(makeBatteryState(percentage: 93), limit: 80, resumeAt: 70,
            heatLimit: 40, topUp: false, now: Date()).target, 93)
    }
}
