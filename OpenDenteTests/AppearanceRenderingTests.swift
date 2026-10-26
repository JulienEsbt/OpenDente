import AppKit
import SwiftUI
import XCTest
@testable import OpenDente

@MainActor
final class AppearanceRenderingTests: XCTestCase {
    /// Render native controls with inert fixtures; no service or battery command is used.
    func testChargeControlsRenderInLightAndDarkWithoutChangingPolicy() throws {
        let suite = "OpenDente.AppearanceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults)
        settings.chargeLimit = 80
        settings.sailingRange = 10
        settings.nativeChargeLimitEnabled = true
        let battery = BatteryService(settings: settings)
        battery.batteryState = BatteryState(percentage: 78, hardwarePercentage: nil,
            isCharging: true, isPluggedIn: true, currentCapacity: nil, maxCapacity: nil,
            designCapacity: nil, cycleCount: nil, temperature: 31, voltage: nil,
            amperage: nil, systemPower: 8, adapterPower: 30, adapterInfo: nil,
            batteryPower: 22, notChargingReason: nil, chargerInhibitReason: nil,
            timeToEmpty: nil, timeToFull: nil)
        let helper = MockChargingControl()
        let manager = ChargingManager(settings: settings, helper: helper, battery: battery, sleepAssertion: MockSleepAssertionControl())
        manager.isHelperInstalled = true
        manager.nativeLimitAvailable = true
        for dark in [false, true] {
            let appearance = try XCTUnwrap(NSAppearance(named: dark ? .darkAqua : .aqua))
            let content = VStack(spacing: 16) {
                ChargeControlsView(charging: manager, settings: settings, state: battery.batteryState)
                PowerFlowView(battery: battery.batteryState, mode: .charging)
            }
            .padding(16)
            .frame(width: 360, height: 520, alignment: .top)
            .background(Color(nsColor: .windowBackgroundColor))
            .tint(AppPalette.accent)
            .environment(\.colorScheme, dark ? .dark : .light)
            .environment(\.controlActiveState, .active)
            let host = NSHostingView(rootView: content)
            host.frame = NSRect(x: 0, y: 0, width: 360, height: 520)
            let window = NSWindow(contentRect: host.frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.appearance = appearance
            window.contentView = host
            host.layoutSubtreeIfNeeded()
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            XCTAssertGreaterThanOrEqual(bitmap.pixelsWide, 360)
            XCTAssertGreaterThanOrEqual(bitmap.pixelsHigh, 520)
            if let folder = ProcessInfo.processInfo.environment["OPENDENTE_UI_CAPTURE_DIR"] {
                let file = URL(fileURLWithPath: folder).appendingPathComponent("controls-\(L10n.languageCode)-\(dark ? "dark" : "light").png")
                try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: file)
            }
            window.orderOut(nil)
        }
        XCTAssertEqual(settings.chargeLimit, 80)
        XCTAssertEqual(settings.sailingLowerBound, 70)
        XCTAssertTrue(helper.calls.isEmpty, "Rendering must not issue a charging command")
    }
}
