import Foundation

enum MagSafeLEDChoice: Int, CaseIterable, Identifiable {
    case system = 0, off = 1, green = 3, orange = 4
    var id: Int { rawValue }
    var byte: UInt8 { UInt8(rawValue) }
    var title: String {
        switch self {
        case .system: "Automatique macOS"
        case .off: "Éteint"
        case .green: "Vert"
        case .orange: "Orange"
        }
    }
}
