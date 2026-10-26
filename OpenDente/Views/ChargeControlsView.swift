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
                Text(String(localized: "Limite habituelle", bundle: L10n.bundle)).font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(String(localized: "\(settings.chargeLimit) %", bundle: L10n.bundle))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            Slider(value: Binding(
                get: { Double(settings.chargeLimit) },
                set: { settings.storagePreparationEnabled = false; settings.chargeLimit = Int($0.rounded()) }
            ), in: 20...100, step: 1)
            .controlSize(.small)
            .accessibilityLabel(String(localized: "Limite habituelle de charge", bundle: L10n.bundle))
            .accessibilityValue(String(localized: "\(settings.chargeLimit) pour cent", bundle: L10n.bundle))
            .disabled(!controlAvailable)
            HStack(spacing: 8) {
                ForEach(ChargeProfile.allCases) { profile in profileButton(profile) }
            }
            .disabled(!controlAvailable)
            Text(settings.sailingModeEnabled
                 ? String(localized: "La charge reprend sous \(settings.sailingLowerBound) %. Le niveau peut baisser naturellement entre les deux seuils.", bundle: L10n.bundle)
                 : String(localized: "La charge reprend dès que le niveau passe sous \(settings.chargeLimit) %.", bundle: L10n.bundle))
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Divider()
            if charging.nativeLimitAvailable {
                StoragePreparationControls(charging: charging, settings: settings, state: state, compact: true)
                Divider()
            }
            if charging.topUpRequested {
                VStack(alignment: .leading, spacing: 8) {
                    Label(String(localized: "Charge complète ponctuelle", bundle: L10n.bundle), systemImage: "arrow.up.to.line.circle")
                        .font(.system(size: 12, weight: .semibold))
                    Text(charging.mode == .heatProtection
                         ? String(localized: "Suspendue par la protection thermique. Ta limite habituelle reste enregistrée.", bundle: L10n.bundle)
                         : String(localized: "Ta limite de \(settings.chargeLimit) % revient au débranchement ou à l’annulation.", bundle: L10n.bundle))
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(String(localized: "Revenir à ma limite", bundle: L10n.bundle)) { charging.cancelTopUp() }
                        .buttonStyle(.bordered).controlSize(.small)
                }
            } else {
                Button { charging.startTopUp() } label: {
                    Label(String(localized: "Charger à 100 % cette fois", bundle: L10n.bundle), systemImage: "arrow.up.to.line.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).tint(AppPalette.action).controlSize(.large)
                .disabled(!controlAvailable || !state.isPluggedIn || (charging.mode == .discharging && !charging.nativeLimitAvailable))
                .help(String(localized: "Charge ponctuelle à 100 %, avec retour à la limite habituelle au débranchement", bundle: L10n.bundle))
            }
            HStack {
                if settings.heatProtectionEnabled {
                    Label(String(localized: "Pause thermique à \(TemperatureDisplay.format(settings.heatProtectionTemp, fractionDigits: 0))", bundle: L10n.bundle), systemImage: "thermometer.medium")
                        .font(.caption2).foregroundStyle(.secondary)
                        .help(String(localized: "Pause à partir de \(TemperatureDisplay.format(settings.heatProtectionTemp))", bundle: L10n.bundle))
                }
                Spacer(minLength: 4)
                if charging.mode == .discharging && !charging.isPreparingStorage {
                    Button(String(localized: "Arrêter la décharge", bundle: L10n.bundle)) { charging.stopDischarge() }.controlSize(.small)
                } else if !charging.nativeLimitAvailable {
                    Menu {
                        Button(String(localized: "Décharger jusqu’à \(settings.chargeLimit) %", bundle: L10n.bundle)) { charging.startDischarge() }
                            .disabled(!canDischarge)
                        Text(String(localized: "Utilise la batterie même avec le chargeur branché.", bundle: L10n.bundle))
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .menuStyle(.borderlessButton).fixedSize()
                    .disabled(charging.nativeLimitAvailable)
                    .help(String(localized: "Autres actions", bundle: L10n.bundle))
                    .accessibilityLabel(String(localized: "Autres actions de charge", bundle: L10n.bundle))
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
                Text(String(localized: "\(profile.chargeLimit) %", bundle: L10n.bundle))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(selected ? AppPalette.accent.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(selected ? AppPalette.accent : Color.secondary.opacity(0.22), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Profil \(profile.title), limite \(profile.chargeLimit) pour cent, reprise sous \(profile.resumeAt) pour cent", bundle: L10n.bundle))
        .accessibilityValue(selected ? String(localized: "Sélectionné", bundle: L10n.bundle) : String(localized: "Non sélectionné", bundle: L10n.bundle))
        .help(String(localized: "Limite \(profile.chargeLimit) %, reprise sous \(profile.resumeAt) %, protection thermique active ; le retour sur secteur suit son option", bundle: L10n.bundle))
    }
}
