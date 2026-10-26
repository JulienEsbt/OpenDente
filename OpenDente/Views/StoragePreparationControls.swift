import SwiftUI

struct StoragePreparationControls: View {
    @ObservedObject var charging: ChargingManager
    @ObservedObject var settings: AppSettings
    let state: BatteryState
    var compact = false

    static func detail(_ state: BatteryState, mode: ChargingMode) -> String {
        if state == .unknown { return String(localized: "En attente d’une mesure de batterie.", bundle: L10n.bundle) }
        if mode == .heatProtection { return String(localized: "Préparation en attente du refroidissement de la batterie.", bundle: L10n.bundle) }
        if state.percentage == 50 { return String(localized: "50 % atteints. Débranche le chargeur, puis éteins le Mac depuis le menu Pomme.", bundle: L10n.bundle) }
        if !state.isPluggedIn { return String(localized: "Préparation à 50 % conservée. Rebranche pour charger si nécessaire ; la batterie baisse naturellement à l’usage.", bundle: L10n.bundle) }
        if state.percentage > 50 {
            let discharging = (state.amperage ?? 0) < -0.05
            return discharging
                ? String(localized: "La batterie fournit de l’énergie malgré le branchement. Descente vers 50 % en cours.", bundle: L10n.bundle)
                : String(localized: "Descente vers 50 % demandée à macOS. En attente d’un courant de décharge confirmé.", bundle: L10n.bundle)
        }
        return String(localized: "Recharge vers 50 %, puis maintien. La consigne peut prendre plusieurs minutes.", bundle: L10n.bundle)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if charging.isPreparingStorage {
                Label(String(localized: "Mode stockage — cible 50 %", bundle: L10n.bundle), systemImage: "archivebox")
                    .font(.headline)
                Text(Self.detail(state, mode: charging.mode)).font(.callout)
                Text(String(localized: "Ton réglage quotidien \(settings.chargeLimit) % / reprise sous \(settings.sailingLowerBound) % reste sauvegardé.", bundle: L10n.bundle))
                    .font(.caption).foregroundStyle(.secondary)
                Button(String(localized: "Arrêter le mode stockage", bundle: L10n.bundle)) { charging.cancelStoragePreparation() }
                    .help(String(localized: "Annule la cible 50 % et remet les seuils quotidiens, sans forcer une recharge ou une décharge.", bundle: L10n.bundle))
            } else {
                Button(String(localized: "Préparer le stockage à 50 %", bundle: L10n.bundle)) { charging.startStoragePreparation() }
                    .buttonStyle(.borderedProminent).tint(AppPalette.action)
                    .disabled(!charging.isHelperInstalled || !charging.nativeLimitAvailable || state == .unknown)
                    .help(String(localized: "Cible temporaire 50 %. Au-dessus, demande une décharge même sur secteur ; en dessous, demande une recharge. Tes seuils quotidiens sont conservés.", bundle: L10n.bundle))
            }
            if !compact {
                Text(String(localized: "Ce mode autorise explicitement macOS à utiliser la batterie sur secteur pour descendre vers 50 %. Il ne lance aucun calcul pour accélérer la décharge. L’app signale l’effet mesuré ; une consigne acceptée ne prouve pas que la décharge a commencé.", bundle: L10n.bundle))
                    .font(.caption).foregroundStyle(.secondary)
                Text(String(localized: "La cible reste active jusqu’à l’arrêt du mode, au choix d’un profil ou à une charge ponctuelle. Quitter l’app ou désactiver le contrôle restaure les réglages Apple. Le Mac s’éteint uniquement à ta demande.", bundle: L10n.bundle))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
