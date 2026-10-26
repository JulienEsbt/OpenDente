import XCTest
@testable import OpenDente

final class BundledGuideTests: XCTestCase {
    func testGuideAndCreditsAreAvailableOfflineInApplicationBundle() throws {
        let bundle = L10n.bundle(for: "fr")
        let url = try XCTUnwrap(bundle.url(forResource: "OpenDenteGuide", withExtension: "json"))
        let sections = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [[String: Any]])
        XCTAssertGreaterThan(sections.count, 5)
        XCTAssertTrue(sections.contains { ($0["title"] as? String) == "Charge : ce que contrôlent les réglages" })
        XCTAssertNotNil(Bundle.main.url(forResource: "LICENSE", withExtension: nil))
        XCTAssertNotNil(Bundle.main.url(forResource: "THIRD-PARTY-NOTICES", withExtension: "md"))
    }
}
