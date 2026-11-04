import Foundation

struct UFitShippingAddress: Codable, Equatable {
    var fullName = String()
    var line1 = String()
    var line2: String?
    var postalCode = String()
    var city = String()
    var country = "CH"
    var phone: String?
}
enum UFitCheckoutStep: Hashable { case address, review, recovery, confirming, paid }

enum UFitCheckoutRecoveryCopy {
    static let title = String(localized: "Retrouver votre achat")
    static let detail = String(localized: "Vérifiez son état avant de recommencer une commande.")
    static let loading = String(localized: "Recherche de votre commande")
    static let absent = String(localized: "Aucune commande enregistrée pour cette tentative pour le moment.")
    static let replay = String(localized: "Reprendre ma commande")
    static let verify = String(localized: "Vérifier la commande")
    static let reviewBeforePayment = String(localized: "Vous pourrez relire la commande avant de payer.")
    static let invalid = String(localized: "Le résultat de la tentative ne peut pas être vérifié. Réessayez.")
    static let localRead = String(localized: "La tentative conservée sur cet appareil ne peut pas être relue. Retrouvez vos commandes depuis votre compte.")
    static let localWrite = String(localized: "Le suivi de cette tentative n’a pas pu être actualisé. Réessayez.")
    static let changed = String(localized: "Votre sélection a changé. Vérifiez de nouveau le montant avant de payer.")
    static let commissionUnavailable = String(localized: "L’achat de cet article n’est pas encore disponible. Réessayez plus tard.")
    static let amount = String(localized: "Montant initial")
    static let cartTitle = String(localized: "Une tentative à vérifier")
    static let cartDetail = String(localized: "Vérifiez votre dernière tentative avant de continuer.")
    static let deliveryRetry = String(localized: "Actualiser la livraison")
    static let localRemoval = String(localized: "Le compte est fermé, mais le suivi local d’une commande n’a pas pu être supprimé. Réessayez.")
}

enum UFitCheckoutRecoveryNotice {
    case pending(amount: String)
    case unavailable
    var actionTitle: String {
        switch self {
        case .pending: UFitCheckoutRecoveryCopy.replay
        case .unavailable: UFitCheckoutRecoveryCopy.verify
        }
    }
}
struct UFitCheckoutSummary {
    let subtotal: String
    let shipping: String
    let taxes: String
    let total: String
    let returnPolicy: String
    let refundPolicy: UFitRefundPolicy
    let taxNotice: String
    let customsNotice: String
}
