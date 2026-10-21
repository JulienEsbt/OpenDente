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
            Text("Mesures de la batterie")
                .font(.system(size: 12, weight: .semibold))
            ForEach(settings.popoverDetailItems) { item in
                if let row = detailValue(for: item, state: battery.batteryState) {
                    detailRow(row.label, value: row.value)
                        .accessibilityElement(children: .combine)
                }
            }
            if !battery.smcAvailable {
                Label("Certaines mesures ne sont pas disponibles.", systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func detailValue(for item: PopoverDetailItem, state: BatteryState) -> (label: String, value: String)? {
        switch item {
        case .temperature:
            guard let temp = state.temperature else { return nil }
            return ("Température", TemperatureDisplay.format(temp))
        case .batteryHealth:
            guard let health = state.healthPercentage else { return nil }
            return ("Capacité maximale", String(format: "%.1f%%", health))
        case .cycleCount:
            guard let cycles = state.cycleCount else { return nil }
            return ("Cycles", "\(cycles)")
        case .timeRemaining:
            return charging.mode.frenchTimeRemainingDisplay(
                chargeLimit: settings.chargeLimit,
                percentage: displayPercentage,
                timeToFull: state.timeToFull,
                timeToEmpty: state.timeToEmpty
            )
        case .systemPower:
            guard let power = state.systemPower, power > 0 else { return nil }
            return ("Puissance du Mac", String(format: "%.1f W", power))
        case .adapterPower:
            guard adapterVisible, let power = state.adapterPower, power > 0 else { return nil }
            if let max = state.adapterInfo?.watts, max > 0 {
                return ("Puissance du chargeur", String(format: "%.1f W sur %d W", power, max))
            }
            return ("Puissance du chargeur", String(format: "%.1f W", power))
        case .adapterName:
            guard adapterVisible, let info = state.adapterInfo else { return nil }
            return ("Chargeur", info.name)
        case .adapterManufacturer:
            guard adapterVisible, let mfr = state.adapterInfo?.manufacturer else { return nil }
            return ("Fabricant", mfr)
        case .adapterModel:
            guard adapterVisible, let model = state.adapterInfo?.model else { return nil }
            return ("Modèle", model)
        case .adapterSerial:
            guard adapterVisible, let serial = state.adapterInfo?.serial else { return nil }
            return ("Numéro de série", serial)
        case .adapterVoltage:
            guard adapterVisible, let info = state.adapterInfo else { return nil }
            return ("Tension du chargeur", String(format: "%.2f V", info.voltage))
        case .adapterCurrent:
            guard adapterVisible, let info = state.adapterInfo else { return nil }
            return ("Courant du chargeur", String(format: "%.3f A", info.current))
        case .voltage:
            guard let voltage = state.voltage else { return nil }
            return ("Tension de la batterie", String(format: "%.2f V", voltage))
        case .amperage:
            guard let amperage = state.amperage else { return nil }
            return ("Courant de la batterie", String(format: "%.3f A", amperage))
        case .currentCapacity:
            guard let current = state.currentCapacity, let max = state.maxCapacity else { return nil }
            return ("Capacité", "\(current) / \(max) mAh")
        case .designCapacity:
            guard let design = state.designCapacity else { return nil }
            return ("Capacité de conception", "\(design) mAh")
        case .batteryPower:
            guard let power = state.batteryPower else { return nil }
            return ("Puissance de la batterie", String(format: "%.1f W", power))
        case .notChargingReason:
            guard let reason = state.notChargingReason, reason != 0 else { return nil }
            return ("Motif d’arrêt de charge", String(format: "0x%016llX", reason))
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
