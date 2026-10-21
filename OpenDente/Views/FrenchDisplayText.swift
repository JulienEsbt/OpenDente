import Foundation

/// Presentation-only French labels. The model's diagnostic identifiers stay stable.
extension ChargingMode {
    var frenchTitle: String {
        switch self {
        case .charging: return "Charge en cours"
        case .paused: return "Limite atteinte"
        case .sailing: return "Charge suspendue"
        case .discharging: return "Décharge en cours"
        case .topUp: return "Vers 100 %"
        case .calibrating: return "Calibration"
        case .heatProtection: return "Protection thermique"
        case .onBattery: return "Sur batterie"
        case .idle: return "En attente"
        }
    }

    func frenchTimeRemainingDisplay(chargeLimit: Int, percentage: Int,
                                    timeToFull: Int?, timeToEmpty: Int?) -> (label: String, value: String)? {
        guard let result = timeRemainingDisplay(chargeLimit: chargeLimit, percentage: percentage,
                                                timeToFull: timeToFull, timeToEmpty: timeToEmpty) else { return nil }
        let label: String
        switch self {
        case .charging: label = "Durée estimée vers \(chargeLimit) %"
        case .topUp: label = "Durée estimée vers 100 %"
        default: label = "Autonomie estimée"
        }
        let value: String
        switch result.value {
        case "Reached": value = "Limite atteinte"
        case "Charged": value = "Charge complète"
        case "Calculating…": value = "Calcul en cours…"
        case "Paused": value = "En pause"
        default: value = result.value
        }
        return (label, value)
    }
}

extension PopoverDetailItem {
    var frenchTitle: String {
        switch self {
        case .temperature: return "Température"
        case .batteryHealth: return "Capacité maximale"
        case .cycleCount: return "Cycles"
        case .timeRemaining: return "Autonomie estimée"
        case .systemPower: return "Puissance du Mac"
        case .adapterPower: return "Puissance du chargeur"
        case .adapterName: return "Chargeur"
        case .adapterManufacturer: return "Fabricant"
        case .adapterModel: return "Modèle du chargeur"
        case .adapterSerial: return "Numéro de série du chargeur"
        case .adapterVoltage: return "Tension du chargeur"
        case .adapterCurrent: return "Courant du chargeur"
        case .voltage: return "Tension de la batterie"
        case .amperage: return "Courant de la batterie"
        case .currentCapacity: return "Capacité"
        case .designCapacity: return "Capacité de conception"
        case .batteryPower: return "Puissance de la batterie"
        case .notChargingReason: return "Motif d’arrêt de charge"
        }
    }
}
