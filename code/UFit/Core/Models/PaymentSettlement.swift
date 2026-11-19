import Foundation

enum UFitPaymentSettlementCopy {
    static let title = String(localized: "Règlement Stripe"), loading = String(localized: "Lecture du règlement")
    static let customerAmount = String(localized: "Encaissement client"), initial = String(localized: "Règlement initial")
    static let gross = String(localized: "Brut"), fees = String(localized: "Frais Stripe"), net = String(localized: "Net initial")
    static let initialScope = String(localized: "Avant remboursements et versements.")
    static let conversion = String(localized: "Conversion par Stripe"), test = String(localized: "Mode test")
    static let notRequested = String(localized: "Règlement à vérifier"), verify = String(localized: "Vérifier l’encaissement")
    static let checking = String(localized: "Vérification en cours"), review = String(localized: "Vérification nécessaire")
    static let retry = String(localized: "Relancer la vérification"), refreshStatus = String(localized: "Actualiser le statut")
    static let references = String(localized: "Références Stripe"), paymentIntent = String(localized: "Paiement")
    static let charge = String(localized: "Encaissement"), transaction = String(localized: "Écriture de règlement")
    static let recorded = String(localized: "Données enregistrées le")
    static let icon = "banknote", lookup = "doc.text.magnifyingglass", reviewIcon = "doc.text.viewfinder"
    static let loadFailed = String(localized: "Le règlement n’a pas pu être actualisé. Réessayez.")
    static let unconfirmed = String(localized: "Le statut de la vérification n’a pas pu être confirmé. Actualisez pour continuer.")
    static let notStarted = String(localized: "La vérification n’a pas encore démarré. Vous pouvez la relancer.")
    static let missing = String(localized: "Cet encaissement n’est plus disponible. Revenez à la commande et actualisez.")
    static let unsupported = String(localized: "Cet encaissement ne peut pas être vérifié auprès de Stripe.")
    static let invalid = String(localized: "Les données du règlement reçues sont incohérentes. Actualisez avant de continuer.")
    private static let locale = Locale(identifier: "fr_CH")
    static func consulted(_ date: UFitTimestamp) -> String {
        String(localized: "Consulté le \(date.value.formatted(.dateTime.day().month(.wide).hour().minute().locale(locale)))")
    }
    static func retryAt(_ date: UFitTimestamp) -> String {
        String(localized: "Nouvelle vérification prévue à \(date.value.formatted(.dateTime.hour().minute().locale(locale)))")
    }
}
extension UFitPaymentSettlementDocument.Failure {
    var label: String {
        switch self {
        case .missing: String(localized: "Cet encaissement n’a pas été retrouvé chez Stripe.")
        case .balancePending: String(localized: "Stripe prépare encore les montants du règlement.")
        case .unavailable: String(localized: "Stripe est momentanément indisponible.")
        case .mismatch, .invalid, .linked, .changed: String(localized: "Les informations de cet encaissement doivent être vérifiées.")
        }
    }
}
