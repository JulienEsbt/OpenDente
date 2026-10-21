import SwiftUI

/// Native menu-bar dashboard. Requested hardware changes remain visibly pending.
struct PopoverView: View {
    @ObservedObject var battery = BatteryService.shared
    @ObservedObject var charging = ChargingManager.shared
    @ObservedObject var settings = AppSettings.shared
    @Environment(\.openSettings) private var openSettingsAction

    private var state: BatteryState { battery.batteryState }
    private var hasReading: Bool { state != .unknown }
    private var displayPercentage: Int {
        state.effectivePercentage(useHardware: settings.useHardwareBatteryPercentage)
    }

    static func adapterVisible(isPluggedIn: Bool, mode: ChargingMode) -> Bool {
        isPluggedIn || mode == .discharging
    }

    static func canDischarge(isPluggedIn: Bool, percentage: Int, chargeLimit: Int,
                             isHelperInstalled: Bool, chargingAPI: SMCChargingAPI) -> Bool {
        isPluggedIn && percentage > chargeLimit && isHelperInstalled && chargingAPI != .unknown
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    batterySummary
                    availabilityMessage
                    ChargeControlsView(charging: charging, settings: settings, state: state)
                    if settings.showPowerFlow && hasReading {
                        PowerFlowView(battery: state, mode: charging.mode)
                            .accessibilityLabel("Alimentation du Mac et de la batterie")
                    }
                    BatteryDetailsView(battery: battery, charging: charging, settings: settings)
                }
                .padding(16)
            }
            Divider()
            footer
        }
        .frame(width: 360, height: 640)
        .tint(.teal)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "leaf")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.teal)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("OpenDente").font(.headline)
                Text("Édition personnelle").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: openSettings) {
                Image(systemName: "slider.horizontal.3").frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .help("Ouvrir les réglages")
            .accessibilityLabel("Réglages d’OpenDente")
            .keyboardShortcut(",", modifiers: .command)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var batterySummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 16) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(hasReading ? "\(displayPercentage)" : "—")
                        .font(.system(size: 44, weight: .medium, design: .rounded))
                        .monospacedDigit()
                    if hasReading { Text("%").font(.title3).foregroundStyle(.secondary) }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(hasReading ? "Batterie : \(displayPercentage) pour cent" : "Lecture de la batterie en cours")
                VStack(alignment: .leading, spacing: 4) {
                    Label(statusTitle, systemImage: statusIcon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(statusColor)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(statusDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            GeometryReader { geometry in
                let fill = CGFloat(min(100, max(0, displayPercentage))) / 100
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(nsColor: .quaternarySystemFill))
                    Capsule().fill(statusColor)
                        .frame(width: hasReading ? geometry.size.width * fill : 0)
                    Rectangle().fill(Color.primary)
                        .frame(width: 2, height: 12)
                        .offset(x: geometry.size.width * CGFloat(charging.activeChargeLimit) / 100 - 1)
                }
            }
            .frame(height: 8)
            .accessibilityHidden(true)
            HStack {
                Text(state.isPluggedIn || charging.mode == .discharging ? "Chargeur branché" : "Sur batterie")
                Spacer()
                Text("Repère : \(charging.activeChargeLimit) %")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .opacity(hasReading ? 1 : 0)
        }
    }

    @ViewBuilder
    private var availabilityMessage: some View {
        if !charging.isHelperInstalled {
            let helperStatus = charging.helperServiceStatus
            let needsApproval = helperStatus == .requiresApproval
            let canRetry = helperStatus == .enabled
            notice(
                title: needsApproval ? "Autorisation nécessaire" : "Contrôle de charge indisponible",
                text: charging.helperConnectionIssue ?? (needsApproval
                    ? "Autorise OpenDente dans les éléments d’ouverture de macOS."
                    : "Vérifie le service de contrôle dans les réglages d’OpenDente."),
                button: needsApproval ? "Autoriser…" : (canRetry ? "Réessayer" : "Configurer…")
            ) {
                if needsApproval { HelperInstaller.openSystemSettings() }
                else if canRetry { charging.connectToHelper() }
                else { openSettings() }
            }
        } else if charging.nativeLimitAvailable {
            notice(title: "Mode natif expérimental", text: charging.nativeLimitIssue ?? charging.nativePauseWarning ?? (charging.usesNativeLimit
                ? "Limite et pauses confiées à macOS. Délai possible : 1 min ; une calibration peut dépasser la consigne. Surveillance thermique quand le Mac est éveillé."
                : "Active le mode natif dans les réglages Charge. Les commandes SMC ne sont pas disponibles sur ce Mac."), button: "Réglages…", action: openSettings)
        } else if charging.chargingAPI == .unknown {
            notice(title: "Contrôle indisponible", text: "L’interface de charge de ce Mac n’est pas encore détectée.", button: "Réglages…", action: openSettings)
        }
        if charging.systemChargeLimitConflict {
            notice(title: "Limite macOS active", text: "Le réglage de macOS empêche actuellement la charge demandée.", button: "Batterie…") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.Battery-Settings.extension") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    private func notice(title: String, text: String, button: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: "exclamationmark.triangle")
                .font(.system(size: 12, weight: .semibold))
            Text(text).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(button, action: action).controlSize(.small)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
    }

    private var footer: some View {
        HStack {
            Label("Réglages conservés sur ce Mac", systemImage: "internaldrive")
                .font(.caption2).foregroundStyle(.secondary)
            Spacer()
            Button("Quitter") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.borderless)
                .font(.caption)
                .help("Quitter et demander le rétablissement de la charge par macOS")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var statusTitle: String {
        if !hasReading { return "Lecture en cours…" }
        if charging.systemChargeLimitConflict { return "Limite macOS" }
        if !charging.chargeControlAvailable {
            return state.isCharging ? "Charge en cours" : "Lecture seule"
        }
        if [.paused, .sailing, .heatProtection].contains(charging.mode), state.isCharging {
            return "Arrêt de charge demandé"
        }
        if [.charging, .topUp].contains(charging.mode), !state.isCharging {
            return displayPercentage >= 100 ? "Batterie chargée" : "Charge en attente"
        }
        return charging.mode.frenchTitle
    }

    private var statusDetail: String {
        if !hasReading { return "Les données apparaîtront ici." }
        if charging.nativeLimitAvailable {
            if !charging.usesNativeLimit { return "Suivi de batterie — contrôle désactivé." }
            if let issue = charging.nativeLimitIssue ?? charging.nativePauseWarning { return issue }
            if charging.isPreparingStorage { return StoragePreparationControls.detail(state, mode: charging.mode) }
            if !state.isPluggedIn { return "Réglages conservés pour le prochain branchement." }
            guard let target = charging.nativeLimitTarget else { return "Consigne native en attente de confirmation." }
            if charging.mode == .heatProtection {
                return state.isCharging
                    ? "Pause thermique demandée ; macOS charge encore."
                    : "Charge arrêtée. Reprise après refroidissement de 2 °C et délai de 5 min."
            }
            if [.paused, .sailing].contains(charging.mode) {
                if state.isCharging { return "Pause demandée à macOS ; la batterie charge encore." }
                if displayPercentage > settings.chargeLimit { return "Maintien à \(target) %. Baisse naturelle vers \(settings.chargeLimit) %, sans décharge forcée." }
                return settings.sailingModeEnabled ? "Charge arrêtée. Reprise sous \(settings.sailingLowerBound) %." : "Charge arrêtée à la limite habituelle."
            }
            return "Objectif macOS : \(target) %. \(state.isCharging ? "La batterie charge." : "Reprise de charge en attente.")"
        }
        if !charging.chargeControlAvailable { return "Les commandes d’OpenDente sont indisponibles." }
        if charging.systemChargeLimitConflict { return "Vérifie les réglages Batterie." }
        if charging.mode == .heatProtection {
            return state.isCharging ? "Protection thermique : arrêt à confirmer." : "Reprise après refroidissement et délai de 5 min."
        }
        if [.paused, .sailing].contains(charging.mode), state.isCharging { return "La batterie reçoit encore de l’énergie." }
        switch charging.mode {
        case .charging: return "Objectif : \(settings.chargeLimit) %."
        case .topUp: return "100 % jusqu’au débranchement."
        case .paused, .sailing:
            return settings.sailingModeEnabled ? "Reprise sous \(settings.sailingLowerBound) %." : "Reprise sous \(settings.chargeLimit) %."
        case .discharging: return "Décharge vers \(settings.chargeLimit) %."
        case .onBattery: return "Limite appliquée au prochain branchement."
        case .idle: return "En attente de l’état de charge."
        case .calibrating: return "Cycle en cours."
        case .heatProtection: return "Refroidissement en cours."
        }
    }

    private var statusIcon: String {
        charging.systemChargeLimitConflict ? "exclamationmark.triangle" : charging.mode.statusBarIcon
    }

    private var statusColor: Color {
        if charging.systemChargeLimitConflict || charging.mode == .heatProtection { return .orange }
        if !hasReading || !charging.chargeControlAvailable { return .secondary }
        if displayPercentage <= 20 || charging.mode == .discharging { return .orange }
        return .teal
    }

    private func openSettings() {
        openSettingsAction()
        NSApp.activate()
    }
}
