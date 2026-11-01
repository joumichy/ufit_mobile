import Foundation

enum UFitShipmentAction: String, Codable, CaseIterable, Identifiable {
    case prepare, ship, deliver
    case reportIncident = "report_incident", resolveIncident = "resolve_incident", updateTracking = "update_tracking"
    var id: String { rawValue }
    var requiresForm: Bool { [.ship, .reportIncident, .updateTracking].contains(self) }
    var isPrimary: Bool { [.prepare, .ship, .deliver, .resolveIncident].contains(self) }
    var label: String {
        switch self {
        case .prepare: String(localized: "Préparer la commande")
        case .ship: String(localized: "Renseigner l’expédition")
        case .deliver: String(localized: "Confirmer la livraison")
        case .reportIncident: String(localized: "Signaler un incident")
        case .resolveIncident: String(localized: "Résoudre l’incident")
        case .updateTracking: String(localized: "Modifier le suivi")
        }
    }
    var saveLabel: String {
        switch self {
        case .ship: String(localized: "Confirmer l’expédition")
        case .updateTracking: String(localized: "Enregistrer le suivi")
        case .reportIncident: String(localized: "Signaler l’incident")
        default: label
        }
    }
    var confirmation: String {
        switch self {
        case .prepare: String(localized: "Le client ne pourra plus annuler cette commande.")
        case .deliver: String(localized: "Confirmez que le colis a été livré au client.")
        case .resolveIncident: String(localized: "Confirmez que l’incident est résolu pour reprendre le suivi de la commande.")
        default: String()
        }
    }
}
struct UFitShipmentCommand: Identifiable, Equatable {
    let action: UFitShipmentAction
    let expectedVersion: Int
    var id: String { action.rawValue }
}
struct UFitShipmentPresentation {
    let status: UFitShipmentLifecycle
    let carrier: String?
    let trackingNumber: String?
    let trackingURL: URL?
    let shippedDate: String?
    let deliveredDate: String?
    let incidentReason: String?
    let incidentDate: String?
    init(status: UFitShipmentLifecycle, carrier: String? = nil, trackingNumber: String? = nil, trackingURL: URL? = nil,
         shippedAt: UFitTimestamp? = nil, deliveredAt: UFitTimestamp? = nil, incidentReason: String? = nil, incidentAt: UFitTimestamp? = nil) {
        self.status = status; self.carrier = carrier; self.trackingNumber = trackingNumber; self.trackingURL = trackingURL
        shippedDate = shippedAt?.label; deliveredDate = deliveredAt?.label; self.incidentReason = incidentReason; incidentDate = incidentAt?.label
    }
}
struct UFitShipmentFormDraft: Equatable {
    var carrier = String()
    var trackingNumber = String()
    var trackingURL = String()
    var incidentReason = String()
}
enum UFitShipmentFormField: Hashable { case carrier, trackingNumber, trackingURL, incidentReason }
enum UFitShipmentInput {
    static let minimumText = 1; static let carrierMaximum = 120; static let trackingMaximum = 160; static let incidentMaximum = 2000
    static let maximumPrimaryActions = 1
    static let initialVersion = 1; static let versionStep = 1; static let maximumVersion = UFitDecimalInput.maximumInteger
    static let https = "https"
    static func trimmed(_ value: String) -> String { value.trimmingCharacters(in: .whitespacesAndNewlines) }
    static func validText(_ value: String, maximum: Int) -> Bool { (minimumText...maximum).contains(trimmed(value).utf16.count) }
    static func trackingURL(_ value: String) -> URL? {
        guard let url = URL(string: trimmed(value)), url.scheme?.lowercased() == https, let host = url.host, !host.isEmpty else { return nil }
        return url
    }
    static func errors(_ draft: UFitShipmentFormDraft, action: UFitShipmentAction) -> [UFitShipmentFormField: String] {
        var errors: [UFitShipmentFormField: String] = [:]
        if action == .reportIncident {
            if !validText(draft.incidentReason, maximum: incidentMaximum) { errors[.incidentReason] = String(localized: "Précisez l’incident, jusqu’à 2 000 caractères.") }
        } else if action == .ship || action == .updateTracking {
            if !validText(draft.carrier, maximum: carrierMaximum) { errors[.carrier] = String(localized: "Indiquez le transporteur, jusqu’à 120 caractères.") }
            if !validText(draft.trackingNumber, maximum: trackingMaximum) { errors[.trackingNumber] = String(localized: "Indiquez le numéro de suivi, jusqu’à 160 caractères.") }
            if !trimmed(draft.trackingURL).isEmpty && trackingURL(draft.trackingURL) == nil { errors[.trackingURL] = String(localized: "Saisissez un lien de suivi HTTPS valide ou laissez ce champ vide.") }
        }
        return errors
    }
}
