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
            Toggle("Adapter le voyant aux modes", isOn: $settings.nativeMagSafeLEDEnabled)
                .disabled(!charging.isHelperInstalled || !charging.nativeLEDHardwareAvailable)
            if !charging.nativeLEDHardwareAvailable {
                Text("Ce Mac n’expose pas de commande MagSafe compatible, ou le service n’est pas encore connecté.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if settings.nativeMagSafeLEDEnabled {
                choice("Charge confirmée", value: $settings.nativeLEDChargingColor)
                choice("Pause confirmée", value: $settings.nativeLEDPausedColor)
                choice("Descente en mode stockage", value: $settings.nativeLEDStorageColor)
                choice("Pause thermique", value: $settings.nativeLEDThermalColor)
            }
            HStack {
                Button("Vert (10 s)") { charging.previewMagSafeLED(.green) }
                Button("Orange (10 s)") { charging.previewMagSafeLED(.orange) }
                Button("Éteint (10 s)") { charging.previewMagSafeLED(.off) }
            }
            .disabled(!charging.isHelperInstalled || !charging.nativeLEDHardwareAvailable)
            Button("Rendre le voyant à macOS") { charging.useSystemMagSafeLED() }
                .disabled(!charging.isHelperInstalled || !charging.nativeLEDHardwareAvailable)
            if charging.magSafeLEDPreviewActive {
                Text("Test temporaire : retour au réglage choisi après environ 10 secondes.")
                    .font(.caption).foregroundStyle(.teal)
            }
            if let issue = charging.nativeLEDIssue {
                Text(issue).font(.caption).foregroundStyle(.orange)
            }
            Text("Vert, orange ou éteint ; ce voyant n’est pas RGB. Une charge encore mesurée garde la couleur « Charge confirmée », même si une pause a été demandée. Le voyant ne prouve pas à lui seul l’arrêt de charge.")
                .font(.caption).foregroundStyle(.secondary)
            Text("Retour au contrôle de macOS au débranchement, pendant la veille, à l’arrêt de l’app ou en cas de perte du client. Aucun clignotement personnalisé n’est ajouté.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
