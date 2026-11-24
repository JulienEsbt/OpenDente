import Foundation
import Combine

struct BatteryHistorySample: Codable, Identifiable, Equatable {
    var id: Date { date }
    let date: Date
    let percentage: Int
    let temperature: Double?
    let mode: String
    let plugged: Bool
    let segment: UUID
}

/// Observes existing readings only. No hardware access and no charging commands.
@MainActor
final class BatteryHistoryStore: ObservableObject {
    static let shared = BatteryHistoryStore(fileURL: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("OpenDente/BatteryHistory.json"),
        enabled: UserDefaults.standard.object(forKey: "batteryHistoryEnabled") as? Bool ?? true, defaults: .standard)
    @Published private(set) var retentionDays: Int
    var retention: TimeInterval { Double(retentionDays) * 86400 }
    var maximumSamples: Int { retentionDays * 2880 }
    @Published private(set) var samples: [BatteryHistorySample] = []
    @Published private(set) var enabled: Bool
    @Published private(set) var error: String?
    private let fileURL: URL
    private let defaults: UserDefaults?
    private var segment = UUID()

    init(fileURL: URL, enabled: Bool, defaults: UserDefaults? = nil, retentionDays: Int = 7, now: Date = Date()) {
        self.fileURL = fileURL; self.enabled = enabled; self.defaults = defaults
        let savedDays = defaults?.object(forKey: "batteryHistoryDays") as? Int ?? retentionDays
        self.retentionDays = savedDays == 1 ? 1 : 7
        guard enabled else { clear(); return }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            guard (attributes[.size] as? NSNumber)?.intValue ?? Int.max <= 8_000_000 else { throw CocoaError(.fileReadTooLarge) }
            samples = try JSONDecoder().decode([BatteryHistorySample].self, from: Data(contentsOf: fileURL))
                .filter { $0.date.timeIntervalSince(now) <= 0 && now.timeIntervalSince($0.date) <= retention &&
                    (0...100).contains($0.percentage) && ChargingMode(rawValue: $0.mode) != nil &&
                    ($0.temperature.map { $0.isFinite && (-20...100).contains($0) } ?? true) }
                .sorted { $0.date < $1.date }
            samples = Array(samples.suffix(maximumSamples))
            // Apply retention to the on-disk file even before the next valid reading.
            persist()
        } catch { self.error = String(localized: "L’historique local n’a pas pu être lu.", bundle: L10n.bundle) }
    }

    func setEnabled(_ value: Bool) {
        enabled = value
        defaults?.set(value, forKey: "batteryHistoryEnabled")
        if !value { clear() }
    }

    func setRetentionDays(_ days: Int, now: Date = Date()) {
        guard days == 1 || days == 7 else { return }
        retentionDays = days
        defaults?.set(days, forKey: "batteryHistoryDays")
        if enabled { _ = prune(now: now); persist() }
    }

    /// Avoid publishing the entire history when a frequent battery update changes nothing.
    @discardableResult
    private func prune(now: Date) -> Bool {
        let retained = Array(samples.filter { now.timeIntervalSince($0.date) <= retention && $0.date <= now }
            .suffix(maximumSamples))
        guard retained.count != samples.count else { return false }
        samples = retained
        return true
    }

    func record(percentage: Int, temperature: Double?, mode: ChargingMode, plugged: Bool, now: Date = Date()) {
        guard enabled else { return }
        var needsSave = prune(now: now)
        defer { if needsSave { persist() } }
        guard (0...100).contains(percentage), mode != .idle else { return }
        if let last = samples.last {
            let elapsed = now.timeIntervalSince(last.date)
            guard elapsed >= 60 || last.mode != mode.rawValue || last.plugged != plugged else { return }
            // Never draw a continuous line through sleep, shutdown or an observation gap.
            if elapsed > 90 { segment = UUID() }
        }
        samples.append(BatteryHistorySample(date: now, percentage: percentage,
            temperature: temperature.flatMap { $0.isFinite && (-20...100).contains($0) ? $0 : nil },
            mode: mode.rawValue, plugged: plugged, segment: segment))
        if samples.count > maximumSamples { samples.removeFirst(samples.count - maximumSamples) }
        needsSave = true
    }

    func clear() {
        samples = []; segment = UUID()
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) { try FileManager.default.removeItem(at: fileURL) }
            error = nil
        } catch { self.error = String(localized: "L’effacement de l’historique a échoué.", bundle: L10n.bundle) }
    }

    private func persist() {
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700])
            try JSONEncoder().encode(samples).write(to: fileURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
            error = nil
        } catch { self.error = String(localized: "L’enregistrement de l’historique a échoué.", bundle: L10n.bundle) }
    }
}
