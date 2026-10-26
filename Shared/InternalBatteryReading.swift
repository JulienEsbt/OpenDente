import Foundation

/// IOPS can also list UPS devices. Only the Mac's internal battery may authorize
/// a native ceiling; another device's level must never bypass the no-drain guard.
struct InternalBatteryReading {
    let description: [String: Any]
    let percentage: Int

    static func read(_ descriptions: [[String: Any]]) throws -> Self {
        let internalBatteries = descriptions.filter { $0["Type"] as? String == "InternalBattery" }
        guard internalBatteries.count == 1, let description = internalBatteries.first,
              let current = description["Current Capacity"] as? Int,
              let maximum = description["Max Capacity"] as? Int,
              maximum > 0, current >= 0, current <= maximum else {
            throw NativeLimitSession.Failure(message: "Internal battery reading unavailable or ambiguous")
        }
        return Self(description: description,
                    percentage: Int(ceil(Double(current) * 100 / Double(maximum))))
    }
}
