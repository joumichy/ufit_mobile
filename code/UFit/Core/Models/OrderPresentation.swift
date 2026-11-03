import Foundation

enum UFitOrderLifecycle: String, Decodable, CaseIterable {
    case pendingPayment = "pending_payment", paid, cancelling, preparing, shipped, delivered, cancelled, refunded
    var label: String {
        switch self {
        case .pendingPayment: String(localized: "En attente de paiement")
        case .paid: String(localized: "Paiement confirmé")
        case .cancelling: String(localized: "Annulation en cours")
        case .preparing: String(localized: "En préparation")
        case .shipped: String(localized: "Expédiée")
        case .delivered: String(localized: "Livrée")
        case .cancelled: String(localized: "Annulée")
        case .refunded: String(localized: "Remboursée")
        }
    }
}
struct UFitOrderSummary: Identifiable {
    let id: String
    let reference: String
    let date: String
    let status: String
    let amount: String
    let image: String?
    let pieces: String
}
struct UFitOrderPiece: Identifiable {
    let id: String
    let name: String
    let image: String?
    let options: String
    let quantity: Int
    let amount: String
}
struct UFitOrderDetailPresentation {
    let reference: String
    let date: String
    let status: String
    let items: [UFitOrderPiece]
    let address: [String]
    let subtotal: String
    let shipping: String
    let taxes: String
    let total: String
    let returnPolicy: String?
    let shipment: UFitShipmentPresentation?
    let cancellationNote: String?
    let cancellationPrompt: String
    let cancellationPending: Bool
    let canCancel: Bool
    let canResumePayment: Bool
    var canRetryRefund = false
}

enum UFitShipmentLifecycle: String, Decodable {
    case pending, preparing, shipped, delivered, failed, cancelled
    var label: String {
        switch self {
        case .pending: String(localized: "En attente de préparation")
        case .preparing: String(localized: "Préparation du colis")
        case .shipped: String(localized: "Colis expédié")
        case .delivered: String(localized: "Colis livré")
        case .failed: String(localized: "Un problème est survenu avec l’expédition")
        case .cancelled: String(localized: "Expédition annulée")
        }
    }
}
enum UFitCancellationOutcome: String, Decodable {
    case notCharged = "not_charged", refunded, refundFailed = "refund_failed", refundCancelled = "refund_canceled", refundBlocked = "refund_blocked"
}
enum UFitCancellationLifecycle: String, Decodable { case requested, succeeded, failed }
enum UFitCancellationRefundLifecycle: String, Decodable { case queued, pending, succeeded, failed, blocked }
enum UFitCancellationRefundProviderStatus: String, Decodable { case pending, requiresAction = "requires_action", succeeded, failed, cancelled = "canceled" }

enum UFitCancellationCopy {
    static func note(reason: UFitCancellationReason, outcome: UFitCancellationOutcome?, refundState: UFitCancellationRefundLifecycle?, providerStatus: UFitCancellationRefundProviderStatus?, total: String, professional: Bool = false) -> String {
        let financial: String
        switch refundState {
        case .succeeded: financial = String(localized: "\(total) ont été remboursés sur le moyen de paiement utilisé.")
        case .failed, .blocked:
            if providerStatus == .cancelled {
                financial = professional ? String(localized: "Le remboursement a été interrompu. Le client peut le reprendre depuis sa commande.") : String(localized: "Le remboursement a été interrompu. Vous pouvez le reprendre ; la commande reste annulée.")
            } else {
                financial = professional ? String(localized: "Le remboursement de \(total) n’a pas abouti. Un autre moyen de remboursement doit être organisé avec le client.") : String(localized: "Le remboursement de \(total) n’a pas abouti. Ufit doit organiser avec vous un autre moyen de remboursement.")
            }
        case .pending where providerStatus == .requiresAction:
            financial = String(localized: "Le remboursement nécessite une vérification supplémentaire. Il n’est pas encore confirmé.")
        case .queued, .pending:
            financial = String(localized: "Le remboursement de \(total) est en cours. La commande ne sera pas expédiée.")
        case nil:
            switch outcome {
            case .notCharged: financial = String(localized: "Aucun paiement n’a été débité.")
            case .refunded: financial = String(localized: "\(total) ont été remboursés sur le moyen de paiement utilisé.")
            case .refundFailed, .refundBlocked: financial = String(localized: "Le remboursement n’a pas abouti. Un autre moyen de remboursement doit être organisé.")
            case .refundCancelled: financial = String(localized: "Le remboursement a été interrompu.")
            case nil: financial = String(localized: "L’annulation est en cours de traitement. La commande ne sera pas expédiée.")
            }
        }
        if reason == .stockUnavailable { return String(localized: "Une pièce est devenue indisponible après le paiement.") + UFitOrderFormatting.spaceBetweenSentences + financial }
        return financial
    }
}

enum UFitCancellationReason: String, Decodable { case customer = "customer_requested", stockUnavailable = "stock_unavailable" }

enum UFitOrderFormatting {
    static let separator = " · "
    static let spaceBetweenSentences = " "
    private static let space = " "
    private static let single = 1
    private static let countryLocale = Locale(identifier: "fr")
    static func date(_ value: String) -> String { UFitTimestamp(isoString: value)?.label ?? String() }
    static func pieceCount(_ count: Int) -> String { count == single ? String(localized: "1 pièce") : String(localized: "\(count) pièces") }
    static func address(_ value: UFitShippingAddress) -> [String] {
        let country = countryLocale.localizedString(forRegionCode: value.country) ?? value.country
        return [value.fullName, value.line1, value.line2, value.postalCode + space + value.city, country].compactMap { $0 }.filter { !$0.isEmpty }
    }
}
