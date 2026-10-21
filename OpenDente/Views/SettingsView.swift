import SwiftUI
import ServiceManagement
import UserNotifications
import os.log

/// Settings window with tabbed interface
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("Général", systemImage: "gear") }

            ChargingTab()
                .tabItem { Label("Charge", systemImage: "bolt.fill") }

            NotificationsTab()
                .tabItem { Label("Notifications", systemImage: "bell") }

            StatusBarTab()
                .tabItem { Label("Barre des menus", systemImage: "menubar.rectangle") }

            PopoverItemsTab()
                .tabItem { Label("Panneau", systemImage: "list.bullet") }

            BatteryInfoTab()
                .tabItem { Label("Batterie", systemImage: "battery.100percent") }
        }
        .frame(width: 560, height: 620)
    }
}

// MARK: - General Tab

struct GeneralTab: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var charging = ChargingManager.shared
    @State private var helperRegistrationFailed = false

    var body: some View {
        Form {
            Section {
                Toggle("Ouvrir à la connexion", isOn: $settings.launchAtLogin)
                    .onChange(of: settings.launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                    }
            }

            Section {
                LabeledContent("Version") {
                    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
                    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
                    Text("\(version) (\(build))")
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            Section("Service de contrôle") {
                LabeledContent("État") {
                    Text(helperStatusText)
                        .foregroundStyle(charging.isHelperInstalled ? .green : .orange)
                }

                if !charging.isHelperInstalled {
                    helperActions

                    if let issue = charging.helperConnectionIssue {
                        Text(issue)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    Text("Le contrôle de charge nécessite un service autorisé par macOS. Il s’exécute avec les droits administrateur pour communiquer avec la batterie.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private var helperActions: some View {
        let status = HelperInstaller.status
        if status == .requiresApproval {
            Button("Ouvrir les Réglages Système") {
                HelperInstaller.openSystemSettings()
            }
            Text("Autorise OpenDente dans les éléments d’ouverture de macOS.")
                .font(.caption)
                .foregroundStyle(.orange)
        } else if status == .enabled {
            Button("Réessayer la connexion") { charging.connectToHelper() }
            Button("Réinstaller le service") {
                charging.resetToDefaultsSync()
                HelperClient.shared.disconnect()
                helperRegistrationFailed = false
                if HelperInstaller.unregister() && HelperInstaller.register() {
                    charging.connectToHelper()
                } else if HelperInstaller.status != .requiresApproval {
                    helperRegistrationFailed = true
                }
            }
            if helperRegistrationFailed {
                Text("La réinstallation a échoué. Vérifie l’autorisation dans les éléments d’ouverture de macOS.")
                    .font(.caption).foregroundStyle(.orange)
            }
        } else {
            Button("Activer le service") {
                helperRegistrationFailed = false
                if HelperInstaller.register() {
                    charging.connectToHelper()
                } else if HelperInstaller.status != .requiresApproval {
                    helperRegistrationFailed = true
                }
            }
            if helperRegistrationFailed {
                Text("Le service n’a pas pu être activé. Vérifie la signature de l’application et son emplacement, puis consulte le diagnostic.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var helperStatusText: String {
        switch HelperInstaller.status {
        case .enabled: return "Activé"
        case .notRegistered: return "Non activé"
        case .requiresApproval: return "Autorisation nécessaire"
        case .notFound: return "Service absent de l’application"
        @unknown default: return "État inconnu"
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Logger(subsystem: "com.opendente.app", category: "Settings").error("Failed to set launch at login: \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - Notifications Tab

struct NotificationsTab: View {
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        Form {
            Section {
                Toggle("Activer les notifications", isOn: $settings.showNotifications)
            }

            Section("Événements") {
                Toggle("Limite de charge atteinte", isOn: $settings.notifyChargeLimitReached)
                Toggle("Charge ponctuelle terminée (100 %)", isOn: $settings.notifyTopUpComplete)
                Toggle("Protection thermique active", isOn: $settings.notifyHeatProtection)
                Toggle("Décharge terminée", isOn: $settings.notifyDischargeComplete)
            }
            .disabled(!settings.showNotifications)

            #if DEBUG
            Section("Test") {
                Button("Envoyer une notification de test") {
                    sendTestNotification()
                }
            }
            #endif
        }
        .formStyle(.grouped)
    }

    #if DEBUG
    private func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Test OpenDente"
        content.body = "Les notifications fonctionnent."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "com.opendente.test.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
    #endif
}

// MARK: - Charging Tab

struct ChargingTab: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var charging = ChargingManager.shared

    var body: some View {
        Form {
            Section("Limite de charge") {
                HStack {
                    Text("Limite")
                    Slider(
                        value: Binding(
                            get: { Double(settings.chargeLimit) },
                            set: { settings.chargeLimit = Int(($0 / 5).rounded() * 5) }
                        ),
                        in: 20...100
                    )
                    .accessibilityLabel("Limite habituelle de charge")
                    Text("\(settings.chargeLimit)%")
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 45, alignment: .trailing)
                }
            }

            Section("Seuil de reprise") {
                Toggle("Espacer les reprises de charge", isOn: $settings.sailingModeEnabled)

                if settings.sailingModeEnabled {
                    HStack {
                        Text("Écart souhaité")
                        Slider(
                            value: Binding(
                                get: { Double(settings.sailingRange) },
                                set: { settings.sailingRange = Int($0.rounded()) }
                            ),
                            in: 2...25
                        )
                        .accessibilityLabel("Écart entre la limite et le seuil de reprise")
                        Text("\(settings.sailingRange)%")
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 35, alignment: .trailing)
                    }
                    Text("Reprise sous \(settings.sailingLowerBound) %. Le seuil reste au minimum à 10 %. Le niveau baisse naturellement ; aucune décharge n’est nécessaire.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Protection thermique") {
                Toggle("Activer la protection thermique", isOn: $settings.heatProtectionEnabled)

                if settings.heatProtectionEnabled {
                    HStack {
                        Text("Température maximale")
                        Slider(
                            value: Binding(
                                get: { TemperatureDisplay.toDisplay(settings.heatProtectionTemp) },
                                set: {
                                    let step = TemperatureDisplay.sliderStep
                                    let snapped = ($0 / step).rounded() * step
                                    settings.heatProtectionTemp = TemperatureDisplay.toCelsius(snapped)
                                }
                            ),
                            in: TemperatureDisplay.sliderRange
                        )
                        .accessibilityLabel("Température maximale de la batterie")
                        Text(TemperatureDisplay.format(settings.heatProtectionTemp, fractionDigits: 0))
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 50, alignment: .trailing)
                    }
                }
            }

            Section("Options avancées") {
                Toggle("Décharger automatiquement vers la limite", isOn: $settings.automaticDischarge)
                Text("Désactivé dans les profils : laisser le niveau baisser naturellement évite une décharge imposée.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Personnaliser le voyant MagSafe", isOn: $settings.controlMagSafeLED)
                if settings.controlMagSafeLED {
                    Toggle("Éteindre le voyant quand la charge est suspendue", isOn: $settings.magSafeLEDOffWhenInactive)
                        .padding(.leading, 16)
                    Text(settings.magSafeLEDOffWhenInactive
                         ? "Voyant éteint à la limite, orange pendant la charge."
                         : "Voyant vert à la limite, orange pendant la charge.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 16)
                } else {
                    Text("Le voyant du connecteur MagSafe reste géré par macOS. Aucun effet sur un câble USB-C.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Toggle("Suspendre la charge pendant la veille", isOn: $settings.stopChargingWhenSleeping)
                Text("Demande l’arrêt de la charge avant la veille. Le comportement doit être vérifié sur ton Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Empêcher la veille automatique jusqu’à la limite", isOn: $settings.disableSleepUntilChargeLimit)
                Text("Maintient le Mac éveillé pendant la charge ou la décharge vers la limite.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Utiliser le pourcentage matériel de la batterie", isOn: $settings.useHardwareBatteryPercentage)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Status Bar Tab

struct StatusBarTab: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var battery = BatteryService.shared
    @ObservedObject var charging = ChargingManager.shared

    var body: some View {
        Form {
            Section("Afficher dans la barre des menus") {
                Toggle("Pourcentage de batterie", isOn: $settings.statusBarShowPercentage)
                Toggle("Température", isOn: $settings.statusBarShowTemperature)
                Toggle("Consommation électrique", isOn: $settings.statusBarShowPower)
                Toggle("Icône du mode de charge", isOn: $settings.statusBarShowMode)
            }

            Section {
                Text("Aperçu :")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Image(systemName: statusBarIcon)
                        .font(.system(size: 15))
                    if !statusBarPreview.isEmpty {
                        Text(statusBarPreview)
                            .font(.system(size: 13, design: .monospaced))
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
            }
        }
        .formStyle(.grouped)
    }

    private var statusBarIcon: String {
        let state = battery.batteryState
        let pct = state.effectivePercentage(useHardware: settings.useHardwareBatteryPercentage)
        return settings.statusBarShowMode
            ? charging.mode.batteryIconName(percentage: pct, isCharging: state.isCharging)
            : ChargingMode.idle.batteryIconName(percentage: pct, isCharging: false)
    }

    private var statusBarPreview: String {
        let state = battery.batteryState
        let pct = state.effectivePercentage(useHardware: settings.useHardwareBatteryPercentage)
        return state.statusBarText(
            effectivePercentage: pct,
            showPercentage: settings.statusBarShowPercentage,
            showTemperature: settings.statusBarShowTemperature,
            showPower: settings.statusBarShowPower
        )
    }
}

// MARK: - Popover Items Tab

struct PopoverItemsTab: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var enabledItems: [PopoverDetailItem] = []
    @State private var disabledItems: [PopoverDetailItem] = []

    var body: some View {
        VStack(spacing: 0) {
            Text("Fais glisser les mesures pour les réordonner. Le bouton œil les affiche ou les masque.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 6)

            List {
                Section {
                    Toggle("Afficher les flux d’énergie", isOn: $settings.showPowerFlow)
                }

                Section("Affiché") {
                    ForEach(enabledItems) { item in
                        PopoverItemRow(item: item, isEnabled: true) {
                            disableItem(item)
                        }
                    }
                    .onMove { from, to in
                        enabledItems.move(fromOffsets: from, toOffset: to)
                        save()
                    }
                }

                Section("Masqué") {
                    ForEach(disabledItems) { item in
                        PopoverItemRow(item: item, isEnabled: false) {
                            enableItem(item)
                        }
                    }
                }
            }
        }
        .onAppear { load() }
    }

    private func load() {
        enabledItems = settings.popoverDetailItems
        let enabledSet = Set(enabledItems.map(\.rawValue))
        disabledItems = PopoverDetailItem.allCases.filter { !enabledSet.contains($0.rawValue) }
    }

    private func save() {
        settings.popoverDetailItems = enabledItems
    }

    private func disableItem(_ item: PopoverDetailItem) {
        enabledItems.removeAll { $0 == item }
        disabledItems.append(item)
        save()
    }

    private func enableItem(_ item: PopoverDetailItem) {
        disabledItems.removeAll { $0 == item }
        enabledItems.append(item)
        save()
    }
}

struct PopoverItemRow: View {
    let item: PopoverDetailItem
    let isEnabled: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.icon)
                .font(.system(size: 12))
                .foregroundStyle(isEnabled ? .primary : .secondary)
                .frame(width: 18)

            Text(item.frenchTitle)
                .foregroundStyle(isEnabled ? .primary : .secondary)

            Spacer()

            Button(action: onToggle) {
                Image(systemName: isEnabled ? "eye.fill" : "eye.slash")
                    .font(.system(size: 12))
                    .foregroundStyle(isEnabled ? .blue : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(isEnabled ? "Masquer" : "Afficher") \(item.frenchTitle)")
        }
    }
}

// MARK: - Battery Info Tab

struct BatteryInfoTab: View {
    @ObservedObject var battery = BatteryService.shared
    @ObservedObject var charging = ChargingManager.shared

    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        let state = battery.batteryState

        Form {
            Section("Batterie") {
                infoRow("Pourcentage macOS", value: "\(state.percentage)%")
                validatedRow("Pourcentage matériel", raw: state.hardwarePercentage, format: { "\($0)%" })
                if let current = state.currentCapacity, let max = state.maxCapacity {
                    validatedRow("Capacité", value: "\(current) / \(max) mAh",
                                 warn: max < 500 || max > 20000 || current < 0 || current > max * 11 / 10)
                }
                validatedRow("Capacité de conception", raw: state.designCapacity, format: { "\($0) mAh" },
                             warn: { $0 < 500 || $0 > 20000 })
                if let health = state.healthPercentage {
                    validatedRow("Capacité maximale", value: String(format: "%.1f%%", health),
                                 warn: health < 0 || health > 120)
                }
                validatedRow("Cycles", raw: state.cycleCount, format: { "\($0)" },
                             warn: { $0 < 0 || $0 >= 10000 })
                validatedRow("Température", raw: state.temperature,
                             format: { TemperatureDisplay.format($0) },
                             warn: { $0 < -20 || $0 > 100 })
            }

            Section("Puissance de la batterie") {
                infoRow("Source", value: state.isPluggedIn ? "Chargeur" : "Batterie")
                validatedRow("Tension de la batterie", raw: state.voltage,
                             format: { String(format: "%.2f V", $0) },
                             warn: { $0 < 1 || $0 > 30 })
                validatedRow("Courant de la batterie", raw: state.amperage,
                             format: { String(format: "%.3f A", $0) },
                             warn: { abs($0) > 10 })
                validatedRow("Puissance de la batterie", raw: state.batteryPower,
                             format: { String(format: "%.1f W", $0) },
                             warn: { abs($0) > 200 })
            }

            Section("Puissance du Mac") {
                validatedRow("Puissance du Mac", raw: state.systemPower,
                             format: { String(format: "%.1f W", $0) },
                             warn: { $0 < 0 || $0 > 200 })
                validatedRow("Puissance du chargeur", raw: state.adapterPower,
                             format: { String(format: "%.1f W", $0) },
                             warn: { $0 < 0 || $0 > 200 })
            }

            if PopoverView.adapterVisible(isPluggedIn: state.isPluggedIn, mode: charging.mode), let adapter = state.adapterInfo {
                Section("Chargeur") {
                    infoRow("Nom", value: adapter.name)
                    if let desc = adapter.description {
                        infoRow("Description", value: desc)
                    }
                    if let mfr = adapter.manufacturer {
                        infoRow("Fabricant", value: mfr)
                    }
                    if let model = adapter.model {
                        infoRow("Modèle", value: model)
                    }
                    infoRow("Puissance nominale", value: "\(adapter.watts) W")
                    validatedRow("Tension", raw: adapter.voltage,
                                 format: { String(format: "%.2f V", $0) },
                                 warn: { $0 < 1 || $0 > 30 })
                    validatedRow("Courant", raw: adapter.current,
                                 format: { String(format: "%.3f A", $0) },
                                 warn: { abs($0) > 10 })
                    if !adapter.usbPDProfiles.isEmpty {
                        infoRow("Protocole", value: "USB-PD")
                    }
                    if let serial = adapter.serial {
                        infoRow("Numéro de série", value: serial)
                    }
                    if let firmware = adapter.firmware {
                        infoRow("Micrologiciel", value: firmware)
                    }
                    if adapter.isWireless {
                        infoRow("Sans fil", value: "Oui")
                    }
                }

                if !adapter.usbPDProfiles.isEmpty {
                    Section("Profils USB-PD") {
                        ForEach(Array(adapter.usbPDProfiles.enumerated()), id: \.offset) { index, profile in
                            HStack {
                                Text(String(format: "%.0fV \u{00D7} %.2fA (%dW)",
                                            profile.voltage, profile.current, profile.watts))
                                    .font(.system(.body, design: .monospaced))
                                Spacer()
                                if index == adapter.activeProfileIndex {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                    }
                }

                if let reason = state.notChargingReason, reason != 0 {
                    Section {
                        infoRow("Motif d’arrêt de charge", value: String(format: "0x%016llX", reason))
                    }
                }
            }

            Section("Contrôle") {
                infoRow("Mode", value: charging.mode.frenchTitle)
                infoRow("Interface de charge", value: chargingAPIName)
                if settings.controlMagSafeLED {
                    infoRow("Voyant MagSafe", value: ledColorName)
                }
                infoRow("Accès aux mesures SMC", value: battery.smcAvailable ? "Oui" : "Non")
                if let version = charging.helperVersion {
                    infoRow("Version du service", value: version)
                }
            }

            Section {
                Button("Exporter un diagnostic…") {
                    DiagnosticExporter.exportWithSavePanel()
                }
                Text("Enregistre les informations du système, l’état actuel, les réglages et les journaux récents dans un fichier texte local.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var chargingAPIName: String {
        switch charging.chargingAPI {
        case .legacy: return "Historique (CH0B/CH0C)"
        case .tahoe:  return "Tahoe (CHTE/CHIE)"
        case .unknown: return "Non détectée"
        }
    }

    private var ledColorName: String {
        switch charging.lastLEDColor {
        case HelperConstants.ledAuto:   return "Auto"
        case HelperConstants.ledOff:    return "Éteint"
        case HelperConstants.ledGreen:  return "Vert"
        case HelperConstants.ledOrange: return "Orange"
        default: return charging.lastLEDColor.map { String(format: "0x%02X", $0) } ?? "–"
        }
    }

    private func infoRow(_ label: String, value: String) -> some View {
        LabeledContent(label) {
            Text(value)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
        }
    }

    /// Show a value with warning if out of expected range, or "–" if unavailable
    private func validatedRow<T>(_ label: String, raw: T?, format: (T) -> String, warn: ((T) -> Bool)? = nil) -> some View {
        LabeledContent(label) {
            if let val = raw {
                let isWarning = warn?(val) ?? false
                Text(format(val))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(isWarning ? .orange : .primary)
                    .textSelection(.enabled)
            } else {
                Text("–")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Overload for pre-formatted string values
    private func validatedRow(_ label: String, value: String, warn: Bool) -> some View {
        LabeledContent(label) {
            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(warn ? .orange : .primary)
                .textSelection(.enabled)
        }
    }
}
