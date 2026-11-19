import Foundation

enum UFitCustomerPaymentState: String, Decodable {
    case notStarted = "not_started", ready, failed, action = "requires_action", processing
    case confirming = "awaiting_confirmation", closed, review, orderUpdated = "order_updated"
    var canResume: Bool { [.notStarted, .ready, .failed, .action].contains(self) }
}
enum UFitCustomerPaymentCopy {
    static let loading = String(localized: "Vérification du paiement")
    static let resume = String(localized: "Reprendre le paiement")
    static let chooseMethod = String(localized: "Choisir le moyen de paiement")
    static let methodChoice = String(localized: "Vous pouvez changer de carte à l’étape suivante.")
    static let invalid = String(localized: "Le paiement n’a pas pu être vérifié. Actualisez son statut avant de réessayer.")
    static let unavailable = String(localized: "Le statut du paiement est indisponible. Vérifiez-le avant toute nouvelle tentative.")
    static let interrupted = String(localized: "Le paiement a été interrompu. Vous pouvez reprendre la même tentative.")
    static let failed = String(localized: "Le paiement n’a pas abouti. Vous pouvez réessayer depuis cette commande.")
    static func title(_ state: UFitCustomerPaymentState) -> String {
        switch state {
        case .notStarted, .ready: String(localized: "Paiement à finaliser")
        case .failed: String(localized: "Paiement non abouti")
        case .action: String(localized: "Vérification bancaire requise")
        case .processing: String(localized: "Paiement en traitement")
        case .confirming: String(localized: "Confirmation de la commande en cours")
        case .closed: String(localized: "Tentative de paiement fermée")
        case .review: String(localized: "Paiement en vérification")
        case .orderUpdated: String(localized: "Le statut de la commande a changé")
        }
    }
    static func detail(_ state: UFitCustomerPaymentState) -> String {
        switch state {
        case .notStarted: String(localized: "Choisissez votre moyen de paiement pour cette commande.")
        case .ready: String(localized: "Vous pouvez choisir une autre carte pour finaliser cette commande.")
        case .failed: String(localized: "Vous pouvez utiliser une autre carte en reprenant cette tentative.")
        case .action: String(localized: "Reprenez le paiement pour terminer la vérification demandée par votre banque.")
        case .processing: String(localized: "Le résultat est attendu. Aucune nouvelle tentative de paiement n’est nécessaire.")
        case .confirming: String(localized: "Le paiement a abouti. La confirmation de la commande est encore attendue.")
        case .closed: String(localized: "Cette tentative ne peut plus être reprise. Vous pouvez annuler la commande pour recommencer depuis votre panier.")
        case .review: String(localized: "Le paiement nécessite une vérification. Ne recommencez pas le paiement ; actualisez son statut.")
        case .orderUpdated: String(localized: "Cette commande n’est plus en attente de paiement. Actualisez son suivi.")
        }
    }
    static func message(_ error: Error) -> String {
        if error is DecodingError || error is UFitCustomerPaymentFailure { return invalid }
        if case UFitAPIError.requestFailed(_, _, let code) = error, UFitCustomerPaymentHTTP.failures.contains(code ?? String()) { return unavailable }
        return error.localizedDescription
    }
}
