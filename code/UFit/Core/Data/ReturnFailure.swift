import Foundation

enum UFitReturnFailureCode: String {
    case input = "order_return_input_invalid", changed = "order_return_version_changed", state = "order_return_action_unavailable"
    case persisted = "order_return_persisted_invalid", quantity = "order_return_quantity_unavailable", expired = "order_return_window_closed"
    case open = "order_return_already_open", reused = "order_return_request_conflict", quote = "order_return_quote_changed"
    case missing = "order_return_not_found", access = "order_return_access_required", cursor = "order_return_cursor_invalid"
    case paymentMismatch = "order_return_payment_mismatch", paymentUnavailable = "order_return_payment_unavailable", refundUnknown = "order_return_refund_status_unknown"
    var label: String {
        switch self {
        case .input: String(localized: "Vérifiez les champs indiqués avant de continuer.")
        case .changed: String(localized: "Le dossier a changé. Actualisez avant de continuer.")
        case .state: String(localized: "Cette action n’est plus disponible. Actualisez le dossier pour consulter son état.")
        case .persisted: UFitReturnContractError.document.localizedDescription
        case .quantity: String(localized: "Certaines pièces ne sont plus éligibles. Actualisez la sélection avant de continuer.")
        case .expired: String(localized: "Le délai de retour est terminé ou cette commande n’est pas éligible au retour.")
        case .open: String(localized: "Un retour est déjà en cours pour cette commande. Actualisez pour ouvrir son dossier.")
        case .reused: String(localized: "Cette demande possède déjà un autre contenu enregistré. Le support doit vérifier sa référence avant un nouvel envoi.")
        case .quote: String(localized: "Le montant du retour a changé. Vérifiez le nouveau récapitulatif avant d’envoyer.")
        case .missing: String(localized: "Ce dossier n’est plus disponible. Actualisez la liste des retours.")
        case .access: String(localized: "Votre accès à ce retour a changé. Revenez à votre espace et actualisez.")
        case .cursor: UFitReturnContractError.page.localizedDescription
        case .paymentMismatch, .paymentUnavailable: String(localized: "Le paiement doit être vérifié avant le remboursement. Le retour reste enregistré.")
        case .refundUnknown: String(localized: "Le prestataire n’a pas encore confirmé le remboursement. Actualisez le dossier plus tard.")
        }
    }
}
extension UFitAPIError {
    var returnFailure: UFitReturnFailureCode? {
        guard case .requestFailed(_, _, let code) = self, let code else { return nil }
        return UFitReturnFailureCode(rawValue: code)
    }
    var returnFailureDescription: String? { returnFailure?.label }
    var isReturnConflict: Bool { returnFailure == .changed || returnFailure == .state }
    var losesReturnAccess: Bool {
        switch self {
        case .authenticationRequired: true
        case .requestFailed(let status, _, _): status == UFitReturnsHTTP.unauthorized || status == UFitReturnsHTTP.forbidden
        default: false
        }
    }
}
