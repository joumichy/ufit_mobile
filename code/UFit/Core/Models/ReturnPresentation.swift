import Foundation

enum UFitReturnRole { case customer, brand, administrator }
enum UFitReturnStatus: String, Codable, CaseIterable, Identifiable {
    case requested, approved, rejected, disputed, inTransit = "in_transit"
    case refundPending = "refund_pending", refundFailed = "refund_failed", refunded, closed, withdrawn
    var id: String { rawValue }
    var label: String {
        switch self {
        case .requested: String(localized: "Demande envoyée")
        case .approved: String(localized: "Retour accepté")
        case .rejected: String(localized: "Retour refusé")
        case .disputed: String(localized: "Arbitrage demandé")
        case .inTransit: String(localized: "Colis de retour envoyé")
        case .refundPending: String(localized: "Remboursement en cours")
        case .refundFailed: String(localized: "Remboursement à reprendre")
        case .refunded: String(localized: "Remboursé")
        case .closed: String(localized: "Refus confirmé par l’administration")
        case .withdrawn: String(localized: "Demande retirée")
        }
    }
}
enum UFitReturnAction: String, Codable, Identifiable {
    case approve, reject, withdraw, dispute, send, receive
    case arbitrateApprove = "arbitrate_approve", arbitrateReject = "arbitrate_reject", retryRefund = "retry_refund", updateTracking = "update_tracking"
    var id: String { rawValue }
    var requiresForm: Bool { self != .withdraw && self != .retryRefund }
    var needsReason: Bool { [.reject, .dispute, .arbitrateApprove, .arbitrateReject].contains(self) }
    var needsInstructions: Bool { self == .approve || self == .arbitrateApprove }
    var needsTracking: Bool { self == .send || self == .updateTracking }
    var isPrimary: Bool { [.approve, .dispute, .send, .receive, .arbitrateApprove, .retryRefund].contains(self) }
    var label: String {
        switch self {
        case .approve: String(localized: "Accepter le retour")
        case .reject: String(localized: "Refuser le retour")
        case .withdraw: String(localized: "Retirer ma demande")
        case .dispute: String(localized: "Demander un arbitrage")
        case .send: String(localized: "Renseigner l’envoi du retour")
        case .receive: String(localized: "Confirmer la réception")
        case .arbitrateApprove: String(localized: "Autoriser le retour")
        case .arbitrateReject: String(localized: "Confirmer le refus")
        case .retryRefund: String(localized: "Reprendre le remboursement")
        case .updateTracking: String(localized: "Corriger le suivi du retour")
        }
    }
    var saveLabel: String { self == .receive ? String(localized: "Confirmer la réception et rembourser") : label }
    var confirmation: String {
        switch self {
        case .withdraw: String(localized: "La demande sera retirée. Aucun remboursement ne sera déclenché.")
        case .retryRefund: String(localized: "Le remboursement sera repris sur le moyen de paiement utilisé.")
        default: String()
        }
    }
}
struct UFitReturnCommand: Identifiable, Equatable {
    let action: UFitReturnAction
    let expectedVersion: Int
    var id: String { action.rawValue }
}
struct UFitReturnSummaryPresentation: Identifiable {
    let id: String
    let orderNumber: String
    let date: String
    let status: UFitReturnStatus
    let amount: String
    let pieces: String
}
struct UFitReturnAmountsPresentation {
    let merchandise: String
    let shipping: String
    let taxes: String
    let total: String
    let policy: UFitRefundPolicy
}
struct UFitReturnDecisionPresentation {
    let accepted: Bool
    let date: String
    let reason: String?
    let instructions: String?
}
struct UFitReturnDetailPresentation {
    let summary: UFitReturnSummaryPresentation
    let items: [UFitOrderPiece]
    let amounts: UFitReturnAmountsPresentation
    let reason: String
    let deadline: String
    let returnPolicy: String
    let brandDecision: UFitReturnDecisionPresentation?
    let disputeReason: String?
    let disputeDate: String?
    let adminDecision: UFitReturnDecisionPresentation?
    let tracking: UFitParcelPresentation?
    let receiptDate: String?
    let restocked: [String: Int]
    let refundDate: String?
    let refundNote: String?
    let commands: [UFitReturnCommand]
}
struct UFitReturnSelectablePiece: Identifiable {
    let id: String
    let name: String
    let image: String?
    let options: String
    let unitAmount: String
    let availableQuantity: Int
}
struct UFitReturnOptionsPresentation {
    let orderNumber: String
    let items: [UFitReturnSelectablePiece]
    let returnPolicy: String?
    let refundPolicy: UFitRefundPolicy
    let deadline: String?
    let canRequest: Bool
    let unavailableNote: String?
    let openReturnID: String?
}
