import Foundation

enum UFitRefundRecoveryKind: String, Codable, CaseIterable {
    case orderReturn = "return", cancellation
    var label: String { switch self { case .orderReturn: String(localized: "Retour"); case .cancellation: String(localized: "Annulation") } }
    var sourceTitle: String { switch self { case .orderReturn: String(localized: "Voir le retour"); case .cancellation: String(localized: "Voir la commande") } }
}
struct UFitRefundRecoveryReference: Hashable {
    let kind: UFitRefundRecoveryKind
    let id: String
}
enum UFitRefundRecoveryCause: String, Decodable {
    case failed = "original_method_failed", blocked = "original_method_blocked"
    var explanation: String {
        switch self {
        case .failed: String(localized: "Le remboursement sur le moyen de paiement d’origine a été refusé. Un autre moyen doit être organisé avec le client.")
        case .blocked: String(localized: "Le moyen de paiement d’origine ne permet plus ce remboursement. Un autre moyen doit être organisé avec le client.")
        }
    }
}
struct UFitRefundRecoveryRow {
    let reference: UFitRefundRecoveryReference
    let orderNumber: String
    let context: String
    let amount: String
    let failedAt: String
}
enum UFitRefundRecoveryCopy {
    static let title = String(localized: "Remboursements")
    static let action = String(localized: "Remboursements à traiter")
    static let pending = String(localized: "À organiser")
    static let search = String(localized: "Rechercher une commande")
    static let kind = String(localized: "Origine")
    static let allKinds = String(localized: "Retours et annulations")
    static let loading = String(localized: "Chargement des remboursements")
    static let retry = String(localized: "Réessayer")
    static let refresh = String(localized: "Actualiser les remboursements")
    static let more = String(localized: "Voir la suite")
    static let empty = String(localized: "Aucun remboursement à traiter")
    static let noMatches = String(localized: "Aucun remboursement ne correspond")
    static let reset = String(localized: "Voir tous les remboursements")
    static let unavailable = String(localized: "Ce dossier n’est plus disponible")
    static let backToQueue = String(localized: "Revenir à la liste")
    static let paymentReference = String(localized: "Référence Stripe")
    static let failedAt = String(localized: "Dernier échec")
    static let icon = "arrow.uturn.backward"
    static let next = "chevron.right"
    static let refreshIcon = "arrow.clockwise"
    static let separator = " · "
    static let singleDossier = 1
    static func count(_ value: Int) -> String {value == singleDossier ? String(localized: "1 dossier à traiter") : String(localized: "\(value) dossiers à traiter")}
    static let searchDebounce = Duration.milliseconds(300)
}

struct UFitRefundRecoveryDocument {
    let row: UFitRefundRecoveryRow
    let explanation: String
    let providerReference: String?
    let sourceTitle: String
}
