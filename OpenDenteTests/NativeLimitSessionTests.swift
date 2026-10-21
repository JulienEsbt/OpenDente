import XCTest
@testable import OpenDente

final class NativeLimitSessionTests: XCTestCase {
    private final class Store {
        var marker: NativeLimitSession.Snapshot?
        var events: [String] = []
        var failSave = false
        var failApply = false
        var failRestore = false
        var corrupt = false
        let original = NativeLimitSession.Snapshot(enabled: 1, limit: 80)
        func session() -> NativeLimitSession {
            NativeLimitSession(load: {
                if self.corrupt { throw NativeLimitSession.Failure(message: "corrupt journal") }
                return self.marker
            }, save: { value in
                self.events.append("save")
                if self.failSave { throw NativeLimitSession.Failure(message: "disk full") }
                self.marker = value
            }, capture: { self.original }, apply: { target in
                self.events.append("apply:\(target)")
                if self.failApply { throw NativeLimitSession.Failure(message: "agent failed") }
            }, restore: { value in
                self.events.append("restore:\(value.limit ?? -1)")
                if self.failRestore { throw NativeLimitSession.Failure(message: "restore failed") }
            }, clear: { self.events.append("clear"); self.marker = nil })
        }
    }
    func testJournalPrecedesWriteAndOriginalIsNotOverwritten() throws {
        let store = Store(), session = store.session()
        try session.setLimit(70, currentPercentage: 50)
        try session.setLimit(100, currentPercentage: 60)
        XCTAssertEqual(store.events, ["save", "apply:70", "apply:100"])
        XCTAssertEqual(store.marker, store.original)
    }
    func testInvalidOrLowerTargetNeverWrites() {
        let store = Store(), session = store.session()
        for (target, current) in [(19, 10), (101, 50), (70, 85), (80, -1), (80, 101)] {
            XCTAssertThrowsError(try session.setLimit(target, currentPercentage: current))
        }
        XCTAssertTrue(store.events.isEmpty)
    }
    func testFailedJournalPreventsNativeWrite() {
        let store = Store(); store.failSave = true
        XCTAssertThrowsError(try store.session().setLimit(80, currentPercentage: 50))
        XCTAssertEqual(store.events, ["save"])
    }
    func testPartialFailureRestoresOriginal() {
        let store = Store(); store.failApply = true
        XCTAssertThrowsError(try store.session().setLimit(80, currentPercentage: 50))
        XCTAssertEqual(store.events, ["save", "apply:80", "restore:80", "clear"])
        XCTAssertNil(store.marker)
    }
    func testFailedRestorationKeepsJournalAndCanRetryAfterRestart() throws {
        let store = Store(); store.failApply = true; store.failRestore = true
        let session = store.session()
        XCTAssertThrowsError(try session.setLimit(80, currentPercentage: 50))
        XCTAssertTrue(session.restorationPending)
        XCTAssertEqual(store.marker, store.original)
        store.failRestore = false
        try store.session().restore()
        XCTAssertNil(store.marker)
    }
    func testCorruptJournalDoesNotGetReplacedByFabricatedDefaults() {
        let store = Store(); store.corrupt = true
        XCTAssertThrowsError(try store.session().setLimit(80, currentPercentage: 50))
        XCTAssertThrowsError(try store.session().restore())
        XCTAssertTrue(store.events.isEmpty)
    }
    func testNoJournalMeansNoRestorationWrite() throws {
        let store = Store()
        try store.session().restore()
        XCTAssertTrue(store.events.isEmpty)
    }
}

extension NativeLimitSessionTests {
    func testNativePreferenceJournalPreservesTemporaryDatesAndUnknownMCLKeys() throws {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let originals: [String: Any] = ["MCLFeatureState": 2, "mclLimitValue": 80,
            "mclTemporaryDisablementDate": date, "MCLFutureOption": Data([1, 2, 3])]
        let data = try NativeLimitPreferences.encode(originals)
        XCTAssertTrue(NSDictionary(dictionary: try NativeLimitPreferences.decode(data)).isEqual(to: originals))
    }

    func testNativePreferenceJournalCannotRestoreUnrelatedSettings() {
        XCTAssertThrowsError(try NativeLimitPreferences.encode(["optimizedCharging": true]))
        XCTAssertThrowsError(try NativeLimitPreferences.decode(Data("invalid".utf8)))
        XCTAssertThrowsError(try NativeLimitPreferences.decode(Data(repeating: 0, count: 16385)))
    }

    func testNativeSnapshotCodablePreservesCompletePreferences() throws {
        let data = try NativeLimitPreferences.encode(["MCLFeatureState": 2, "mclLimitValue": 95])
        let snapshot = NativeLimitSession.Snapshot(enabled: 2, limit: 95, preferences: data)
        XCTAssertEqual(try JSONDecoder().decode(NativeLimitSession.Snapshot.self,
            from: JSONEncoder().encode(snapshot)), snapshot)
    }

    func testLegacyNativeJournalCanStillBeDecodedForRestoration() throws {
        let legacy = Data("{\"enabled\":1,\"limit\":100}".utf8)
        let decoded = try JSONDecoder().decode(NativeLimitSession.Snapshot.self, from: legacy)
        XCTAssertEqual(decoded, NativeLimitSession.Snapshot(enabled: 1, limit: 100))
    }
}


extension NativeLimitSessionTests {
    func testNativeGuardUsesInternalBatteryWhenUPSIsListedFirst() throws {
        let ups: [String: Any] = ["Type": "UPS", "Current Capacity": 20, "Max Capacity": 100]
        let internalBattery: [String: Any] = ["Type": "InternalBattery", "Current Capacity": 99, "Max Capacity": 100]
        let reading = try InternalBatteryReading.read([ups, internalBattery])
        XCTAssertEqual(reading.percentage, 99)
        let store = Store()
        XCTAssertThrowsError(try store.session().setLimit(80, currentPercentage: reading.percentage))
        XCTAssertTrue(store.events.isEmpty)
    }
    func testNativeGuardRejectsMissingOrAmbiguousInternalBattery() {
        let battery: [String: Any] = ["Type": "InternalBattery", "Current Capacity": 50, "Max Capacity": 100]
        XCTAssertThrowsError(try InternalBatteryReading.read([]))
        XCTAssertThrowsError(try InternalBatteryReading.read([["Type": "UPS"]]))
        XCTAssertThrowsError(try InternalBatteryReading.read([battery, battery]))
    }
    func testNativeGuardRejectsImpossibleInternalCapacity() {
        for (current, maximum) in [(-1, 100), (101, 100), (50, 0)] {
            XCTAssertThrowsError(try InternalBatteryReading.read([["Type": "InternalBattery",
                "Current Capacity": current, "Max Capacity": maximum]]))
        }
    }
    func testNativeGuardRoundsUpFractionalInternalPercentage() throws {
        let reading = try InternalBatteryReading.read([["Type": "InternalBattery",
            "Current Capacity": 177, "Max Capacity": 200]])
        XCTAssertEqual(reading.percentage, 89)
    }
}


extension NativeLimitSessionTests {
    func testOnlyDedicatedStorageCommandCanRequestBelowCurrentLevel() throws {
        let store = Store(), session = store.session()
        XCTAssertThrowsError(try session.setLimit(50, currentPercentage: 98))
        try session.setStorageLimit(currentPercentage: 98)
        XCTAssertEqual(store.events, ["save", "apply:50"])
        try session.restore()
        XCTAssertEqual(store.events.suffix(2), ["restore:80", "clear"])
    }
    func testStorageRejectsInvalidOrAlreadyLowerReadingBeforeWriting() {
        let store = Store(), session = store.session()
        for level in [-1, 0, 49, 101] { XCTAssertThrowsError(try session.setStorageLimit(currentPercentage: level)) }
        XCTAssertTrue(store.events.isEmpty)
    }
    func testStorageCannotWriteWithoutRecoveryJournal() {
        let store = Store(); store.failSave = true
        XCTAssertThrowsError(try store.session().setStorageLimit(currentPercentage: 90))
        XCTAssertEqual(store.events, ["save"])
    }
}
