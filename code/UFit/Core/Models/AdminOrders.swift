import Foundation

struct UFitAdminOrderQuery: Equatable {
    var search = String()
    var status: UFitOrderLifecycle?
    var currency: String?
    var shipmentStatus: UFitShipmentLifecycle?
    var isFiltered: Bool { !search.isEmpty || status != nil || currency != nil || shipmentStatus != nil }
}
enum UFitAdminOrdersCopy {
    static let title = String(localized: "Commandes et paiements"), detail = String(localized: "Supervision de commande")
    static let icon = "shippingbox", refreshIcon = "arrow.clockwise", nextIcon = "chevron.right"
    static let search = String(localized: "Référence ou marque"), status = String(localized: "Commande"), allStatuses = String(localized: "Tous les statuts")
    static let shipping = String(localized: "Expédition"), allShipments = String(localized: "Toutes les expéditions")
    static let currency = String(localized: "Devise"), allCurrencies = String(localized: "Toutes les devises")
    static let refresh = String(localized: "Actualiser"), retry = String(localized: "Réessayer"), returnHome = String(localized: "Retour à l’accueil")
    static let reset = String(localized: "Voir toutes les commandes"), more = String(localized: "Afficher la suite")
    static let loading = String(localized: "Chargement des commandes"), loadingOrder = String(localized: "Chargement de la commande")
    static let loadingReturns = String(localized: "Chargement des retours")
    static let empty = String(localized: "Aucune commande"), noMatches = String(localized: "Aucune commande pour ces critères")
    static let access = String(localized: "Cet espace n’est plus accessible. Revenez à l’accueil et actualisez vos accès.")
    static let missing = String(localized: "Cette commande est indisponible. Actualisez la liste pour continuer.")
    static let changed = String(localized: "Les commandes ont changé. Actualisez la liste pour continuer.")
    static let listFailure = String(localized: "Les commandes n’ont pas pu être chargées. Réessayez.")
    static let detailFailure = String(localized: "La commande n’a pas pu être chargée. Réessayez.")
    static let returnsFailure = String(localized: "Les retours de cette commande n’ont pas pu être chargés. Réessayez.")
    static let payments = String(localized: "Paiements enregistrés")
    static let noPaymentDetail = String(localized: "Aucun paiement confirmé n’est enregistré pour cette commande.")
    static let paymentSucceeded = String(localized: "Encaissement confirmé"), paymentRefunded = String(localized: "Paiement remboursé")
    static let paymentDetails = String(localized: "Référence de paiement"), provider = String(localized: "Prestataire"), paymentReference = String(localized: "Référence Stripe")
    static let updatedAt = String(localized: "Mis à jour le")
    static let returns = String(localized: "Retours et remboursements"), noReturns = String(localized: "Aucun retour pour cette commande")
    static let contents = String(localized: "Pièces commandées"), address = String(localized: "Adresse de livraison"), brand = String(localized: "Marque")
    static let noShipment = String(localized: "Aucune expédition enregistrée")
    static let searchDebounce = Duration.milliseconds(300)
    static let locale = Locale(identifier: "fr_CH")
    static func count(_ count: Int) -> String { String(localized: "Commandes : \(count)") }
    static func returnsCount(_ count: Int) -> String { String(localized: "Retours : \(count)") }
    static func observed(_ date: UFitTimestamp) -> String { String(localized: "Actualisé le \(date.value.formatted(.dateTime.day().month(.wide).hour().minute().locale(locale)))") }
}
