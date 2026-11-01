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
enum UFitCancellationOutcome: String, Decodable { case notCharged = "not_charged", refunded }

enum UFitCancellationReason: String, Decodable { case customer = "customer_requested", stockUnavailable = "stock_unavailable" }

enum UFitOrderFormatting {
    static let separator = " · "
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
