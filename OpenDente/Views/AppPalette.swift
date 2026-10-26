import SwiftUI

/// Asset colors supply readable light/dark variants; labels never depend on hue alone.
enum AppPalette {
    static let accent = Color("BatteryAccent")
    static let positive = Color("BatteryPositive")
    static let power = Color("BatteryPower")
    static let warning = Color("BatteryWarning")
    static let action = Color("BatteryAction")
}
