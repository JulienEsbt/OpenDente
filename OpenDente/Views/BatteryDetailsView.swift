import SwiftUI

/// The user's selected live measurements; unavailable measurements stay absent.
struct BatteryDetailsView: View {
    @ObservedObject var battery: BatteryService
    @ObservedObject var charging: ChargingManager
    @ObservedObject var settings: AppSettings

    private var displayPercentage: Int {
        battery.batteryState.effectivePercentage(useHardware: settings.useHardwareBatteryPercentage)
    }

    private var adapterVisible: Bool {
        PopoverView.adapterVisible(isPluggedIn: battery.batteryState.isPluggedIn, mode: charging.mode)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Mesures de la batterie", bundle: L10n.bundle))
                .font(.system(size: 12, weight: .semibold))
            ForEach(settings.popoverDetailItems) { item in
                if let row = detailValue(for: item, state: battery.batteryState) {
                    detailRow(row.label, value: row.value)
                        .accessibilityElement(children: .combine)
                }
            }
            if !battery.smcAvailable {
                Label(String(localized: "Certaines mesures ne sont pas disponibles.", bundle: L10n.bundle), systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func detailValue(for item: PopoverDetailItem, state: BatteryState) -> (label: String, value: String)? {
        switch item {
        case .temperature:
            guard let temp = state.temperature else { return nil }
            return (String(localized: "Température", bundle: L10n.bundle), TemperatureDisplay.format(temp))
        case .batteryHealth:
            guard let health = state.healthPercentage else { return nil }
            return (String(localized: "Capacité maximale", bundle: L10n.bundle), String(format: "%.1f%%", health))
        case .cycleCount:
            guard let cycles = state.cycleCount else { return nil }
            return (String(localized: "Cycles", bundle: L10n.bundle), "\(cycles)")
        case .timeRemaining:
            return charging.mode.localizedTimeRemainingDisplay(
                chargeLimit: settings.chargeLimit,
                percentage: displayPercentage,
                timeToFull: state.timeToFull,
                timeToEmpty: state.timeToEmpty
            )
        case .systemPower:
            guard let power = state.systemPower, power > 0 else { return nil }
            return (String(localized: "Puissance du Mac", bundle: L10n.bundle), String(format: "%.1f W", power))
        case .adapterPower:
            guard adapterVisible, let power = state.adapterPower, power > 0 else { return nil }
            if let max = state.adapterInfo?.watts, max > 0 {
                return (String(localized: "Puissance du chargeur", bundle: L10n.bundle), String(format: String(localized: "%.1f W sur %d W", bundle: L10n.bundle), power, max))
            }
            return (String(localized: "Puissance du chargeur", bundle: L10n.bundle), String(format: "%.1f W", power))
        case .adapterName:
            guard adapterVisible, let info = state.adapterInfo else { return nil }
            return (String(localized: "Chargeur", bundle: L10n.bundle), info.name)
        case .adapterManufacturer:
            guard adapterVisible, let mfr = state.adapterInfo?.manufacturer else { return nil }
            return (String(localized: "Fabricant", bundle: L10n.bundle), mfr)
        case .adapterModel:
            guard adapterVisible, let model = state.adapterInfo?.model else { return nil }
            return (String(localized: "Modèle", bundle: L10n.bundle), model)
        case .adapterSerial:
            guard adapterVisible, let serial = state.adapterInfo?.serial else { return nil }
            return (String(localized: "Numéro de série", bundle: L10n.bundle), serial)
        case .adapterVoltage:
            guard adapterVisible, let info = state.adapterInfo else { return nil }
            return (String(localized: "Tension du chargeur", bundle: L10n.bundle), String(format: "%.2f V", info.voltage))
        case .adapterCurrent:
            guard adapterVisible, let info = state.adapterInfo else { return nil }
            return (String(localized: "Courant du chargeur", bundle: L10n.bundle), String(format: "%.3f A", info.current))
        case .voltage:
            guard let voltage = state.voltage else { return nil }
            return (String(localized: "Tension de la batterie", bundle: L10n.bundle), String(format: "%.2f V", voltage))
        case .amperage:
            guard let amperage = state.amperage else { return nil }
            return (String(localized: "Courant de la batterie", bundle: L10n.bundle), String(format: "%.3f A", amperage))
        case .currentCapacity:
            guard let current = state.currentCapacity, let max = state.maxCapacity else { return nil }
            return (String(localized: "Capacité", bundle: L10n.bundle), "\(current) / \(max) mAh")
        case .designCapacity:
            guard let design = state.designCapacity else { return nil }
            return (String(localized: "Capacité de conception", bundle: L10n.bundle), "\(design) mAh")
        case .batteryPower:
            guard let power = state.batteryPower else { return nil }
            return (String(localized: "Puissance de la batterie", bundle: L10n.bundle), String(format: "%.1f W", power))
        case .notChargingReason:
            guard let reason = state.notChargingReason, reason != 0 else { return nil }
            return (String(localized: "Motif d’arrêt de charge", bundle: L10n.bundle), String(format: "0x%016llX", reason))
        }
    }

    private func detailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
    }

}
