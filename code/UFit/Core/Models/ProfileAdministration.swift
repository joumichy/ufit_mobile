import Foundation

enum UFitProfileAdministrationCopy {
    static let title = String(localized: "Profils professionnels")
    static let creators = String(localized: "Créateur"), brands = String(localized: "Marques")
    static let brand = String(localized: "Marque")
    static let empty = String(localized: "Aucun profil pour ce compte"), loading = String(localized: "Chargement des profils")
    static let icon = "person.crop.square", nextIcon = "chevron.right", refreshIcon = "arrow.clockwise"
    static let kind = String(localized: "Type de profil"), status = String(localized: "Statut du profil")
    static let change = String(localized: "Changer le statut"), history = String(localized: "Décisions sur le profil")
    static let noHistory = String(localized: "Aucune décision administrative enregistrée"), saved = String(localized: "Statut du profil mis à jour")
    static let profileUnavailable = String(localized: "Ce profil est indisponible. Revenez à la liste pour l’actualiser.")
    static let conflict = String(localized: "Le profil a changé. Actualisez-le avant de décider. Votre motif est conservé.")
    static let referenceUpdated = String(localized: "Profil actualisé. Vérifiez la décision avant de confirmer.")
    static let reasonRequired = String(localized: "Ajoutez un motif de 1 à 500 caractères.")
    static let cancel = String(localized: "Annuler la décision")
    static let reload = String(localized: "Actualiser le profil")
    static let listFailure = String(localized: "Les profils n’ont pas pu être chargés. Réessayez.")
    static let detailFailure = String(localized: "Le profil n’a pas pu être actualisé. Réessayez.")
    static let historyFailure = String(localized: "L’historique n’a pas pu être chargé. Réessayez.")
    static let uncertain = String(localized: "Le résultat de la décision n’a pas pu être confirmé. Actualisez le profil avant de réessayer. Votre motif est conservé.")
    static let locale = Locale(identifier: "fr_CH")
    static let noActions = String(localized: "Aucune décision disponible pour ce profil et ses accès actuels.")
    static let visibility = String(localized: "La suspension retire le profil de la sélection publique et bloque son espace professionnel. Les commandes et données sont conservées.")
    static let pauseConsequence = String(localized: "Le profil quitte la sélection publique. Son équipe conserve son espace de gestion et peut le réactiver.")
    static let activateConsequence = String(localized: "Le profil retrouve sa visibilité publique et son espace professionnel. Les contenus conservent leur propre statut de modération.")
    static func action(_ status: UFitProfileStatus) -> String {
        switch status {
        case .active: String(localized: "Activer le profil")
        case .paused: String(localized: "Mettre le profil en pause")
        case .suspended: String(localized: "Suspendre le profil")
        case .draft: status.label
        }
    }
    static func consequence(_ status: UFitProfileStatus) -> String {
        switch status { case .active: activateConsequence; case .paused: pauseConsequence; case .suspended: visibility; case .draft: String() }
    }
}
