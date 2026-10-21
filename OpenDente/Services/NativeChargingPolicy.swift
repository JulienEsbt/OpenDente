import Foundation

/// Charge intents only. PowerUI acknowledgement is never proof of a physical stop.
/// Holding follows the latest level, including natural dips, rather than asking
/// the firmware to drain to the saved upper limit. The helper checks a fresh read.
struct NativeChargingPolicy {
    private(set) var chargingToLimit = false
    private(set) var thermalPause = false
    private(set) var lastHotDate: Date?

    mutating func resetChargingCycle() { chargingToLimit = false }

    struct Decision: Equatable {
        let mode: ChargingMode
        let target: Int
        var allowsStorageDrain = false
        var allowsLimitDrain = false
    }

    mutating func evaluate(_ state: BatteryState, limit: Int, resumeAt: Int?,
                           heatLimit: Double?, topUp: Bool, now: Date, storage: Bool = false, returnToLimit: Bool = false) -> Decision {
        let level = state.percentage
        guard state.isPluggedIn else {
            chargingToLimit = false
            thermalPause = false
            lastHotDate = nil
            let waitingInBand = resumeAt.map { level >= $0 } ?? false
            return Decision(mode: .onBattery, target: storage ? max(50, level) : max(20, level, waitingInBand ? level : limit))
        }
        if let threshold = heatLimit {
            if let temperature = state.temperature, temperature.isFinite {
                if temperature >= threshold {
                    thermalPause = true
                    lastHotDate = now
                } else if thermalPause, temperature <= threshold - 2,
                          let lastHotDate, now.timeIntervalSince(lastHotDate) >= 300 {
                    thermalPause = false
                    self.lastHotDate = nil
                }
            }
            // A missing reading cannot end a thermal pause.
        } else {
            thermalPause = false
            lastHotDate = nil
        }
        if thermalPause { return Decision(mode: .heatProtection, target: max(20, level)) }
        if topUp { return Decision(mode: .topUp, target: 100) }
        if storage {
            chargingToLimit = false
            return Decision(mode: level > 50 ? .discharging : (level < 50 ? .charging : .paused),
                            target: 50, allowsStorageDrain: level > 50)
        }
        if returnToLimit && level > limit {
            chargingToLimit = false
            return Decision(mode: .discharging, target: limit, allowsLimitDrain: true)
        }
        if level >= limit { chargingToLimit = false }
        else if resumeAt == nil || level < resumeAt! { chargingToLimit = true }
        if chargingToLimit { return Decision(mode: .charging, target: max(level, limit)) }
        return Decision(mode: level >= limit ? .paused : .sailing, target: max(20, level))
    }
}
