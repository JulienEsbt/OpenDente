import SwiftUI

/// Native menu-bar dashboard. Requested hardware changes remain visibly pending.
struct PopoverView: View {
    @ObservedObject var battery = BatteryService.shared
    @ObservedObject var charging = ChargingManager.shared
    @ObservedObject var settings = AppSettings.shared
    @State private var showsNativeInfo = false
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
                            .accessibilityLabel(String(localized: "Alimentation du Mac et de la batterie", bundle: L10n.bundle))
                    }
                    BatteryDetailsView(battery: battery, charging: charging, settings: settings)
                }
                .padding(16)
            }
            Divider()
            footer
        }
        .frame(width: 360, height: 640)
        .tint(AppPalette.accent)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "leaf")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(AppPalette.accent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("OpenDente").font(.headline)
                if charging.nativeLimitAvailable {
                    Button { showsNativeInfo.toggle() } label: {
                        Label(charging.usesNativeLimit ? String(localized: "Contrôle macOS", bundle: L10n.bundle) : String(localized: "Suivi uniquement", bundle: L10n.bundle), systemImage: "info.circle")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(String(localized: "Comprendre le contrôle natif expérimental", bundle: L10n.bundle))
                    .popover(isPresented: $showsNativeInfo) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(String(localized: "Contrôle natif expérimental", bundle: L10n.bundle)).font(.headline)
                            Text(String(localized: "OpenDente confie ses consignes à macOS via une interface Apple privée, susceptible de changer. Une demande peut prendre plusieurs minutes ; macOS peut dépasser le plafond pour sa jauge.", bundle: L10n.bundle))
                            Text(String(localized: "En veille, macOS garde la dernière consigne. Les mesures et la pause thermique de l’app reprennent au réveil. À l’arrêt, OpenDente restitue le réglage Apple sauvegardé.", bundle: L10n.bundle))
                            Button(String(localized: "Réglages…", bundle: L10n.bundle)) { showsNativeInfo = false; openSettings() }
                        }
                        .font(.caption).padding(16).frame(width: 280)
                    }
                } else {
                    Text(String(localized: "Édition personnelle", bundle: L10n.bundle)).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(action: openSettings) {
                Image(systemName: "slider.horizontal.3").frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .help(String(localized: "Ouvrir les réglages", bundle: L10n.bundle))
            .accessibilityLabel(String(localized: "Réglages d’OpenDente", bundle: L10n.bundle))
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
                .accessibilityLabel(hasReading ? String(localized: "Batterie : \(displayPercentage) pour cent", bundle: L10n.bundle) : String(localized: "Lecture de la batterie en cours", bundle: L10n.bundle))
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
                Text(state.isPluggedIn || charging.mode == .discharging ? String(localized: "Chargeur branché", bundle: L10n.bundle) : String(localized: "Sur batterie", bundle: L10n.bundle))
                Spacer()
                Text(String(localized: "Repère : \(charging.activeChargeLimit) %", bundle: L10n.bundle))
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
                title: needsApproval ? String(localized: "Autorisation nécessaire", bundle: L10n.bundle) : String(localized: "Contrôle de charge indisponible", bundle: L10n.bundle),
                text: charging.helperConnectionIssue ?? (needsApproval
                    ? String(localized: "Autorise OpenDente dans les éléments d’ouverture de macOS.", bundle: L10n.bundle)
                    : String(localized: "Vérifie le service de contrôle dans les réglages d’OpenDente.", bundle: L10n.bundle)),
                button: needsApproval ? String(localized: "Autoriser…", bundle: L10n.bundle) : (canRetry ? String(localized: "Réessayer", bundle: L10n.bundle) : String(localized: "Configurer…", bundle: L10n.bundle))
            ) {
                if needsApproval { HelperInstaller.openSystemSettings() }
                else if canRetry { charging.connectToHelper() }
                else { openSettings() }
            }
        } else if charging.nativeLimitAvailable {
            if let issue = charging.nativeLimitIssue ?? charging.nativePauseWarning {
                notice(title: String(localized: "Contrôle à vérifier", bundle: L10n.bundle), text: issue, button: String(localized: "Réglages…", bundle: L10n.bundle), action: openSettings)
            }
        } else if charging.chargingAPI == .unknown {
            notice(title: String(localized: "Contrôle indisponible", bundle: L10n.bundle), text: String(localized: "L’interface de charge de ce Mac n’est pas encore détectée.", bundle: L10n.bundle), button: String(localized: "Réglages…", bundle: L10n.bundle), action: openSettings)
        }
        if charging.systemChargeLimitConflict {
            notice(title: String(localized: "Limite macOS active", bundle: L10n.bundle), text: String(localized: "Le réglage de macOS empêche actuellement la charge demandée.", bundle: L10n.bundle), button: String(localized: "Batterie…", bundle: L10n.bundle)) {
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
            Label(String(localized: "Réglages conservés sur ce Mac", bundle: L10n.bundle), systemImage: "internaldrive")
                .font(.caption2).foregroundStyle(.secondary)
            Spacer()
            Button(String(localized: "Quitter", bundle: L10n.bundle)) { NSApplication.shared.terminate(nil) }
                .buttonStyle(.borderless)
                .font(.caption)
                .help(String(localized: "Quitter et demander le rétablissement de la charge par macOS", bundle: L10n.bundle))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var statusTitle: String {
        if !hasReading { return String(localized: "Lecture en cours…", bundle: L10n.bundle) }
        if charging.systemChargeLimitConflict { return String(localized: "Limite macOS", bundle: L10n.bundle) }
        if !charging.chargeControlAvailable {
            return state.isCharging ? String(localized: "Charge en cours", bundle: L10n.bundle) : String(localized: "Lecture seule", bundle: L10n.bundle)
        }
        if [.paused, .sailing, .heatProtection].contains(charging.mode), state.isCharging {
            return String(localized: "Arrêt de charge demandé", bundle: L10n.bundle)
        }
        if [.charging, .topUp].contains(charging.mode), !state.isCharging {
            return displayPercentage >= 100 ? String(localized: "Batterie chargée", bundle: L10n.bundle) : String(localized: "Charge en attente", bundle: L10n.bundle)
        }
        return charging.mode.localizedTitle
    }

    private var statusDetail: String {
        if !hasReading { return String(localized: "Les données apparaîtront ici.", bundle: L10n.bundle) }
        if charging.nativeLimitAvailable {
            if !charging.usesNativeLimit { return String(localized: "Suivi de batterie — contrôle désactivé.", bundle: L10n.bundle) }
            if let issue = charging.nativeLimitIssue ?? charging.nativePauseWarning { return issue }
            if charging.isPreparingStorage { return StoragePreparationControls.detail(state, mode: charging.mode) }
            if !state.isPluggedIn { return String(localized: "Réglages conservés pour le prochain branchement.", bundle: L10n.bundle) }
            guard let target = charging.nativeLimitTarget else { return String(localized: "Consigne native en attente de confirmation.", bundle: L10n.bundle) }
            if charging.mode == .heatProtection {
                return state.isCharging
                    ? String(localized: "Pause thermique demandée ; macOS charge encore.", bundle: L10n.bundle)
                    : String(localized: "Charge arrêtée. Reprise après refroidissement de 2 °C et délai de 5 min.", bundle: L10n.bundle)
            }
            if charging.mode == .discharging {
                return (state.amperage ?? 0) < -0.05
                    ? String(localized: "Descente sur secteur vers \(settings.chargeLimit) %. Puis maintien, sans cycle forcé.", bundle: L10n.bundle)
                    : String(localized: "Retour à \(settings.chargeLimit) % demandé. Décharge non encore confirmée.", bundle: L10n.bundle)
            }
            if [.paused, .sailing].contains(charging.mode) {
                if state.isCharging { return String(localized: "Pause demandée à macOS ; la batterie charge encore.", bundle: L10n.bundle) }
                if displayPercentage > settings.chargeLimit { return String(localized: "Maintien à \(target) %. Baisse naturelle vers \(settings.chargeLimit) %, sans décharge forcée.", bundle: L10n.bundle) }
                return settings.sailingModeEnabled ? String(localized: "Charge arrêtée. Reprise sous \(settings.sailingLowerBound) %.", bundle: L10n.bundle) : String(localized: "Charge arrêtée à la limite habituelle.", bundle: L10n.bundle)
            }
            return String(localized: "Objectif macOS : \(target) %. \(state.isCharging ? String(localized: "La batterie charge.", bundle: L10n.bundle) : String(localized: "Reprise de charge en attente.", bundle: L10n.bundle))", bundle: L10n.bundle)
        }
        if !charging.chargeControlAvailable { return String(localized: "Les commandes d’OpenDente sont indisponibles.", bundle: L10n.bundle) }
        if charging.systemChargeLimitConflict { return String(localized: "Vérifie les réglages Batterie.", bundle: L10n.bundle) }
        if charging.mode == .heatProtection {
            return state.isCharging ? String(localized: "Protection thermique : arrêt à confirmer.", bundle: L10n.bundle) : String(localized: "Reprise après refroidissement et délai de 5 min.", bundle: L10n.bundle)
        }
        if [.paused, .sailing].contains(charging.mode), state.isCharging { return String(localized: "La batterie reçoit encore de l’énergie.", bundle: L10n.bundle) }
        switch charging.mode {
        case .charging: return String(localized: "Objectif : \(settings.chargeLimit) %.", bundle: L10n.bundle)
        case .topUp: return String(localized: "100 % jusqu’au débranchement.", bundle: L10n.bundle)
        case .paused, .sailing:
            return settings.sailingModeEnabled ? String(localized: "Reprise sous \(settings.sailingLowerBound) %.", bundle: L10n.bundle) : String(localized: "Reprise sous \(settings.chargeLimit) %.", bundle: L10n.bundle)
        case .discharging: return String(localized: "Décharge vers \(settings.chargeLimit) %.", bundle: L10n.bundle)
        case .onBattery: return String(localized: "Limite appliquée au prochain branchement.", bundle: L10n.bundle)
        case .idle: return String(localized: "En attente de l’état de charge.", bundle: L10n.bundle)
        case .calibrating: return String(localized: "Cycle en cours.", bundle: L10n.bundle)
        case .heatProtection: return String(localized: "Refroidissement en cours.", bundle: L10n.bundle)
        }
    }

    private var statusIcon: String {
        charging.systemChargeLimitConflict ? "exclamationmark.triangle" : charging.mode.statusBarIcon
    }

    private var statusColor: Color {
        if charging.systemChargeLimitConflict || charging.mode == .heatProtection { return AppPalette.warning }
        if !hasReading || !charging.chargeControlAvailable { return .secondary }
        if displayPercentage <= 20 || charging.mode == .discharging { return AppPalette.warning }
        return AppPalette.accent
    }

    private func openSettings() {
        openSettingsAction()
        NSApp.activate()
    }
}
