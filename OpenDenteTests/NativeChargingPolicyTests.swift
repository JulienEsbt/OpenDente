import XCTest
@testable import OpenDente

@MainActor
final class NativeChargingPolicyTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1000)

    private func step(_ policy: inout NativeChargingPolicy, level: Int, temperature: Double? = 25,
                      time: Double = 0, plugged: Bool = true, limit: Int = 80,
                      resume: Int? = 70, heat: Double? = 40, topUp: Bool = false) -> NativeChargingPolicy.Decision {
        policy.evaluate(makeBatteryState(percentage: level, isCharging: true,
            isPluggedIn: plugged, temperature: temperature), limit: limit,
            resumeAt: resume, heatLimit: heat, topUp: topUp, now: start.addingTimeInterval(time))
    }

    func testWaitsInBandAtStartupAndReleasesOnlyBelowResumeThreshold() {
        var policy = NativeChargingPolicy()
        XCTAssertEqual(step(&policy, level: 75), .init(mode: .sailing, target: 75))
        XCTAssertEqual(step(&policy, level: 70), .init(mode: .sailing, target: 70))
        XCTAssertEqual(step(&policy, level: 69), .init(mode: .charging, target: 80))
        XCTAssertEqual(step(&policy, level: 75), .init(mode: .charging, target: 80))
        XCTAssertEqual(step(&policy, level: 80), .init(mode: .paused, target: 80))
        XCTAssertEqual(step(&policy, level: 74), .init(mode: .sailing, target: 74))
    }

    func testUserCanWaitFor20WithoutForcingDischargeOrCuttingTheAdapter() {
        var policy = NativeChargingPolicy()
        for level in stride(from: 80, through: 20, by: -1) {
            let result = step(&policy, level: level, resume: 20)
            XCTAssertEqual(result.target, level)
            XCTAssertNotEqual(result.mode, .charging)
        }
        XCTAssertEqual(step(&policy, level: 19, resume: 20), .init(mode: .charging, target: 80))
        XCTAssertEqual(step(&policy, level: 79, resume: 20), .init(mode: .charging, target: 80))
    }

    func testHoldingFollowsBothChargingLagAndNaturalDownwardDrift() {
        var policy = NativeChargingPolicy()
        XCTAssertEqual(step(&policy, level: 81).target, 81)
        XCTAssertEqual(step(&policy, level: 82).target, 82)
        XCTAssertEqual(step(&policy, level: 79).target, 79)
    }

    func testLoweringUsualLimitDoesNotRequestDrain() {
        var policy = NativeChargingPolicy()
        XCTAssertEqual(step(&policy, level: 95, limit: 70), .init(mode: .paused, target: 95))
    }

    func testThermalPauseHasPriorityOverTopUpAndWaitsForCoolingAndTime() {
        var policy = NativeChargingPolicy()
        XCTAssertEqual(step(&policy, level: 50, temperature: 40, topUp: true), .init(mode: .heatProtection, target: 50))
        XCTAssertEqual(step(&policy, level: 51, temperature: 38, time: 299, topUp: true).mode, .heatProtection)
        XCTAssertEqual(step(&policy, level: 51, temperature: 39, time: 301, topUp: true).mode, .heatProtection)
        XCTAssertEqual(step(&policy, level: 51, temperature: 38, time: 301, topUp: true), .init(mode: .topUp, target: 100))
    }

    func testMissingOrInvalidTemperatureCannotEndThermalPause() {
        var policy = NativeChargingPolicy()
        _ = step(&policy, level: 50, temperature: 42)
        for temperature: Double? in [nil, .nan, .infinity] {
            XCTAssertEqual(step(&policy, level: 50, temperature: temperature, time: 900).mode, .heatProtection)
        }
    }

    func testNewTemperatureSpikeRestartsCooldown() {
        var policy = NativeChargingPolicy()
        _ = step(&policy, level: 50, temperature: 41)
        _ = step(&policy, level: 50, temperature: 41, time: 290)
        XCTAssertEqual(step(&policy, level: 50, temperature: 30, time: 301).mode, .heatProtection)
        XCTAssertEqual(step(&policy, level: 50, temperature: 30, time: 590).mode, .charging)
    }

    func testDisablingThermalPauseClearsItsState() {
        var policy = NativeChargingPolicy()
        _ = step(&policy, level: 50, temperature: 41)
        XCTAssertEqual(step(&policy, level: 50, temperature: 41, heat: nil).mode, .charging)
        XCTAssertFalse(policy.thermalPause)
    }

    func testUnpluggingClearsChargeCycleAndPreparesHoldWithinBand() {
        var policy = NativeChargingPolicy()
        _ = step(&policy, level: 60)
        XCTAssertEqual(step(&policy, level: 75, plugged: false), .init(mode: .onBattery, target: 75))
        XCTAssertFalse(policy.chargingToLimit)
        XCTAssertEqual(step(&policy, level: 75), .init(mode: .sailing, target: 75))
    }

    func testSimpleCeilingWithoutHysteresisKeepsChargingBelowLimit() {
        var policy = NativeChargingPolicy()
        XCTAssertEqual(step(&policy, level: 79, resume: nil), .init(mode: .charging, target: 80))
    }

    func testNoNormalOrThermalTargetIsBelowTheObservedBatteryLevel() {
        for level in 0...100 {
            for limit in stride(from: 20, through: 100, by: 5) {
                for temperature in [25.0, 45.0] {
                    var policy = NativeChargingPolicy()
                    let result = step(&policy, level: level, temperature: temperature, limit: limit)
                    XCTAssertGreaterThanOrEqual(result.target, level)
                    XCTAssertTrue((20...100).contains(result.target))
                    XCTAssertNotEqual(result.mode, .discharging)
                }
            }
        }
    }
}


extension NativeChargingPolicyTests {
    func testExplicitStorageRequestsDrainToFiftyWithoutChangingUsualPolicy() {
        var policy = NativeChargingPolicy()
        let decision = policy.evaluate(makeBatteryState(percentage: 98, isCharging: false), limit: 80,
            resumeAt: 70, heatLimit: 40, topUp: false, now: Date(), storage: true)
        XCTAssertEqual(decision.mode, .discharging)
        XCTAssertEqual(decision.target, 50)
        XCTAssertTrue(decision.allowsStorageDrain)
        let usual = policy.evaluate(makeBatteryState(percentage: 98, isCharging: false), limit: 80,
            resumeAt: 70, heatLimit: 40, topUp: false, now: Date())
        XCTAssertEqual(usual.target, 98)
        XCTAssertFalse(usual.allowsStorageDrain)
    }
    func testStorageStopsDrainAtFiftyAndChargesIfBelow() {
        var policy = NativeChargingPolicy()
        for (level, mode) in [(50, ChargingMode.paused), (45, .charging)] {
            let d = policy.evaluate(makeBatteryState(percentage: level), limit: 80, resumeAt: 70,
                heatLimit: 40, topUp: false, now: Date(), storage: true)
            XCTAssertEqual(d.target, 50); XCTAssertEqual(d.mode, mode); XCTAssertFalse(d.allowsStorageDrain)
        }
    }
    func testStorageNeverForcesDrainWhileHotOrUnplugged() {
        var policy = NativeChargingPolicy()
        let hot = policy.evaluate(makeBatteryState(percentage: 90, temperature: 45), limit: 80,
            resumeAt: 70, heatLimit: 40, topUp: false, now: Date(), storage: true)
        XCTAssertEqual(hot.mode, .heatProtection); XCTAssertEqual(hot.target, 90)
        XCTAssertFalse(hot.allowsStorageDrain)
        let unplugged = policy.evaluate(makeBatteryState(percentage: 90, isPluggedIn: false), limit: 80,
            resumeAt: 70, heatLimit: 40, topUp: false, now: Date(), storage: true)
        XCTAssertEqual(unplugged.mode, .onBattery); XCTAssertEqual(unplugged.target, 90)
        XCTAssertFalse(unplugged.allowsStorageDrain)
    }
}
