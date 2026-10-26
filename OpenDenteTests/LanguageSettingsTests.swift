import XCTest
@testable import OpenDente

@MainActor
final class LanguageSettingsTests: XCTestCase {
    func testAutomaticLanguageUsesFrenchOnlyForFrenchAndEnglishOtherwise() {
        XCTAssertEqual(AppLanguage.system.resolvedCode(preferredLanguages: ["fr-CA", "en"]), "fr")
        XCTAssertEqual(AppLanguage.system.resolvedCode(preferredLanguages: ["en-GB", "fr"]), "en")
        XCTAssertEqual(AppLanguage.system.resolvedCode(preferredLanguages: ["de-DE"]), "en")
        XCTAssertEqual(AppLanguage.system.resolvedCode(preferredLanguages: []), "en")
        XCTAssertEqual(AppLanguage.french.resolvedCode(preferredLanguages: ["en"]), "fr")
        XCTAssertEqual(AppLanguage.english.resolvedCode(preferredLanguages: ["fr"]), "en")
    }

    func testLanguagePersistsWithoutChangingBatteryPreferences() throws {
        let name = "OpenDente.LanguageTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(80, forKey: "chargeLimit")
        defaults.set(true, forKey: "nativeChargeLimitEnabled")
        let settings = LanguageSettings(defaults: defaults)
        XCTAssertEqual(settings.selection, .system)
        settings.selection = .english
        XCTAssertEqual(LanguageSettings(defaults: defaults).selection, .english)
        XCTAssertEqual(defaults.integer(forKey: "chargeLimit"), 80)
        XCTAssertTrue(defaults.bool(forKey: "nativeChargeLimitEnabled"))
        settings.selection = .french
        XCTAssertEqual(LanguageSettings(defaults: defaults).selection, .french)
    }
}
