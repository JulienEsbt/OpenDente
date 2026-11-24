import XCTest
import AppKit
import SwiftUI
@testable import OpenDente

@MainActor
final class BatteryHistoryTests: XCTestCase {
    func testWeekRetentionKeepsOlderReadingsAndShorteningTheWindowPrunesThem() throws {
        let name = "OpenDente.HistoryTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("history.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let now = Date()
        let history = BatteryHistoryStore(fileURL: url, enabled: true, defaults: defaults, retentionDays: 7, now: now)
        history.record(percentage: 80, temperature: 32, mode: .paused, plugged: true, now: now.addingTimeInterval(-172800))
        history.record(percentage: 78, temperature: 31, mode: .paused, plugged: true, now: now)
        XCTAssertEqual(history.samples.count, 2)
        history.setRetentionDays(1, now: now)
        XCTAssertEqual(history.samples.count, 1)
        XCTAssertEqual(BatteryHistoryStore(fileURL: url, enabled: true, defaults: defaults, now: now).retentionDays, 1)
        history.setRetentionDays(7, now: now)
        XCTAssertEqual(history.samples.count, 1, "Extending retention cannot recreate purged data")
    }

    func testReloadBoundsTheFileAndDoesNotAcceptFutureOrInvalidSamples() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let now = Date()
        var samples = (0..<3000).map { index in
            BatteryHistorySample(date: now.addingTimeInterval(-Double(3000 - index) * 10), percentage: 80,
                temperature: 30, mode: "paused", plugged: true, segment: UUID())
        }
        samples.append(BatteryHistorySample(date: now.addingTimeInterval(100), percentage: 101,
            temperature: 30, mode: "paused", plugged: true, segment: UUID()))
        try JSONEncoder().encode(samples).write(to: url)
        let store = BatteryHistoryStore(fileURL: url, enabled: true, retentionDays: 1, now: now)
        XCTAssertEqual(store.samples.count, store.maximumSamples)
        XCTAssertTrue(store.samples.allSatisfy { $0.date <= now && (0...100).contains($0.percentage) })
        let expired = BatteryHistoryStore(fileURL: url, enabled: true, retentionDays: 1, now: now.addingTimeInterval(86401))
        XCTAssertTrue(expired.samples.isEmpty)
        XCTAssertTrue(try JSONDecoder().decode([BatteryHistorySample].self, from: Data(contentsOf: url)).isEmpty)
    }

    func testHistoryGraphsRenderInBothAppearancesWithoutHardwareAccess() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("history.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let history = BatteryHistoryStore(fileURL: url, enabled: true)
        let start = Date().addingTimeInterval(-600)
        for index in 0..<6 {
            history.record(percentage: 75 + index, temperature: index == 2 ? nil : 31 + Double(index),
                mode: index == 4 ? .heatProtection : .charging, plugged: true, now: start.addingTimeInterval(Double(index) * 60))
        }
        for dark in [false, true] {
            let host = NSHostingView(rootView: BatteryHistoryView(history: history)
                .environment(\.colorScheme, dark ? .dark : .light))
            host.frame = NSRect(x: 0, y: 0, width: 620, height: 640)
            let window = NSWindow(contentRect: host.frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            window.contentView = host
            host.layoutSubtreeIfNeeded()
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            XCTAssertGreaterThanOrEqual(bitmap.pixelsWide, 620)
            window.orderOut(nil)
        }
    }

    func testHistoryThrottlesButKeepsModeChangesAndPrunesAfterADay() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("history.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let now = Date()
        let history = BatteryHistoryStore(fileURL: url, enabled: true, retentionDays: 1, now: now)
        history.record(percentage: 80, temperature: 34, mode: .paused, plugged: true, now: now)
        history.record(percentage: 79, temperature: 34, mode: .paused, plugged: true, now: now.addingTimeInterval(2))
        XCTAssertEqual(history.samples.count, 1)
        history.record(percentage: 79, temperature: 40, mode: .heatProtection, plugged: true, now: now.addingTimeInterval(3))
        XCTAssertEqual(history.samples.count, 2)
        let restored = BatteryHistoryStore(fileURL: url, enabled: true, retentionDays: 1, now: now.addingTimeInterval(10))
        XCTAssertEqual(restored.samples.count, 2)
        restored.record(percentage: 75, temperature: .nan, mode: .charging, plugged: true, now: now.addingTimeInterval(86410))
        XCTAssertEqual(restored.samples.count, 1)
        XCTAssertNil(restored.samples.first?.temperature)
        restored.setEnabled(false)
        XCTAssertTrue(restored.samples.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testClearPreventsOldDataReturningAndMissingMeasurementsRemainGaps() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("history.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let now = Date()
        let store = BatteryHistoryStore(fileURL: url, enabled: true, now: now)
        store.record(percentage: 101, temperature: 30, mode: .paused, plugged: true, now: now)
        XCTAssertTrue(store.samples.isEmpty)
        store.record(percentage: 80, temperature: 30, mode: .paused, plugged: true, now: now)
        store.record(percentage: 78, temperature: nil, mode: .onBattery, plugged: false, now: now.addingTimeInterval(600))
        XCTAssertNotEqual(store.samples[0].segment, store.samples[1].segment)
        store.clear()
        XCTAssertTrue(BatteryHistoryStore(fileURL: url, enabled: true, now: now).samples.isEmpty)
    }
}
