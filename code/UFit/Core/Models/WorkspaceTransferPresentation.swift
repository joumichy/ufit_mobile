import Foundation

enum UFitWorkspaceTransfersCopy {
    static let title = String(localized: "Versements"), refresh = String(localized: "Actualiser les versements")
    static let loading = String(localized: "Lecture des versements"), more = String(localized: "Voir les opérations suivantes")
    static let scope = String(localized: "Transferts confirmés en devise de règlement sur votre compte Stripe. Les virements vers votre banque ne sont pas suivis ici.")
    static let net = String(localized: "Net transféré"), transferred = String(localized: "Transféré"), recovered = String(localized: "Récupéré")
    static let test = String(localized: "Mode test"), live = String(localized: "Réel"), history = String(localized: "Mouvements")
    static let transfer = String(localized: "Transfert"), reversal = String(localized: "Récupération de transfert")
    static let empty = String(localized: "Pas encore de versement"), emptyScope = String(localized: "Vos transferts et récupérations apparaîtront ici une fois confirmés.")
    static let account = String(localized: "Compte de versement"), accountIcon = "creditcard", historyIcon = "arrow.up.arrow.down"
    static let details = String(localized: "Références de l’opération"), receipt = String(localized: "Référence Stripe"), original = String(localized: "Transfert d’origine")
    static let created = String(localized: "Créé le"), recorded = String(localized: "Enregistré le"), order = String(localized: "Commande")
    static let previous = String(localized: "Dernières données consultées"), retry = String(localized: "Réessayer"), back = String(localized: "Retour aux revenus")
    static let unavailable = String(localized: "Accès indisponible"), unavailableScope = String(localized: "Cet espace n’est plus accessible. Revenez aux revenus pour actualiser vos accès.")
    static let changed = String(localized: "L’historique a changé. Actualisez-le avant de poursuivre."), invalid = String(localized: "Les versements reçus sont incohérents. Actualisez l’historique avant de continuer.")
    static let refreshHistory = String(localized: "Actualiser l’historique"), loadingMore = String(localized: "Lecture des opérations suivantes")
    private static let locale = Locale(identifier: "fr_CH")
    static func date(_ value: UFitTimestamp) -> String { value.value.formatted(.dateTime.day().month(.abbreviated).year().hour().minute().locale(locale)) }
    static func consulted(_ value: UFitTimestamp) -> String { String(localized: "Consulté le \(date(value))") }
}
