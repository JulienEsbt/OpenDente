import SwiftUI

struct MagSafeLEDControls: View {
    @ObservedObject var charging: ChargingManager
    @ObservedObject var settings: AppSettings

    private func choice(_ title: String, value: Binding<MagSafeLEDChoice>) -> some View {
        Picker(title, selection: value) {
            ForEach(MagSafeLEDChoice.allCases) { Text($0.title).tag($0) }
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(String(localized: "Adapter le voyant aux modes", bundle: L10n.bundle), isOn: $settings.nativeMagSafeLEDEnabled)
                .disabled(!charging.isHelperInstalled || !charging.nativeLEDHardwareAvailable)
            if !charging.nativeLEDHardwareAvailable {
                Text(String(localized: "Ce Mac n’expose pas de commande MagSafe compatible, ou le service n’est pas encore connecté.", bundle: L10n.bundle))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Button(String(localized: "Appliquer les signaux distincts", bundle: L10n.bundle)) { settings.applyDistinctLEDSignals() }
                .disabled(!charging.isHelperInstalled || !charging.nativeLEDHardwareAvailable)
            if settings.nativeMagSafeLEDEnabled {
                choice(String(localized: "Charge confirmée", bundle: L10n.bundle), value: $settings.nativeLEDChargingColor)
                choice(String(localized: "Pause confirmée", bundle: L10n.bundle), value: $settings.nativeLEDPausedColor)
                choice(String(localized: "Décharge sur secteur", bundle: L10n.bundle), value: $settings.nativeLEDStorageColor)
                choice(String(localized: "Pause thermique", bundle: L10n.bundle), value: $settings.nativeLEDThermalColor)
                choice(String(localized: "Charge ponctuelle vers 100 %", bundle: L10n.bundle), value: $settings.nativeLEDTopUpColor)
                choice(String(localized: "100 % ponctuel atteint", bundle: L10n.bundle), value: $settings.nativeLEDCompleteColor)
            }
            HStack {
                Button(String(localized: "Vert (10 s)", bundle: L10n.bundle)) { charging.previewMagSafeLED(.green) }
                Button(String(localized: "Orange (10 s)", bundle: L10n.bundle)) { charging.previewMagSafeLED(.orange) }
                Button(String(localized: "Éteint (10 s)", bundle: L10n.bundle)) { charging.previewMagSafeLED(.off) }
            }
            .disabled(!charging.isHelperInstalled || !charging.nativeLEDHardwareAvailable)
            HStack {
                Button(String(localized: "Vert clignotant (10 s)", bundle: L10n.bundle)) { charging.previewMagSafeLED(.pulsingGreen) }
                Button(String(localized: "Orange clignotant (10 s)", bundle: L10n.bundle)) { charging.previewMagSafeLED(.pulsingOrange) }
                Button(String(localized: "Alternance (10 s)", bundle: L10n.bundle)) { charging.previewMagSafeLED(.alternating) }
            }
            .disabled(!charging.isHelperInstalled || !charging.nativeLEDHardwareAvailable)
            Button(String(localized: "Rendre le voyant à macOS", bundle: L10n.bundle)) { charging.useSystemMagSafeLED() }
                .disabled(!charging.isHelperInstalled || !charging.nativeLEDHardwareAvailable)
            if charging.magSafeLEDPreviewActive {
                Text(String(localized: "Test temporaire : retour au réglage choisi après environ 10 secondes.", bundle: L10n.bundle))
                    .font(.caption).foregroundStyle(AppPalette.accent)
            }
            if let issue = charging.nativeLEDIssue {
                Text(issue).font(.caption).foregroundStyle(AppPalette.warning)
            }
            Text(String(localized: "Signaux distincts : charge normale orange clignotant ; maintien vert clignotant ; décharge alternée ; charge ponctuelle orange fixe puis vert fixe à 100 % ; pause thermique éteinte.", bundle: L10n.bundle))
                .font(.caption).foregroundStyle(.secondary)
            Text(String(localized: "Vert, orange ou éteint ; ce voyant n’est pas RGB. Une charge encore mesurée garde la couleur « Charge confirmée », même si une pause a été demandée. Le voyant ne prouve pas à lui seul l’arrêt de charge.", bundle: L10n.bundle))
                .font(.caption).foregroundStyle(.secondary)
            Text(String(localized: "Retour au contrôle de macOS au débranchement, pendant la veille, à l’arrêt de l’app ou en cas de perte du client. Les clignotements sont animés par l’app éveillée, environ 2 s par phase, avec les commandes de couleur déjà vérifiées. Aucun code de défaut du chargeur n’est utilisé.", bundle: L10n.bundle))
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
