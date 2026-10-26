import Foundation

/// App patterns, never raw SMC commands. Animation reuses the existing 2 s poll.
enum MagSafeLEDChoice: Int, CaseIterable, Identifiable {
    case system = 0, off = 1, green = 3, orange = 4
    case pulsingGreen = 103, pulsingOrange = 104, alternating = 105
    var id: Int { rawValue }
    var byte: UInt8 {
        switch self {
        case .pulsingGreen, .alternating: 3
        case .pulsingOrange: 4
        default: UInt8(rawValue)
        }
    }
    func output(at date: Date) -> UInt8 {
        let firstPhase = Int(floor(date.timeIntervalSince1970 / 2)) & 1 == 0
        switch self {
        case .pulsingGreen: return firstPhase ? 3 : 1
        case .pulsingOrange: return firstPhase ? 4 : 1
        case .alternating: return firstPhase ? 3 : 4
        default: return byte
        }
    }
    var title: String {
        switch self {
        case .system: String(localized: "Automatique macOS", bundle: L10n.bundle)
        case .off: String(localized: "Éteint", bundle: L10n.bundle)
        case .green: String(localized: "Vert fixe", bundle: L10n.bundle)
        case .orange: String(localized: "Orange fixe", bundle: L10n.bundle)
        case .pulsingGreen: String(localized: "Vert clignotant lent", bundle: L10n.bundle)
        case .pulsingOrange: String(localized: "Orange clignotant lent", bundle: L10n.bundle)
        case .alternating: String(localized: "Alternance vert / orange", bundle: L10n.bundle)
        }
    }
}
