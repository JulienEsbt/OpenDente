import SwiftUI
import ServiceManagement
import UserNotifications
import os.log

/// Settings window with tabbed interface
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label(String(localized: "Général", bundle: L10n.bundle), systemImage: "gear") }

            ChargingTab()
                .tabItem { Label(String(localized: "Charge", bundle: L10n.bundle), systemImage: "bolt.fill") }

            NotificationsTab()
                .tabItem { Label(String(localized: "Notifications", bundle: L10n.bundle), systemImage: "bell") }

            StatusBarTab()
                .tabItem { Label(String(localized: "Barre des menus", bundle: L10n.bundle), systemImage: "menubar.rectangle") }

            PopoverItemsTab()
                .tabItem { Label(String(localized: "Panneau", bundle: L10n.bundle), systemImage: "list.bullet") }

            BatteryInfoTab()
                .tabItem { Label(String(localized: "Batterie", bundle: L10n.bundle), systemImage: "battery.100percent") }
            GuideTab()
                .tabItem { Label(String(localized: "Guide", bundle: L10n.bundle), systemImage: "book.closed") }
        }
        .frame(width: 620, height: 640)
    }
}

// MARK: - General Tab

struct GeneralTab: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var charging = ChargingManager.shared
    @ObservedObject private var language = LanguageSettings.shared
    @State private var helperRegistrationFailed = false
    @State private var loginEnabled = false
    @State private var loginIssue: String?


    var body: some View {
        Form {
            Section {
                Picker(String(localized: "Langue de l’interface", bundle: L10n.bundle), selection: $language.selection) {
                    ForEach(AppLanguage.allCases) { choice in
                        Text(choice.title).tag(choice)
                    }
                }
                Text(String(localized: "Le changement est immédiat et ne modifie pas les réglages de charge.", bundle: L10n.bundle))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Toggle(String(localized: "Ouvrir à la connexion", bundle: L10n.bundle), isOn: Binding(
                    get: { loginEnabled }, set: { setLaunchAtLogin($0) }))
                    .help(String(localized: "Démarrer discrètement dans la barre des menus, sans ouvrir le panneau ni les réglages", bundle: L10n.bundle))
                if let loginIssue { Text(loginIssue).font(.caption).foregroundStyle(AppPalette.warning) }
            }

            Section {
                LabeledContent(String(localized: "Version", bundle: L10n.bundle)) {
                    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
                    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
                    Text("\(version) (\(build))")
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            Section(String(localized: "Service de contrôle", bundle: L10n.bundle)) {
                LabeledContent(String(localized: "État", bundle: L10n.bundle)) {
                    Text(helperStatusText)
                        .foregroundStyle(charging.isHelperInstalled ? AppPalette.positive : AppPalette.warning)
                }

                if !charging.isHelperInstalled {
                    helperActions

                    if let issue = charging.helperConnectionIssue {
                        Text(issue)
                            .font(.caption)
                            .foregroundStyle(AppPalette.warning)
                    }

                    Text(String(localized: "Le contrôle de charge nécessite un service autorisé par macOS. Il s’exécute avec les droits administrateur pour communiquer avec la batterie.", bundle: L10n.bundle))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            loginEnabled = SMAppService.mainApp.status == .enabled
            if settings.launchAtLogin != loginEnabled { settings.launchAtLogin = loginEnabled }
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
            Button(String(localized: "Ouvrir les Réglages Système", bundle: L10n.bundle)) {
                HelperInstaller.openSystemSettings()
            }
            Text(String(localized: "Autorise OpenDente dans les éléments d’ouverture de macOS.", bundle: L10n.bundle))
                .font(.caption)
                .foregroundStyle(AppPalette.warning)
        } else if status == .enabled {
            Button(String(localized: "Réessayer la connexion", bundle: L10n.bundle)) { charging.connectToHelper() }
            Button(String(localized: "Réinstaller le service", bundle: L10n.bundle)) {
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
                Text(String(localized: "La réinstallation a échoué. Vérifie l’autorisation dans les éléments d’ouverture de macOS.", bundle: L10n.bundle))
                    .font(.caption).foregroundStyle(AppPalette.warning)
            }
        } else {
            Button(String(localized: "Activer le service", bundle: L10n.bundle)) {
                helperRegistrationFailed = false
                if HelperInstaller.register() {
                    charging.connectToHelper()
                } else if HelperInstaller.status != .requiresApproval {
                    helperRegistrationFailed = true
                }
            }
            if helperRegistrationFailed {
                Text(String(localized: "Le service n’a pas pu être activé. Vérifie la signature de l’application et son emplacement, puis consulte le diagnostic.", bundle: L10n.bundle))
                    .font(.caption)
                    .foregroundStyle(AppPalette.warning)
            }
        }
    }

    private var helperStatusText: String {
        if charging.isHelperInstalled { return charging.nativeLimitAvailable ? String(localized: "Connecté — mode natif disponible", bundle: L10n.bundle) : String(localized: "Connecté", bundle: L10n.bundle) }
        switch charging.helperServiceStatus {
        case .enabled: return String(localized: "Activé", bundle: L10n.bundle)
        case .notRegistered: return String(localized: "Non activé", bundle: L10n.bundle)
        case .requiresApproval: return String(localized: "Autorisation nécessaire", bundle: L10n.bundle)
        case .notFound: return HelperInstaller.bundleIsComplete ? String(localized: "Non enregistré", bundle: L10n.bundle) : String(localized: "Service absent de l’application", bundle: L10n.bundle)
        @unknown default: return String(localized: "État inconnu", bundle: L10n.bundle)
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        loginIssue = nil
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            loginIssue = String(localized: "macOS n’a pas enregistré cette modification : ", bundle: L10n.bundle) + error.localizedDescription
        }
        loginEnabled = SMAppService.mainApp.status == .enabled
        settings.launchAtLogin = loginEnabled
        if enabled && SMAppService.mainApp.status == .requiresApproval {
            loginIssue = String(localized: "Autorise OpenDente dans les éléments d’ouverture des Réglages Système.", bundle: L10n.bundle)
        }
    }

}

// MARK: - Notifications Tab

struct NotificationsTab: View {
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        Form {
            Section {
                Toggle(String(localized: "Activer les notifications", bundle: L10n.bundle), isOn: $settings.showNotifications)
            }

            Section(String(localized: "Événements", bundle: L10n.bundle)) {
                Toggle(String(localized: "Limite de charge atteinte", bundle: L10n.bundle), isOn: $settings.notifyChargeLimitReached)
                Toggle(String(localized: "Charge ponctuelle terminée (100 %)", bundle: L10n.bundle), isOn: $settings.notifyTopUpComplete)
                Toggle(String(localized: "Protection thermique active", bundle: L10n.bundle), isOn: $settings.notifyHeatProtection)
                Toggle(String(localized: "Décharge terminée", bundle: L10n.bundle), isOn: $settings.notifyDischargeComplete)
            }
            .disabled(!settings.showNotifications)

            #if DEBUG
            Section(String(localized: "Test", bundle: L10n.bundle)) {
                Button(String(localized: "Envoyer une notification de test", bundle: L10n.bundle)) {
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
        content.title = String(localized: "Test OpenDente", bundle: L10n.bundle)
        content.body = String(localized: "Les notifications fonctionnent.", bundle: L10n.bundle)
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
    @ObservedObject var battery = BatteryService.shared

    var body: some View {
        Form {
            if charging.nativeLimitAvailable {
                Section(String(localized: "Contrôle expérimental — macOS 27", bundle: L10n.bundle)) {
                    Toggle(String(localized: "Activer le contrôle de charge", bundle: L10n.bundle), isOn: $settings.nativeChargeLimitEnabled)
                    Text(settings.nativeChargeLimitEnabled
                         ? String(localized: "Limite, seuil de reprise et pause thermique actifs. Les demandes passent par le service de charge de macOS, avec un délai pouvant atteindre plusieurs minutes.", bundle: L10n.bundle)
                         : String(localized: "Configure les seuils ci-dessous, puis active le contrôle pour les appliquer. Le suivi de batterie fonctionne aussi sans contrôle.", bundle: L10n.bundle))
                        .font(.caption).foregroundStyle(.secondary)
                    Text(String(localized: "macOS peut dépasser une consigne pour sa calibration. Une demande de pause n’est pas une coupure de sécurité immédiate : vérifie l’état réel dans le panneau.", bundle: L10n.bundle))
                        .font(.caption).foregroundStyle(.secondary)
                    if let issue = charging.nativeLimitIssue ?? charging.nativePauseWarning {
                        Text(issue).font(.caption).foregroundStyle(AppPalette.warning)
                    }
                }
            }
            Section(String(localized: "Limite de charge", bundle: L10n.bundle)) {
                HStack {
                    Text(String(localized: "Arrêter à", bundle: L10n.bundle))
                    Slider(value: Binding(
                        get: { Double(settings.chargeLimit) },
                        set: { settings.storagePreparationEnabled = false; settings.chargeLimit = Int($0.rounded()) }
                    ), in: 20...100, step: 1)
                    .accessibilityLabel(String(localized: "Limite habituelle de charge", bundle: L10n.bundle))
                    Text(String(localized: "\(settings.chargeLimit) %", bundle: L10n.bundle)).monospacedDigit().frame(width: 50, alignment: .trailing)
                }
                if charging.nativeLimitAvailable {
                    Toggle(String(localized: "Redescendre au plafond sur secteur", bundle: L10n.bundle), isOn: $settings.nativeReturnToLimitEnabled)
                    Text(settings.nativeReturnToLimitEnabled
                         ? String(localized: "Au lancement, au branchement ou après un changement de limite, un niveau trop élevé redescend vers le plafond choisi. Ensuite le Mac reste alimenté par le secteur ; aucun cycle continu n’est forcé.", bundle: L10n.bundle)
                         : String(localized: "Au-dessus du plafond, le niveau reste maintenu et baisse naturellement à l’usage. Active le retour au plafond pour demander une descente sur secteur.", bundle: L10n.bundle))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Section(String(localized: "Seuil de reprise", bundle: L10n.bundle)) {
                Toggle(String(localized: "Choisir quand la charge reprend", bundle: L10n.bundle), isOn: $settings.sailingModeEnabled)
                if settings.sailingModeEnabled {
                    HStack {
                        Text(String(localized: "Reprendre sous", bundle: L10n.bundle))
                        Slider(value: Binding(
                            get: { Double(settings.sailingLowerBound) },
                            set: { settings.sailingRange = settings.chargeLimit - Int($0.rounded()) }
                        ), in: 10...Double(settings.chargeLimit - 2), step: 1)
                        .accessibilityLabel(String(localized: "Seuil de reprise de la charge", bundle: L10n.bundle))
                        Text(String(localized: "\(settings.sailingLowerBound) %", bundle: L10n.bundle)).monospacedDigit().frame(width: 50, alignment: .trailing)
                    }
                    Text(String(localized: "Exemple : arrêt à \(settings.chargeLimit) %, puis attente jusqu’à moins de \(settings.sailingLowerBound) %. Une fois reprise, la charge continue jusqu’au plafond. La baisse reste naturelle, surtout lorsque tu débranches le Mac.", bundle: L10n.bundle))
                        .font(.caption).foregroundStyle(.secondary)
                    if charging.nativeLimitAvailable {
                        Text(String(localized: "Mode expérimental : OpenDente ajuste le plafond au niveau courant pendant l’attente. La reprise peut être retardée ou contournée par macOS ; aucun seuil exact n’est garanti pendant la veille.", bundle: L10n.bundle))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Section(String(localized: "Pause thermique supplémentaire", bundle: L10n.bundle)) {
                Toggle(String(localized: "Demander une pause si la batterie chauffe", bundle: L10n.bundle), isOn: $settings.heatProtectionEnabled)
                if settings.heatProtectionEnabled {
                    HStack {
                        Text(String(localized: "Température de la batterie", bundle: L10n.bundle))
                        Slider(value: Binding(
                            get: { TemperatureDisplay.toDisplay(settings.heatProtectionTemp) },
                            set: { settings.heatProtectionTemp = TemperatureDisplay.toCelsius(($0 / TemperatureDisplay.sliderStep).rounded() * TemperatureDisplay.sliderStep) }
                        ), in: TemperatureDisplay.sliderRange)
                        .accessibilityLabel(String(localized: "Température maximale de la batterie", bundle: L10n.bundle))
                        Text(TemperatureDisplay.format(settings.heatProtectionTemp, fractionDigits: 0))
                            .monospacedDigit().frame(width: 50, alignment: .trailing)
                    }
                    Text(charging.nativeLimitAvailable
                         ? String(localized: "Reprise après au moins 5 min sans dépassement et une baisse de 2 °C. La charge ponctuelle à 100 % attend aussi le refroidissement. La température est surveillée tant que le Mac est éveillé.", bundle: L10n.bundle)
                         : String(localized: "Reprise après refroidissement et 5 min sans dépassement. La charge ponctuelle attend aussi le refroidissement.", bundle: L10n.bundle))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text(String(localized: "Apple recommande une température ambiante de 10 à 35 °C. Ce réglage utilise le capteur interne de la batterie : 40 °C est un choix de précaution de l’app, pas un seuil publié par Apple. Les protections intégrées de macOS restent actives.", bundle: L10n.bundle))
                    .font(.caption).foregroundStyle(.secondary)
                if charging.nativeLimitAvailable {
                    Text(String(localized: "Demande différée, sans garantie d’arrêt immédiat. Sous 20 % de batterie, ce moteur ne peut pas tenir exactement le niveau courant.", bundle: L10n.bundle))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Section(String(localized: "Fonctionnement en arrière-plan", bundle: L10n.bundle)) {
                Toggle(String(localized: "Empêcher la veille automatique jusqu’à la limite", bundle: L10n.bundle), isOn: $settings.disableSleepUntilChargeLimit)
                Text(String(localized: "Le panneau peut rester fermé. Cette option retarde seulement la veille automatique pendant la charge ; fermer le capot reste une demande de veille.", bundle: L10n.bundle))
                    .font(.caption).foregroundStyle(.secondary)
                if charging.nativeLimitAvailable {
                    Text(String(localized: "Panneau fermé : OpenDente continue en arrière-plan. Mac en veille : ses mesures s’arrêtent, mais macOS conserve la dernière consigne. La veille ne retire pas la limite et ne demande pas 100 %. Au réveil, les contrôles reprennent. Quitter l’app ou éteindre le Mac demande la restauration de la limite Apple précédente.", bundle: L10n.bundle))
                        .font(.caption).foregroundStyle(.secondary)
                    DisclosureGroup(String(localized: "Autres commandes du moteur SMC", bundle: L10n.bundle)) {
                        Text(String(localized: "Le pourcentage matériel pour la régulation et la pause SMC dédiée à la veille ne sont pas proposés par ce moteur natif. Les anciens réglages SMC sont conservés pour les Mac compatibles.", bundle: L10n.bundle))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    Toggle(String(localized: "Décharger automatiquement vers la limite", bundle: L10n.bundle), isOn: $settings.automaticDischarge)
                    Toggle(String(localized: "Personnaliser le voyant MagSafe", bundle: L10n.bundle), isOn: $settings.controlMagSafeLED)
                    if settings.controlMagSafeLED {
                        Toggle(String(localized: "Éteindre le voyant pendant une pause", bundle: L10n.bundle), isOn: $settings.magSafeLEDOffWhenInactive)
                    }
                    Toggle(String(localized: "Suspendre la charge pendant la veille", bundle: L10n.bundle), isOn: $settings.stopChargingWhenSleeping)
                    Toggle(String(localized: "Utiliser le pourcentage matériel pour la régulation", bundle: L10n.bundle), isOn: $settings.useHardwareBatteryPercentage)
                }
            }
            Section(String(localized: "Repères pour préserver la batterie", bundle: L10n.bundle)) {
                Text(String(localized: "Au bureau, une limite à 80 % avec reprise sous 75 % se rapproche du comportement natif Apple. Attendre 20 % n’est pas nécessaire pour entretenir une batterie lithium-ion. Utilise 100 % quand tu as besoin d’autonomie, sans forcer des cycles de décharge.", bundle: L10n.bundle))
                    .font(.caption).foregroundStyle(.secondary)
                Button(String(localized: "Appliquer 80 % / reprise sous 75 %", bundle: L10n.bundle)) {
                    settings.storagePreparationEnabled = false
                    settings.chargeLimit = 80
                    settings.sailingRange = 5
                    settings.sailingModeEnabled = true
                    settings.automaticDischarge = false
                }
                Link(String(localized: "Limite de charge : explications d’Apple", bundle: L10n.bundle), destination: L10n.documentationURL("https://support.apple.com/fr-fr/102338"))
                Link(String(localized: "Températures : recommandations d’Apple", bundle: L10n.bundle), destination: L10n.documentationURL("https://support.apple.com/fr-fr/102336"))
                Link(String(localized: "Vieillissement lithium-ion : Battery University", bundle: L10n.bundle), destination: URL(string: "https://batteryuniversity.com/article/bu-808-how-to-prolong-lithium-based-batteries")!)
            }
            Section(String(localized: "Stockage prolongé", bundle: L10n.bundle)) {
                if charging.nativeLimitAvailable {
                    StoragePreparationControls(charging: charging, settings: settings, state: battery.batteryState)
                }
                DisclosureGroup(String(localized: "Préparer le Mac autour de 50 %", bundle: L10n.bundle)) {
                    if battery.batteryState == .unknown {
                        Label(String(localized: "En attente d’une mesure de batterie.", bundle: L10n.bundle), systemImage: "battery.50percent")
                    } else if (45...55).contains(battery.batteryState.percentage) {
                        Label(String(localized: "\(battery.batteryState.percentage) % : niveau proche de 50 %.", bundle: L10n.bundle), systemImage: "checkmark.circle")
                            .foregroundStyle(AppPalette.positive)
                    } else if battery.batteryState.percentage > 55 {
                        Label(String(localized: "\(battery.batteryState.percentage) % : débranche et utilise normalement le Mac jusqu’à environ 50 %.", bundle: L10n.bundle), systemImage: "battery.50percent")
                    } else {
                        Label(String(localized: "\(battery.batteryState.percentage) % : recharge jusqu’à environ 50 %, puis débranche.", bundle: L10n.bundle), systemImage: "battery.50percent")
                    }
                    Text(String(localized: "1. Vise environ 50 % avant une longue inutilisation. Si nécessaire, tu peux choisir un plafond de 50 % plus haut dans cette page. Remets ensuite ton plafond habituel pour l’usage quotidien.", bundle: L10n.bundle))
                    Text(String(localized: "2. Débranche le chargeur, puis éteins le Mac depuis le menu Pomme. Le mode peut préparer le niveau sur secteur ; OpenDente n’éteint pas le Mac à ta place.", bundle: L10n.bundle))
                    Text(String(localized: "3. Range-le dans un endroit frais et sec, à moins de 32 °C. Pour plus de six mois, Apple conseille de revenir à environ 50 % tous les six mois.", bundle: L10n.bundle))
                    Text(String(localized: "Une fois le Mac éteint, l’app ne peut ni surveiller le niveau ni recharger la batterie. La zone 45–55 % affichée ici est un repère pratique autour de 50 %, pas une plage officielle Apple.", bundle: L10n.bundle))
                        .foregroundStyle(.secondary)
                    Link(String(localized: "Stockage : recommandations d’Apple", bundle: L10n.bundle), destination: L10n.documentationURL("https://www.apple.com/fr/batteries/maximizing-performance/"))
                }
                .font(.callout)
            }
            Section(String(localized: "Voyant MagSafe", bundle: L10n.bundle)) {
                if charging.nativeLimitAvailable {
                    MagSafeLEDControls(charging: charging, settings: settings)
                } else {
                    Text(String(localized: "Les réglages de voyant du moteur SMC restent dans Fonctionnement en arrière-plan.", bundle: L10n.bundle))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Section(String(localized: "MagSafe et USB-C", bundle: L10n.bundle)) {
                DisclosureGroup(String(localized: "Comprendre le chargeur et son voyant", bundle: L10n.bundle)) {
                    Text(String(localized: "Le contrôle vise la batterie interne : il est conçu pour fonctionner avec MagSafe comme avec une alimentation USB-C Power Delivery adaptée. Un chargeur trop faible peut laisser la batterie se décharger malgré le branchement.", bundle: L10n.bundle))
                    Text(charging.nativeLimitAvailable
                         ? String(localized: "Par défaut, macOS gère le voyant MagSafe : orange peut signifier charge en cours ou en attente. La section Voyant MagSafe permet de choisir une règle par mode et de tester les couleurs. Consulte le panneau pour connaître l’état réel de charge.", bundle: L10n.bundle)
                         : String(localized: "Sur les Mac compatibles, le réglage de voyant propose vert, orange ou éteint. Le voyant ne remplace pas les mesures de charge du panneau.", bundle: L10n.bundle))
                    Text(String(localized: "Un clignotement orange répété peut signaler un problème de charge selon Apple. OpenDente n’ajoute pas de clignotement qui pourrait masquer cet avertissement.", bundle: L10n.bundle))
                        .foregroundStyle(.secondary)
                    Link(String(localized: "Charger avec MagSafe ou USB-C", bundle: L10n.bundle), destination: L10n.documentationURL("https://support.apple.com/fr-fr/102397"))
                    Link(String(localized: "Voyant et dépannage MagSafe", bundle: L10n.bundle), destination: L10n.documentationURL("https://support.apple.com/fr-fr/102372"))
                }
                .font(.callout)
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
            Section(String(localized: "Présentation", bundle: L10n.bundle)) {
                Toggle(String(localized: "Affichage compact", bundle: L10n.bundle), isOn: $settings.compactStatusBar)
                Text(String(localized: "Pourcentage dans la batterie ; température et puissance sur deux lignes. Le survol conserve les détails.", bundle: L10n.bundle))
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section(String(localized: "Afficher dans la barre des menus", bundle: L10n.bundle)) {
                Toggle(String(localized: "Pourcentage de batterie", bundle: L10n.bundle), isOn: $settings.statusBarShowPercentage)
                Toggle(String(localized: "Température", bundle: L10n.bundle), isOn: $settings.statusBarShowTemperature)
                Toggle(String(localized: "Consommation électrique", bundle: L10n.bundle), isOn: $settings.statusBarShowPower)
                Toggle(String(localized: "Icône du mode de charge", bundle: L10n.bundle), isOn: $settings.statusBarShowMode)
            }

            Section {
                Text(String(localized: "Aperçu :", bundle: L10n.bundle))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    if settings.compactStatusBar {
                        Image(nsImage: CompactStatusBar.image(state: battery.batteryState,
                            mode: charging.mode, settings: settings))
                    } else {
                        Image(systemName: statusBarIcon).font(.system(size: 15))
                        if !statusBarPreview.isEmpty {
                            Text(statusBarPreview).font(.system(size: 13, design: .monospaced))
                        }
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
            Text(String(localized: "Fais glisser les mesures pour les réordonner. Le bouton œil les affiche ou les masque.", bundle: L10n.bundle))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 6)

            List {
                Section {
                    Toggle(String(localized: "Afficher les flux d’énergie", bundle: L10n.bundle), isOn: $settings.showPowerFlow)
                }

                Section(String(localized: "Affiché", bundle: L10n.bundle)) {
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

                Section(String(localized: "Masqué", bundle: L10n.bundle)) {
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

            Text(item.localizedTitle)
                .foregroundStyle(isEnabled ? .primary : .secondary)

            Spacer()

            Button(action: onToggle) {
                Image(systemName: isEnabled ? "eye.fill" : "eye.slash")
                    .font(.system(size: 12))
                    .foregroundStyle(isEnabled ? AppPalette.power : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "\(isEnabled ? String(localized: "Masquer", bundle: L10n.bundle) : String(localized: "Afficher", bundle: L10n.bundle)) \(item.localizedTitle)", bundle: L10n.bundle))
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
            Section(String(localized: "Batterie", bundle: L10n.bundle)) {
                infoRow(String(localized: "Pourcentage macOS", bundle: L10n.bundle), value: "\(state.percentage)%")
                validatedRow(String(localized: "Pourcentage matériel", bundle: L10n.bundle), raw: state.hardwarePercentage, format: { "\($0)%" })
                if let current = state.currentCapacity, let max = state.maxCapacity {
                    validatedRow(String(localized: "Capacité", bundle: L10n.bundle), value: "\(current) / \(max) mAh",
                                 warn: max < 500 || max > 20000 || current < 0 || current > max * 11 / 10)
                }
                validatedRow(String(localized: "Capacité de conception", bundle: L10n.bundle), raw: state.designCapacity, format: { "\($0) mAh" },
                             warn: { $0 < 500 || $0 > 20000 })
                if let health = state.healthPercentage {
                    validatedRow(String(localized: "Capacité maximale", bundle: L10n.bundle), value: String(format: "%.1f%%", health),
                                 warn: health < 0 || health > 120)
                }
                validatedRow(String(localized: "Cycles", bundle: L10n.bundle), raw: state.cycleCount, format: { "\($0)" },
                             warn: { $0 < 0 || $0 >= 10000 })
                validatedRow(String(localized: "Température", bundle: L10n.bundle), raw: state.temperature,
                             format: { TemperatureDisplay.format($0) },
                             warn: { $0 < -20 || $0 > 100 })
            }

            Section(String(localized: "Puissance de la batterie", bundle: L10n.bundle)) {
                infoRow(String(localized: "Source", bundle: L10n.bundle), value: state.isPluggedIn ? String(localized: "Chargeur", bundle: L10n.bundle) : String(localized: "Batterie", bundle: L10n.bundle))
                validatedRow(String(localized: "Tension de la batterie", bundle: L10n.bundle), raw: state.voltage,
                             format: { String(format: "%.2f V", $0) },
                             warn: { $0 < 1 || $0 > 30 })
                validatedRow(String(localized: "Courant de la batterie", bundle: L10n.bundle), raw: state.amperage,
                             format: { String(format: "%.3f A", $0) },
                             warn: { abs($0) > 10 })
                validatedRow(String(localized: "Puissance de la batterie", bundle: L10n.bundle), raw: state.batteryPower,
                             format: { String(format: "%.1f W", $0) },
                             warn: { abs($0) > 200 })
            }

            Section(String(localized: "Puissance du Mac", bundle: L10n.bundle)) {
                validatedRow(String(localized: "Puissance du Mac", bundle: L10n.bundle), raw: state.systemPower,
                             format: { String(format: "%.1f W", $0) },
                             warn: { $0 < 0 || $0 > 200 })
                validatedRow(String(localized: "Puissance du chargeur", bundle: L10n.bundle), raw: state.adapterPower,
                             format: { String(format: "%.1f W", $0) },
                             warn: { $0 < 0 || $0 > 200 })
            }

            if PopoverView.adapterVisible(isPluggedIn: state.isPluggedIn, mode: charging.mode), let adapter = state.adapterInfo {
                Section(String(localized: "Chargeur", bundle: L10n.bundle)) {
                    infoRow(String(localized: "Nom", bundle: L10n.bundle), value: adapter.name)
                    if let desc = adapter.description {
                        infoRow(String(localized: "Description", bundle: L10n.bundle), value: desc)
                    }
                    if let mfr = adapter.manufacturer {
                        infoRow(String(localized: "Fabricant", bundle: L10n.bundle), value: mfr)
                    }
                    if let model = adapter.model {
                        infoRow(String(localized: "Modèle", bundle: L10n.bundle), value: model)
                    }
                    infoRow(String(localized: "Puissance nominale", bundle: L10n.bundle), value: "\(adapter.watts) W")
                    validatedRow(String(localized: "Tension", bundle: L10n.bundle), raw: adapter.voltage,
                                 format: { String(format: "%.2f V", $0) },
                                 warn: { $0 < 1 || $0 > 30 })
                    validatedRow(String(localized: "Courant", bundle: L10n.bundle), raw: adapter.current,
                                 format: { String(format: "%.3f A", $0) },
                                 warn: { abs($0) > 10 })
                    if !adapter.usbPDProfiles.isEmpty {
                        infoRow(String(localized: "Protocole", bundle: L10n.bundle), value: "USB-PD")
                    }
                    if let serial = adapter.serial {
                        infoRow(String(localized: "Numéro de série", bundle: L10n.bundle), value: serial)
                    }
                    if let firmware = adapter.firmware {
                        infoRow(String(localized: "Micrologiciel", bundle: L10n.bundle), value: firmware)
                    }
                    if adapter.isWireless {
                        infoRow(String(localized: "Sans fil", bundle: L10n.bundle), value: String(localized: "Oui", bundle: L10n.bundle))
                    }
                }

                if !adapter.usbPDProfiles.isEmpty {
                    Section(String(localized: "Profils USB-PD", bundle: L10n.bundle)) {
                        ForEach(Array(adapter.usbPDProfiles.enumerated()), id: \.offset) { index, profile in
                            HStack {
                                Text(String(format: "%.0fV \u{00D7} %.2fA (%dW)",
                                            profile.voltage, profile.current, profile.watts))
                                    .font(.system(.body, design: .monospaced))
                                Spacer()
                                if index == adapter.activeProfileIndex {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(AppPalette.positive)
                                }
                            }
                        }
                    }
                }

                if let reason = state.notChargingReason, reason != 0 {
                    Section {
                        infoRow(String(localized: "Motif d’arrêt de charge", bundle: L10n.bundle), value: String(format: "0x%016llX", reason))
                    }
                }
            }

            Section(String(localized: "Contrôle", bundle: L10n.bundle)) {
                infoRow(String(localized: "Mode", bundle: L10n.bundle), value: charging.mode.localizedTitle)
                infoRow(String(localized: "Interface de charge", bundle: L10n.bundle), value: chargingAPIName)
                if settings.controlMagSafeLED {
                    infoRow(String(localized: "Voyant MagSafe", bundle: L10n.bundle), value: ledColorName)
                }
                infoRow(String(localized: "Accès aux mesures SMC", bundle: L10n.bundle), value: battery.smcAvailable ? String(localized: "Oui", bundle: L10n.bundle) : String(localized: "Non", bundle: L10n.bundle))
                if let version = charging.helperVersion {
                    infoRow(String(localized: "Version du service", bundle: L10n.bundle), value: version)
                }
            }

            Section {
                Button(String(localized: "Exporter un diagnostic…", bundle: L10n.bundle)) {
                    DiagnosticExporter.exportWithSavePanel()
                }
                Text(String(localized: "Enregistre les informations du système, l’état actuel, les réglages et les journaux récents dans un fichier texte local.", bundle: L10n.bundle))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var chargingAPIName: String {
        switch charging.chargingAPI {
        case .legacy: return String(localized: "Historique (CH0B/CH0C)", bundle: L10n.bundle)
        case .tahoe:  return String(localized: "Tahoe (CHTE/CHIE)", bundle: L10n.bundle)
        case .unknown: return String(localized: "Non détectée", bundle: L10n.bundle)
        }
    }

    private var ledColorName: String {
        switch charging.lastLEDColor {
        case HelperConstants.ledAuto:   return String(localized: "Auto", bundle: L10n.bundle)
        case HelperConstants.ledOff:    return String(localized: "Éteint", bundle: L10n.bundle)
        case HelperConstants.ledGreen:  return String(localized: "Vert", bundle: L10n.bundle)
        case HelperConstants.ledOrange: return String(localized: "Orange", bundle: L10n.bundle)
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
                    .foregroundStyle(isWarning ? AppPalette.warning : .primary)
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
                .foregroundStyle(warn ? AppPalette.warning : .primary)
                .textSelection(.enabled)
        }
    }
}
