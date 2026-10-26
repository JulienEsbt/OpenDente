import AppKit
import XCTest
@testable import OpenDente

@MainActor
final class LocalizationAndAppearanceTests: XCTestCase {
    func testEnglishResourcesIncludeLabelsAndInterpolatedThresholds() throws {
        let path = try XCTUnwrap(Bundle.main.path(forResource: "en", ofType: "lproj"))
        let bundle = try XCTUnwrap(Bundle(path: path))
        XCTAssertEqual(String(localized: "Limite habituelle", bundle: bundle), "Daily limit")
        let threshold = 75
        XCTAssertEqual(String(localized: "Reprise sous \(threshold) %.", bundle: bundle), "Resume below 75%.")
    }

    func testEnglishOfflineGuideIsBundled() throws {
        let path = try XCTUnwrap(Bundle.main.path(forResource: "en", ofType: "lproj"))
        let bundle = try XCTUnwrap(Bundle(path: path))
        let url = try XCTUnwrap(bundle.url(forResource: "OpenDenteGuide", withExtension: "json"))
        let sections = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [[String: Any]])
        XCTAssertGreaterThan(sections.count, 5)
        XCTAssertTrue(sections.contains { ($0["title"] as? String) == "Charging controls" })
    }

    func testEnglishCatalogKeepsMixedPlaceholderTypesAndCurrentStorageMessage() throws {
        let path = try XCTUnwrap(Bundle.main.path(forResource: "en", ofType: "lproj"))
        let bundle = try XCTUnwrap(Bundle(path: path))
        let title = "Daily", limit = 80, resume = 75
        XCTAssertEqual(String(localized: "Profil \(title), limite \(limit) pour cent, reprise sous \(resume) pour cent", bundle: bundle),
                       "Daily profile, limit 80 percent, resume below 75 percent")
        XCTAssertEqual(String(localized: "Recharge vers 50 %, puis maintien. La consigne peut prendre plusieurs minutes.", bundle: bundle),
                       "Charging toward 50%, then holding. The target may take several minutes to apply.")
    }

    func testFrenchAndEnglishHaveTheSameCatalogKeysAndPlaceholderTypes() throws {
        func catalog(_ language: String) throws -> [String: String] {
            let path = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"))
            let bundle = try XCTUnwrap(Bundle(path: path))
            let url = try XCTUnwrap(bundle.url(forResource: "Localizable", withExtension: "strings"))
            return try XCTUnwrap(PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: String])
        }
        let french = try catalog("fr"), english = try catalog("en")
        XCTAssertGreaterThan(english.count, 300)
        XCTAssertEqual(Set(french.keys), Set(english.keys))
        let pattern = try NSRegularExpression(pattern: #"%(?:\d+\$)?(?:ll)?[diu@fg]"#)
        func placeholders(_ text: String) -> [String] {
            let plain = text.replacingOccurrences(of: "%%", with: "")
            return pattern.matches(in: plain, range: NSRange(plain.startIndex..., in: plain)).map {
                let match = (plain as NSString).substring(with: $0.range)
                return match.replacingOccurrences(of: #"\d+\$"#, with: "", options: .regularExpression)
            }.sorted()
        }
        for (key,value) in french {
            XCTAssertEqual(placeholders(value), placeholders(english[key]!), "Format arguments for \(key)")
        }
    }

    func testStatusAndAccentColorsRemainReadableInBothAppearances() throws {
        for appearanceName in [NSAppearance.Name.aqua, .darkAqua] {
            let appearance = try XCTUnwrap(NSAppearance(named: appearanceName))
            let colors = try ["BatteryAccent", "BatteryPositive", "BatteryPower", "BatteryWarning"].map { name in
                (name, try XCTUnwrap(NSColor(named: name, bundle: .main)))
            }
            let action = try XCTUnwrap(NSColor(named: "BatteryAction", bundle: .main))
            appearance.performAsCurrentDrawingAppearance {
                XCTAssertGreaterThanOrEqual(contrast(action, .white), 4.5, "Primary action label in \(appearanceName.rawValue)")
                let surface = NSColor.windowBackgroundColor
                for (name, color) in colors {
                    XCTAssertGreaterThanOrEqual(contrast(color, surface), 4.5, "\(name) in \(appearanceName.rawValue)")
                }
                let accent = colors[0].1
                if appearanceName == .aqua {
                    XCTAssertGreaterThanOrEqual(contrast(accent, .white), 4.5, "Primary button text")
                }
            }
        }
    }

    private func contrast(_ first: NSColor, _ second: NSColor) -> Double {
        func luminance(_ color: NSColor) -> Double {
            let rgb = color.usingColorSpace(.sRGB)!
            func linear(_ channel: CGFloat) -> Double {
                let v = Double(channel)
                return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear(rgb.redComponent) + 0.7152 * linear(rgb.greenComponent) + 0.0722 * linear(rgb.blueComponent)
        }
        let a = luminance(first), b = luminance(second)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}
