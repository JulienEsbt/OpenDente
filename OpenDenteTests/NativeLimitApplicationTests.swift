import XCTest
@testable import OpenDente

final class NativeLimitApplicationTests: XCTestCase {
    func testRepeatedLowHoldDoesNotReinitializeTheAgentAtEighty() throws {
        let application = NativeLimitApplication()
        var events: [Int] = []
        for _ in 0..<3 {
            try application.apply(77, setAgentLimit: { events.append($0) }, setLowerTarget: { events.append($0) })
        }
        XCTAssertEqual(events, [80, 77, 77, 77])
    }

    func testLowTargetActivatesAgainAfterTopUpOrRestoration() throws {
        let application = NativeLimitApplication()
        var events: [Int] = []
        let set: (Int) -> Void = { events.append($0) }
        try application.apply(76, setAgentLimit: set, setLowerTarget: set)
        try application.apply(100, setAgentLimit: set, setLowerTarget: set)
        try application.apply(76, setAgentLimit: set, setLowerTarget: set)
        application.reset()
        try application.apply(76, setAgentLimit: set, setLowerTarget: set)
        XCTAssertEqual(events, [80, 76, 100, 80, 76, 80, 76])
    }

    func testTargetsInApplesRangeAlwaysUseItsValidatedSetter() throws {
        let application = NativeLimitApplication()
        var limits: [Int] = []
        for target in [80, 90, 100] {
            try application.apply(target, setAgentLimit: { limits.append($0) },
                setLowerTarget: { _ in XCTFail("No preference override") })
        }
        XCTAssertEqual(limits, [80, 90, 100])
    }

    func testFailedActivationDoesNotWriteALowerPreferenceAndCanRetry() throws {
        enum Failure: Error { case unavailable }
        let application = NativeLimitApplication()
        XCTAssertThrowsError(try application.apply(77, setAgentLimit: { _ in throw Failure.unavailable },
            setLowerTarget: { _ in XCTFail("Must preserve the failed activation") }))
        var events: [Int] = []
        try application.apply(77, setAgentLimit: { events.append($0) }, setLowerTarget: { events.append($0) })
        XCTAssertEqual(events, [80, 77])
    }
}
