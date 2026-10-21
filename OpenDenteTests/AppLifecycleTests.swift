import AppKit
import XCTest
@testable import OpenDente

final class AppLifecycleTests: XCTestCase {
    func testClosingAllWindowsKeepsTheMenuBarAppRunning() async {
        await MainActor.run {
            let delegate: NSApplicationDelegate = AppDelegate()
            XCTAssertEqual(delegate.applicationShouldTerminateAfterLastWindowClosed?(NSApplication.shared), false)
        }
    }
}
