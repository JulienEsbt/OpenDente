import SwiftUI
import Charts

struct BatteryHistoryView: View {
    @ObservedObject var history = BatteryHistoryStore.shared
    @State private var confirmClear = false

    private var events: [BatteryHistorySample] {
        history.samples.enumerated().filter { index, sample in
            index == 0 || sample.mode != history.samples[index - 1].mode || sample.plugged != history.samples[index - 1].plugged
        }.map(\.element)
    }

    var body: some View {
        Form {
            Section {
                Toggle(String(localized: "Conserver un historique local", bundle: L10n.bundle),
                    isOn: Binding(get: { history.enabled }, set: { history.setEnabled($0) }))
                Picker(String(localized: "Conservation", bundle: L10n.bundle),
                    selection: Binding(get: { history.retentionDays }, set: { history.setRetentionDays($0) })) {
                    Text(String(localized: "24 heures", bundle: L10n.bundle)).tag(1)
                    Text(String(localized: "7 jours", bundle: L10n.bundle)).tag(7)
                }.disabled(!history.enabled)
                Text(String(localized: "Un relevé par minute, plus les changements d’état. Tout reste sur ce Mac. Réduire la durée ou désactiver l’historique efface les anciens relevés.", bundle: L10n.bundle))
                    .font(.caption).foregroundStyle(.secondary)
            }
            if history.samples.isEmpty {
                Text(String(localized: "Les premiers relevés apparaîtront ici pendant l’utilisation d’OpenDente.", bundle: L10n.bundle))
                    .foregroundStyle(.secondary)
            } else {
                Section(String(localized: "Niveau de batterie", bundle: L10n.bundle)) {
                    Chart(plotSamples) { sample in
                        LineMark(x: .value("Date", sample.date), y: .value("%", sample.percentage), series: .value("Session", sample.segment.uuidString))
                            .foregroundStyle(AppPalette.accent)
                        PointMark(x: .value("Date", sample.date), y: .value("%", sample.percentage))
                            .foregroundStyle(AppPalette.accent).symbolSize(7)
                        if sample.mode == ChargingMode.heatProtection.rawValue {
                            PointMark(x: .value("Date", sample.date), y: .value("%", sample.percentage))
                                .foregroundStyle(AppPalette.warning).symbol(.diamond)
                        }
                    }.chartYScale(domain: 0...100).frame(height: 135)
                        .accessibilityLabel(String(localized: "Niveau de batterie sur la période conservée", bundle: L10n.bundle))
                    if let last = history.samples.last {
                        Text("\(last.percentage) % · \(last.date.formatted(date: .omitted, time: .shortened))").font(.caption).monospacedDigit()
                    }
                }
                Section(String(localized: "Température", bundle: L10n.bundle)) {
                    if temperaturePoints.isEmpty {
                        Text(String(localized: "Mesure indisponible", bundle: L10n.bundle)).foregroundStyle(.secondary)
                    } else {
                    Chart(temperaturePoints) { point in
                        LineMark(x: .value("Date", point.date), y: .value(TemperatureDisplay.unitSuffix, point.value),
                                 series: .value("Session", point.series))
                            .foregroundStyle(AppPalette.power)
                        PointMark(x: .value("Date", point.date), y: .value(TemperatureDisplay.unitSuffix, point.value))
                            .foregroundStyle(AppPalette.power).symbolSize(7)
                    }.frame(height: 110)
                    }
                    Text(String(localized: "Les interruptions de mesure ne sont pas interpolées. Les losanges signalent les pauses thermiques demandées par l’app, sans prouver une coupure matérielle immédiate.", bundle: L10n.bundle))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section(String(localized: "Derniers changements", bundle: L10n.bundle)) {
                    ForEach(Array(events.suffix(8).reversed())) { sample in
                        HStack {
                            Text(sample.date.formatted(date: history.retentionDays > 1 ? .abbreviated : .omitted, time: .shortened)).monospacedDigit()
                            Spacer()
                            Text(ChargingMode(rawValue: sample.mode)?.localizedTitle ?? "—")
                            Image(systemName: sample.plugged ? "powerplug" : "battery.50percent")
                                .accessibilityLabel(sample.plugged ? String(localized: "Chargeur branché", bundle: L10n.bundle) : String(localized: "Sur batterie", bundle: L10n.bundle))
                        }.font(.caption)
                    }
                }
                Button(String(localized: "Effacer l’historique…", bundle: L10n.bundle), role: .destructive) { confirmClear = true }
            }
            if let error = history.error { Text(error).font(.caption).foregroundStyle(AppPalette.warning) }
        }.formStyle(.grouped)
            .confirmationDialog(String(localized: "Effacer les relevés locaux ?", bundle: L10n.bundle), isPresented: $confirmClear) {
                Button(String(localized: "Effacer", bundle: L10n.bundle), role: .destructive) { history.clear() }
                Button(String(localized: "Annuler", bundle: L10n.bundle), role: .cancel) {}
            }
    }

    private var plotSamples: [BatteryHistorySample] {
        let samples = history.samples
        let stride = max(1, Int(ceil(Double(samples.count) / 1440)))
        return samples.enumerated().filter { index, sample in
            if index == 0 || index == samples.count - 1 || index % stride == 0 { return true }
            let previous = samples[index - 1], next = samples[index + 1]
            return sample.segment != previous.segment || sample.segment != next.segment ||
                (sample.temperature == nil) != (previous.temperature == nil) ||
                (sample.temperature == nil) != (next.temperature == nil) ||
                sample.mode != previous.mode || sample.mode != next.mode
        }.map(\.element)
    }

    private struct TemperaturePoint: Identifiable {
        var id: Date { date }
        let date: Date
        let value: Double
        let series: String
    }
    private var temperaturePoints: [TemperaturePoint] {
        var gap = 0
        return plotSamples.compactMap { sample in
            guard let temperature = sample.temperature else { gap += 1; return nil }
            return TemperaturePoint(date: sample.date, value: TemperatureDisplay.toDisplay(temperature), series: "\(sample.segment)-\(gap)")
        }
    }
}
