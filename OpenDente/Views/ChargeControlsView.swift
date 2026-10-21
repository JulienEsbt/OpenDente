import SwiftUI

/// Everyday actions stay visible; deliberate battery discharge stays in the menu.
struct ChargeControlsView: View {
    @ObservedObject var charging: ChargingManager
    @ObservedObject var settings: AppSettings
    let state: BatteryState

    private var controlAvailable: Bool {
        charging.chargeControlAvailable
    }

    private var canDischarge: Bool {
        !charging.topUpRequested && charging.mode != .heatProtection && PopoverView.canDischarge(
            isPluggedIn: state.isPluggedIn,
            percentage: state.effectivePercentage(useHardware: settings.useHardwareBatteryPercentage),
            chargeLimit: settings.chargeLimit,
            isHelperInstalled: charging.isHelperInstalled,
            chargingAPI: charging.chargingAPI
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Limite habituelle").font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("\(settings.chargeLimit) %")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            Slider(value: Binding(
                get: { Double(settings.chargeLimit) },
                set: { settings.storagePreparationEnabled = false; settings.chargeLimit = Int($0.rounded()) }
            ), in: 20...100, step: 1)
            .controlSize(.small)
            .accessibilityLabel("Limite habituelle de charge")
            .accessibilityValue("\(settings.chargeLimit) pour cent")
            .disabled(!controlAvailable)
            HStack(spacing: 8) {
                ForEach(ChargeProfile.allCases) { profile in profileButton(profile) }
            }
            .disabled(!controlAvailable)
            Text(settings.sailingModeEnabled
                 ? "La charge reprend sous \(settings.sailingLowerBound) %. Le niveau peut baisser naturellement entre les deux seuils."
                 : "La charge reprend dès que le niveau passe sous \(settings.chargeLimit) %.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Divider()
            if charging.nativeLimitAvailable {
                StoragePreparationControls(charging: charging, settings: settings, state: state, compact: true)
                Divider()
            }
            if charging.topUpRequested {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Charge complète ponctuelle", systemImage: "arrow.up.to.line.circle")
                        .font(.system(size: 12, weight: .semibold))
                    Text(charging.mode == .heatProtection
                         ? "Suspendue par la protection thermique. Ta limite habituelle reste enregistrée."
                         : "Ta limite de \(settings.chargeLimit) % revient au débranchement ou à l’annulation.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Revenir à ma limite") { charging.cancelTopUp() }
                        .buttonStyle(.bordered).controlSize(.small)
                }
            } else {
                Button { charging.startTopUp() } label: {
                    Label("Charger à 100 % cette fois", systemImage: "arrow.up.to.line.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .disabled(!controlAvailable || !state.isPluggedIn || (charging.mode == .discharging && !charging.nativeLimitAvailable))
                .help("Charge ponctuelle à 100 %, avec retour à la limite habituelle au débranchement")
            }
            HStack {
                if settings.heatProtectionEnabled {
                    Label("Pause thermique à \(TemperatureDisplay.format(settings.heatProtectionTemp, fractionDigits: 0))", systemImage: "thermometer.medium")
                        .font(.caption2).foregroundStyle(.secondary)
                        .help("Pause à partir de \(TemperatureDisplay.format(settings.heatProtectionTemp))")
                }
                Spacer(minLength: 4)
                if charging.mode == .discharging && !charging.isPreparingStorage {
                    Button("Arrêter la décharge") { charging.stopDischarge() }.controlSize(.small)
                } else if !charging.nativeLimitAvailable {
                    Menu {
                        Button("Décharger jusqu’à \(settings.chargeLimit) %") { charging.startDischarge() }
                            .disabled(!canDischarge)
                        Text("Utilise la batterie même avec le chargeur branché.")
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .menuStyle(.borderlessButton).fixedSize()
                    .disabled(charging.nativeLimitAvailable)
                    .help("Autres actions")
                    .accessibilityLabel("Autres actions de charge")
                }
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.65), in: RoundedRectangle(cornerRadius: 8))
    }

    private func profileButton(_ profile: ChargeProfile) -> some View {
        let selected = !charging.isPreparingStorage && settings.selectedProfile == profile
        return Button { settings.apply(profile: profile) } label: {
            VStack(spacing: 4) {
                Text(profile.title).font(.system(size: 11, weight: .medium))
                Text("\(profile.chargeLimit) %")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(selected ? Color.teal.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(selected ? Color.teal : Color.secondary.opacity(0.22), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Profil \(profile.title), limite \(profile.chargeLimit) pour cent, reprise sous \(profile.resumeAt) pour cent")
        .accessibilityValue(selected ? "Sélectionné" : "Non sélectionné")
        .help("Limite \(profile.chargeLimit) %, reprise sous \(profile.resumeAt) %, protection thermique active ; le retour sur secteur suit son option")
    }
}
