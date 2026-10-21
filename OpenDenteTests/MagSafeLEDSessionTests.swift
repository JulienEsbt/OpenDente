import XCTest
@testable import OpenDente

final class MagSafeLEDSessionTests: XCTestCase {
    final class Hardware {
        var value: UInt8 = 0
        var marker = false
        var automaticReadback: UInt8 = 0
        var delayedReads: [UInt8] = []
        var events: [String] = []
        var failSave = false
        var failRestore = false
        var mismatch = false
        func session() -> MagSafeLEDSession {
            MagSafeLEDSession(needsRecovery: marker, write: { c in
                self.events.append("write:\(c)")
                if c == 0 && self.failRestore { throw NSError(domain: "LED", code: 1) }
                self.value = c == 0 ? self.automaticReadback : c
            }, read: {
                if !self.delayedReads.isEmpty { return self.delayedReads.removeFirst() }
                return self.mismatch ? 2 : self.value
            }, persist: { required in
                self.events.append("persist:\(required)")
                if self.failSave { throw NSError(domain: "disk", code: 1) }
                self.marker = required
            })
        }
    }
    func testOwnershipSavedBeforeOverrideAndClearedAfterAutomaticReadback() throws {
        let h = Hardware(), session = h.session()
        try session.set(3)
        XCTAssertEqual(h.events, ["persist:true", "write:3"])
        XCTAssertTrue(h.marker)
        try session.restore()
        XCTAssertEqual(h.events.suffix(2), ["write:0", "persist:false"])
        XCTAssertFalse(h.marker)
    }
    func testMissingJournalSpacePreventsLEDWrite() {
        let h = Hardware(); h.failSave = true
        XCTAssertThrowsError(try h.session().set(4))
        XCTAssertEqual(h.events, ["persist:true"])
        XCTAssertEqual(h.value, 0)
    }
    func testUnknownColorsNeverWriteIncludingUndocumentedBlinkCode() {
        let h = Hardware()
        for c: UInt8 in [2, 5, 255] { XCTAssertThrowsError(try h.session().set(c)) }
        XCTAssertTrue(h.events.isEmpty)
    }
    func testReadbackFailureKeepsRecoveryAndRestartCanRestore() throws {
        let h = Hardware(); h.mismatch = true
        let session = h.session()
        XCTAssertThrowsError(try session.set(3))
        XCTAssertTrue(h.marker); XCTAssertTrue(session.restorationPending)
        h.mismatch = false
        try h.session().restore()
        XCTAssertFalse(h.marker); XCTAssertEqual(h.value, 0)
    }
    func testFailedRestoreRetainsMarkerUntilRetry() throws {
        let h = Hardware(), session = h.session()
        try session.set(1)
        h.failRestore = true
        XCTAssertThrowsError(try session.restore())
        XCTAssertTrue(h.marker); XCTAssertTrue(session.restorationPending)
        h.failRestore = false
        try session.restore()
        XCTAssertFalse(h.marker)
    }
    func testNoOwnershipDoesNotTouchHardwareOnRecovery() throws {
        let h = Hardware(); try h.session().restore(); XCTAssertTrue(h.events.isEmpty)
    }
    func testAutomaticCommandCanReadBackTheSystemCurrentColor() throws {
        let h = Hardware(), session = h.session()
        try session.set(3)
        h.automaticReadback = 4
        XCTAssertNoThrow(try session.restore())
        XCTAssertFalse(h.marker)
        XCTAssertFalse(session.restorationPending)
        XCTAssertEqual(h.value, 4)
    }
    func testColorReadbackWaitsForFirmwareInsteadOfImmediatelyRestoring() throws {
        let h = Hardware(), session = h.session()
        h.delayedReads = [4, 4, 3]
        XCTAssertNoThrow(try session.set(3))
        XCTAssertEqual(h.events, ["persist:true", "write:3"])
        XCTAssertTrue(h.marker)
    }

}
