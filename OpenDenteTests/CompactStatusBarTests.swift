import AppKit
import XCTest
@testable import OpenDente

@MainActor
final class CompactStatusBarTests: XCTestCase {
    private var settings: AppSettings!
    private var suite: String!
    override func setUp() async throws {
        suite = "com.opendente.tests.compact.\(UUID().uuidString)"
        settings = AppSettings(defaults: UserDefaults(suiteName: suite)!)
    }
    override func tearDown() async throws {
        settings.defaults.removePersistentDomain(forName: suite)
        settings = nil
    }
    func testCompactDisplayDefaultsOnAndClassicChoicePersists() {
        XCTAssertTrue(settings.compactStatusBar)
        settings.compactStatusBar = false
        XCTAssertFalse(AppSettings(defaults: settings.defaults).compactStatusBar)
    }
    func testAllMeasurementsFitInLessSpaceThanTheClassicDisplay() {
        settings.statusBarShowTemperature = true
        settings.statusBarShowPower = true
        let state = BatteryState(percentage: 67, hardwarePercentage: nil, isCharging: false, isPluggedIn: false,
            currentCapacity: nil, maxCapacity: nil, designCapacity: nil, cycleCount: nil,
            temperature: 33, voltage: nil, amperage: nil, systemPower: 4, adapterPower: nil,
            adapterInfo: nil, batteryPower: nil, notChargingReason: nil, chargerInhibitReason: nil,
            timeToEmpty: nil, timeToFull: nil)
        let image = CompactStatusBar.image(state: state, mode: .onBattery, settings: settings)
        let classic = state.statusBarText(effectivePercentage: 67, showPercentage: true,
            showTemperature: true, showPower: true)
        let classicWidth = 24 + (classic as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 13)]).width
        XCTAssertLessThan(image.size.width, classicWidth * 0.8)
        XCTAssertTrue(image.isTemplate)
        XCTAssertTrue(image.accessibilityDescription?.contains("67") == true)
        XCTAssertTrue(image.accessibilityDescription?.contains("33") == true)
        XCTAssertTrue(image.accessibilityDescription?.contains("4W") == true)
    }
    func testMissingReadingDoesNotAnnounceAnInventedZeroPercent() {
        let image = CompactStatusBar.image(state: .unknown, mode: .idle, settings: settings)
        XCTAssertTrue(image.accessibilityDescription?.contains(String(localized: "Lecture en cours", bundle: L10n.bundle)) == true)
        XCTAssertFalse(image.accessibilityDescription?.contains("0 %") == true)
        XCTAssertFalse(image.accessibilityDescription?.contains("0%") == true)
    }
    func testMiddleChargeKeepsTheNumberBackgroundUniform() throws {
        for percent in [20, 50, 68, 100] {
            let state = BatteryState(percentage: percent, hardwarePercentage: nil, isCharging: false, isPluggedIn: false,
                currentCapacity: nil, maxCapacity: nil, designCapacity: nil, cycleCount: nil,
                temperature: nil, voltage: nil, amperage: nil, systemPower: nil, adapterPower: nil,
                adapterInfo: nil, batteryPower: nil, notChargingReason: nil, chargerInhibitReason: nil,
                timeToEmpty: nil, timeToFull: nil)
            let image = CompactStatusBar.image(state: state, mode: .onBattery, settings: settings)
            let bitmap = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 68, pixelsHigh: 40,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap))
            NSGraphicsContext.current?.cgContext.scaleBy(x: 2, y: 2)
            image.draw(at: .zero, from: .zero, operation: .copy, fraction: 1)
            NSGraphicsContext.restoreGraphicsState()
            // Padding on either side of the digits must have the same opaque face.
            // The former fill boundary made the right side gray at middle levels.
            XCTAssertEqual(try XCTUnwrap(bitmap.colorAt(x: 6, y: 20)).alphaComponent, 1, accuracy: 0.03)
            XCTAssertEqual(try XCTUnwrap(bitmap.colorAt(x: 56, y: 20)).alphaComponent, 1, accuracy: 0.03)
            // The digits must actually cut through the opaque face for template contrast.
            let clearDigitPixels = (10..<29).flatMap { y in (12..<48).map { x in
                bitmap.colorAt(x: x, y: y)!.alphaComponent
            } }.filter { $0 < 0.1 }.count
            XCTAssertGreaterThan(clearDigitPixels, 8)
            // A 2-point track separated from the number face must stay visible.
            // Bitmap rows run downwards; its four Retina rows are 34...37.
            for y in 34...37 {
                XCTAssertEqual(try XCTUnwrap(bitmap.colorAt(x: 50, y: y)).alphaComponent,
                    percent == 100 ? 1 : 0.25, accuracy: 0.03)
                XCTAssertEqual(try XCTUnwrap(bitmap.colorAt(x: 8, y: y)).alphaComponent, 1, accuracy: 0.03)
            }
            XCTAssertEqual(try XCTUnwrap(bitmap.colorAt(x: 8, y: 32)).alphaComponent, 0, accuracy: 0.03)
        }
    }

}
