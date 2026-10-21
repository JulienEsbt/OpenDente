import SwiftUI

struct StoragePreparationControls: View {
    @ObservedObject var charging: ChargingManager
    @ObservedObject var settings: AppSettings
    let state: BatteryState
    var compact = false

    static func detail(_ state: BatteryState, mode: ChargingMode) -> String {
        if state == .unknown { return "En attente d’une mesure de batterie." }
        if mode == .heatProtection { return "Préparation en attente du refroidissement de la batterie." }
        if state.percentage == 50 { return "50 % atteints. Débranche le chargeur, puis éteins le Mac depuis le menu Pomme." }
        if !state.isPluggedIn { return "Préparation à 50 % conservée. Rebranche pour charger si nécessaire ; la batterie baisse naturellement à l’usage." }
        if state.percentage > 50 {
            let discharging = (state.amperage ?? 0) < -0.05
            return discharging
                ? "La batterie fournit de l’énergie malgré le branchement. Descente vers 50 % en cours."
                : "Descente vers 50 % demandée à macOS. En attente d’un courant de décharge confirmé."
        }
        return "Recharge vers 50 %, puis maintien. La consigne peut prendre environ une minute."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if charging.isPreparingStorage {
                Label("Mode stockage — cible 50 %", systemImage: "archivebox")
                    .font(.headline)
                Text(Self.detail(state, mode: charging.mode)).font(.callout)
                Text("Ton réglage quotidien \(settings.chargeLimit) % / reprise sous \(settings.sailingLowerBound) % reste sauvegardé.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Arrêter le mode stockage") { charging.cancelStoragePreparation() }
                    .help("Annule la cible 50 % et remet les seuils quotidiens, sans forcer une recharge ou une décharge.")
            } else {
                Button("Préparer le stockage à 50 %") { charging.startStoragePreparation() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!charging.isHelperInstalled || !charging.nativeLimitAvailable || state == .unknown)
                    .help("Cible temporaire 50 %. Au-dessus, demande une décharge même sur secteur ; en dessous, demande une recharge. Tes seuils quotidiens sont conservés.")
            }
            if !compact {
                Text("Ce mode autorise explicitement macOS à utiliser la batterie sur secteur pour descendre vers 50 %. Il ne lance aucun calcul pour accélérer la décharge. L’app signale l’effet mesuré ; une consigne acceptée ne prouve pas que la décharge a commencé.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("La cible reste active jusqu’à l’arrêt du mode, au choix d’un profil ou à une charge ponctuelle. Quitter l’app ou désactiver le contrôle restaure les réglages Apple. Le Mac s’éteint uniquement à ta demande.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
