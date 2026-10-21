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
    @State private var loginEnabled = false
    @State private var loginIssue: String?


    var body: some View {
        Form {
            Section {
                Toggle("Ouvrir à la connexion", isOn: Binding(
                    get: { loginEnabled }, set: { setLaunchAtLogin($0) }))
                if let loginIssue { Text(loginIssue).font(.caption).foregroundStyle(.orange) }
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
        .onAppear {
            loginEnabled = SMAppService.mainApp.status == .enabled
            settings.launchAtLogin = loginEnabled
        }
        .task {
            while !Task.isCancelled {
                charging.refreshHelperStatus()
                do { try await Task.sleep(for: .seconds(2)) } catch { break }
            }
        }
    }

    @ViewBuilder
    private var helperActions: some View {
        let status = charging.helperServiceStatus
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
        if charging.isHelperInstalled { return charging.nativeLimitAvailable ? "Connecté — mode natif disponible" : "Connecté" }
        switch charging.helperServiceStatus {
        case .enabled: return "Activé"
        case .notRegistered: return "Non activé"
        case .requiresApproval: return "Autorisation nécessaire"
        case .notFound: return HelperInstaller.bundleIsComplete ? "Non enregistré" : "Service absent de l’application"
        @unknown default: return "État inconnu"
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        loginIssue = nil
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            loginIssue = "macOS n’a pas enregistré cette modification : " + error.localizedDescription
        }
        loginEnabled = SMAppService.mainApp.status == .enabled
        settings.launchAtLogin = loginEnabled
        if enabled && SMAppService.mainApp.status == .requiresApproval {
            loginIssue = "Autorise OpenDente dans les éléments d’ouverture des Réglages Système."
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
            if charging.nativeLimitAvailable {
                Section("Contrôle expérimental — macOS 27") {
                    Toggle("Activer le contrôle de charge", isOn: $settings.nativeChargeLimitEnabled)
                    Text(settings.nativeChargeLimitEnabled
                         ? "Limite, seuil de reprise et pause thermique actifs. Les demandes passent par le service de charge de macOS, avec un délai pouvant approcher une minute."
                         : "Configure les seuils ci-dessous, puis active le contrôle pour les appliquer. Le suivi de batterie fonctionne aussi sans contrôle.")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("macOS peut dépasser une consigne pour sa calibration. Une demande de pause n’est pas une coupure de sécurité immédiate : vérifie l’état réel dans le panneau.")
                        .font(.caption).foregroundStyle(.secondary)
                    if let issue = charging.nativeLimitIssue ?? charging.nativePauseWarning {
                        Text(issue).font(.caption).foregroundStyle(.orange)
                    }
                }
            }
            Section("Limite de charge") {
                HStack {
                    Text("Arrêter à")
                    Slider(value: Binding(
                        get: { Double(settings.chargeLimit) },
                        set: { settings.chargeLimit = Int($0.rounded()) }
                    ), in: 20...100, step: 1)
                    .accessibilityLabel("Limite habituelle de charge")
                    Text("\(settings.chargeLimit) %").monospacedDigit().frame(width: 50, alignment: .trailing)
                }
                Text("Si la batterie dépasse déjà cette limite, elle baisse naturellement. Aucune décharge forcée n’est nécessaire.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Seuil de reprise") {
                Toggle("Choisir quand la charge reprend", isOn: $settings.sailingModeEnabled)
                if settings.sailingModeEnabled {
                    HStack {
                        Text("Reprendre sous")
                        Slider(value: Binding(
                            get: { Double(settings.sailingLowerBound) },
                            set: { settings.sailingRange = settings.chargeLimit - Int($0.rounded()) }
                        ), in: 10...Double(settings.chargeLimit - 2), step: 1)
                        .accessibilityLabel("Seuil de reprise de la charge")
                        Text("\(settings.sailingLowerBound) %").monospacedDigit().frame(width: 50, alignment: .trailing)
                    }
                    Text("Exemple : arrêt à \(settings.chargeLimit) %, puis attente jusqu’à moins de \(settings.sailingLowerBound) %. Une fois reprise, la charge continue jusqu’au plafond. La baisse reste naturelle, surtout lorsque tu débranches le Mac.")
                        .font(.caption).foregroundStyle(.secondary)
                    if charging.nativeLimitAvailable {
                        Text("Mode expérimental : OpenDente ajuste le plafond au niveau courant pendant l’attente. La reprise peut être retardée ou contournée par macOS ; aucun seuil exact n’est garanti pendant la veille.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Section("Pause thermique supplémentaire") {
                Toggle("Demander une pause si la batterie chauffe", isOn: $settings.heatProtectionEnabled)
                if settings.heatProtectionEnabled {
                    HStack {
                        Text("Température de la batterie")
                        Slider(value: Binding(
                            get: { TemperatureDisplay.toDisplay(settings.heatProtectionTemp) },
                            set: { settings.heatProtectionTemp = TemperatureDisplay.toCelsius(($0 / TemperatureDisplay.sliderStep).rounded() * TemperatureDisplay.sliderStep) }
                        ), in: TemperatureDisplay.sliderRange)
                        .accessibilityLabel("Température maximale de la batterie")
                        Text(TemperatureDisplay.format(settings.heatProtectionTemp, fractionDigits: 0))
                            .monospacedDigit().frame(width: 50, alignment: .trailing)
                    }
                    Text(charging.nativeLimitAvailable
                         ? "Reprise après au moins 5 min sans dépassement et une baisse de 2 °C. La charge ponctuelle à 100 % attend aussi le refroidissement. La température est surveillée tant que le Mac est éveillé."
                         : "Reprise après refroidissement et 5 min sans dépassement. La charge ponctuelle attend aussi le refroidissement.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text("Apple recommande une température ambiante de 10 à 35 °C. Ce réglage utilise le capteur interne de la batterie : 40 °C est un choix de précaution de l’app, pas un seuil publié par Apple. Les protections intégrées de macOS restent actives.")
                    .font(.caption).foregroundStyle(.secondary)
                if charging.nativeLimitAvailable {
                    Text("Demande différée, sans garantie d’arrêt immédiat. Sous 20 % de batterie, ce moteur ne peut pas tenir exactement le niveau courant.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("Fonctionnement en arrière-plan") {
                Toggle("Empêcher la veille automatique jusqu’à la limite", isOn: $settings.disableSleepUntilChargeLimit)
                Text("Le panneau peut rester fermé. Cette option retarde seulement la veille automatique pendant la charge ; fermer le capot reste une demande de veille.")
                    .font(.caption).foregroundStyle(.secondary)
                if charging.nativeLimitAvailable {
                    Text("Pendant la veille, macOS conserve le dernier plafond transmis. OpenDente réévalue les seuils et la température au réveil. Désactiver le contrôle ou quitter l’app restaure le réglage Apple sauvegardé.")
                        .font(.caption).foregroundStyle(.secondary)
                    DisclosureGroup("Autres commandes du moteur SMC") {
                        Text("La décharge forcée, le voyant MagSafe, le pourcentage matériel pour la régulation et la pause dédiée à la veille ne sont pas proposés par ce moteur natif. Les anciens réglages SMC sont conservés pour les Mac compatibles.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    Toggle("Décharger automatiquement vers la limite", isOn: $settings.automaticDischarge)
                    Toggle("Personnaliser le voyant MagSafe", isOn: $settings.controlMagSafeLED)
                    if settings.controlMagSafeLED {
                        Toggle("Éteindre le voyant pendant une pause", isOn: $settings.magSafeLEDOffWhenInactive)
                    }
                    Toggle("Suspendre la charge pendant la veille", isOn: $settings.stopChargingWhenSleeping)
                    Toggle("Utiliser le pourcentage matériel pour la régulation", isOn: $settings.useHardwareBatteryPercentage)
                }
            }
            Section("Repères pour préserver la batterie") {
                Text("Au bureau, une limite à 80 % avec reprise sous 75 % se rapproche du comportement natif Apple. Attendre 20 % n’est pas nécessaire pour entretenir une batterie lithium-ion. Utilise 100 % quand tu as besoin d’autonomie, sans forcer des cycles de décharge.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Appliquer 80 % / reprise sous 75 %") {
                    settings.chargeLimit = 80
                    settings.sailingRange = 5
                    settings.sailingModeEnabled = true
                    settings.automaticDischarge = false
                }
                Link("Limite de charge : explications d’Apple", destination: URL(string: "https://support.apple.com/fr-fr/102338")!)
                Link("Températures : recommandations d’Apple", destination: URL(string: "https://support.apple.com/fr-fr/102336")!)
                Link("Vieillissement lithium-ion : Battery University", destination: URL(string: "https://batteryuniversity.com/article/bu-808-how-to-prolong-lithium-based-batteries")!)
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
