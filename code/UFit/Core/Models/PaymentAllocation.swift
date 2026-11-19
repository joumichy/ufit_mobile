import Foundation

enum UFitPaymentAllocationCopy {
    static let title = String(localized: "Répartition initiale"), icon = "chart.pie"
    static let loading = String(localized: "Lecture de la répartition"), net = String(localized: "Net initial réparti")
    static let scope = String(localized: "Avant remboursements et versements."), purchase = String(localized: "Achat client")
    static let platform = String(localized: "Ufit"), brand = String(localized: "Marque"), creators = String(localized: "Commissions créateur")
    static let gross = String(localized: "Part brute"), fee = String(localized: "Frais Stripe"), totalFees = String(localized: "Frais Stripe totaux")
    static let original = String(localized: "Commission à l’achat"), emptyCreators = String(localized: "Aucune commission créateur sur cet achat.")
    static let prepare = String(localized: "Calculer la répartition"), prepareTitle = String(localized: "Répartition à calculer")
    static let prepareScope = String(localized: "Le calcul enregistre les parts initiales sans effectuer de versement.")
    static let check = String(localized: "Vérifier le calcul"), back = String(localized: "Retour au règlement")
    static let deficit = String(localized: "Une part ne couvre pas les frais Stripe. Ce déficit doit être traité avant tout versement.")
    static let loadFailed = String(localized: "La répartition n’a pas pu être actualisée. Réessayez.")
    static let invalid = String(localized: "Les données de répartition reçues sont incohérentes. Actualisez avant de continuer.")
    static let missing = String(localized: "Ce paiement n’est plus disponible. Revenez à la commande et actualisez.")
    static let unconfirmed = String(localized: "Le calcul n’a pas pu être confirmé. Vérifiez son statut avant de continuer.")
    static let notStarted = String(localized: "Aucun calcul enregistré. Vous pouvez réessayer.")
    static let references = String(localized: "Références du calcul"), terms = String(localized: "Conditions d’achat"), preparedAt = String(localized: "Calcul enregistré le")
}
extension UFitPaymentAllocationDocument.BlockReason {
    var title: String {
        switch self {
        case .terms: String(localized: "Conditions d’achat absentes")
        case .settlement: String(localized: "Règlement à vérifier")
        case .fulfillment: String(localized: "Commande non finalisée")
        case .basis: String(localized: "Calcul à vérifier")
        }
    }
    var message: String {
        switch self {
        case .terms: String(localized: "Ce paiement ne possède pas de conditions de répartition figées à l’achat. Aucun calcul n’a été créé.")
        case .settlement: String(localized: "Les montants réglés par Stripe sont nécessaires pour calculer les parts.")
        case .fulfillment: String(localized: "La commande doit être finalisée avant de calculer sa répartition.")
        case .basis: String(localized: "Les informations de ce paiement doivent être vérifiées avant de calculer les parts.")
        }
    }
}
