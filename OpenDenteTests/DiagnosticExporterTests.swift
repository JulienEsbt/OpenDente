import XCTest
@testable import OpenDente

@MainActor
final class DiagnosticExporterTests: XCTestCase {
    private var suite: String!
    private var settings: AppSettings!
    private var manager: ChargingManager!

    override func setUp() async throws {
        try await super.setUp()
        suite = "com.opendente.tests.diagnostics.\(UUID().uuidString)"
        settings = AppSettings(defaults: UserDefaults(suiteName: suite)!)
        settings.showNotifications = false
        manager = ChargingManager(settings: settings, helper: MockChargingControl(),
            battery: BatteryService(settings: settings), sleepAssertion: MockSleepAssertionControl())
    }

    override func tearDown() async throws {
        settings.defaults.removePersistentDomain(forName: suite)
        manager = nil; settings = nil
        try await super.tearDown()
    }

    func testNativeReportIdentifiesPowerUIAndNativeModesWithoutSMC() {
        manager.nativeLimitAvailable = true
        manager.chargingAPI = .unknown
        settings.nativeChargeLimitEnabled = true
        settings.nativeReturnToLimitEnabled = true
        settings.storagePreparationEnabled = true
        settings.nativeMagSafeLEDEnabled = true
        let report = DiagnosticExporter.chargingControlReport(charging: manager, settings: settings)
        XCTAssertTrue(report.contains("Charging API: PowerUI native (experimental)"))
        XCTAssertTrue(report.contains("Native Control: on"))
        XCTAssertTrue(report.contains("Return to Charge Limit: on"))
        XCTAssertTrue(report.contains("Storage Preparation (50%): on"))
        XCTAssertTrue(report.contains("Native MagSafe LED: on"))
        XCTAssertFalse(report.contains("Not detected"))
    }

    func testDetectedNativeBackendDoesNotImplyOptInOrAcknowledgedTarget() {
        manager.nativeLimitAvailable = true
        settings.nativeChargeLimitEnabled = false
        let report = DiagnosticExporter.chargingControlReport(charging: manager, settings: settings)
        XCTAssertTrue(report.contains("Native Control: off"))
        XCTAssertTrue(report.contains("Native Target: not acknowledged"))
    }

    func testSMCBackendIsStillIdentifiedWhenNativeBackendIsUnavailable() {
        manager.nativeLimitAvailable = false
        manager.chargingAPI = .legacy
        let report = DiagnosticExporter.chargingControlReport(charging: manager, settings: settings)
        XCTAssertTrue(report.contains("Charging API: Legacy SMC (CH0B/CH0C)"))
        XCTAssertTrue(report.contains("Native Available: no"))
    }
}
