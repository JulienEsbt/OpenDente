import Foundation

/// Localized presentation labels. The model's diagnostic identifiers stay stable.
extension ChargingMode {
    var localizedTitle: String {
        switch self {
        case .charging: return String(localized: "Charge en cours", bundle: L10n.bundle)
        case .paused: return String(localized: "Limite atteinte", bundle: L10n.bundle)
        case .sailing: return String(localized: "Charge suspendue", bundle: L10n.bundle)
        case .discharging: return String(localized: "Décharge en cours", bundle: L10n.bundle)
        case .topUp: return String(localized: "Vers 100 %", bundle: L10n.bundle)
        case .calibrating: return String(localized: "Calibration", bundle: L10n.bundle)
        case .heatProtection: return String(localized: "Protection thermique", bundle: L10n.bundle)
        case .onBattery: return String(localized: "Sur batterie", bundle: L10n.bundle)
        case .idle: return String(localized: "En attente", bundle: L10n.bundle)
        }
    }

    func localizedTimeRemainingDisplay(chargeLimit: Int, percentage: Int,
                                    timeToFull: Int?, timeToEmpty: Int?) -> (label: String, value: String)? {
        guard let result = timeRemainingDisplay(chargeLimit: chargeLimit, percentage: percentage,
                                                timeToFull: timeToFull, timeToEmpty: timeToEmpty) else { return nil }
        let label: String
        switch self {
        case .charging: label = String(localized: "Durée estimée vers \(chargeLimit) %", bundle: L10n.bundle)
        case .topUp: label = String(localized: "Durée estimée vers 100 %", bundle: L10n.bundle)
        default: label = String(localized: "Autonomie estimée", bundle: L10n.bundle)
        }
        let value: String
        switch result.value {
        case "Reached": value = String(localized: "Limite atteinte", bundle: L10n.bundle)
        case "Charged": value = String(localized: "Charge complète", bundle: L10n.bundle)
        case "Calculating…": value = String(localized: "Calcul en cours…", bundle: L10n.bundle)
        case "Paused": value = String(localized: "En pause", bundle: L10n.bundle)
        default: value = result.value
        }
        return (label, value)
    }
}

extension PopoverDetailItem {
    var localizedTitle: String {
        switch self {
        case .temperature: return String(localized: "Température", bundle: L10n.bundle)
        case .batteryHealth: return String(localized: "Capacité maximale", bundle: L10n.bundle)
        case .cycleCount: return String(localized: "Cycles", bundle: L10n.bundle)
        case .timeRemaining: return String(localized: "Autonomie estimée", bundle: L10n.bundle)
        case .systemPower: return String(localized: "Puissance du Mac", bundle: L10n.bundle)
        case .adapterPower: return String(localized: "Puissance du chargeur", bundle: L10n.bundle)
        case .adapterName: return String(localized: "Chargeur", bundle: L10n.bundle)
        case .adapterManufacturer: return String(localized: "Fabricant", bundle: L10n.bundle)
        case .adapterModel: return String(localized: "Modèle du chargeur", bundle: L10n.bundle)
        case .adapterSerial: return String(localized: "Numéro de série du chargeur", bundle: L10n.bundle)
        case .adapterVoltage: return String(localized: "Tension du chargeur", bundle: L10n.bundle)
        case .adapterCurrent: return String(localized: "Courant du chargeur", bundle: L10n.bundle)
        case .voltage: return String(localized: "Tension de la batterie", bundle: L10n.bundle)
        case .amperage: return String(localized: "Courant de la batterie", bundle: L10n.bundle)
        case .currentCapacity: return String(localized: "Capacité", bundle: L10n.bundle)
        case .designCapacity: return String(localized: "Capacité de conception", bundle: L10n.bundle)
        case .batteryPower: return String(localized: "Puissance de la batterie", bundle: L10n.bundle)
        case .notChargingReason: return String(localized: "Motif d’arrêt de charge", bundle: L10n.bundle)
        }
    }
}
