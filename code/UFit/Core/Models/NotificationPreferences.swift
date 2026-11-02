import Foundation

struct UFitNotificationChoices: Equatable {
    var emailEnabled: Bool
    var pushEnabled: Bool
}

enum UFitNotificationPreferencesCopy {
    static let title = String(localized: "Notifications")
    static let introduction = String(localized: "Choisissez comment recevoir les mises à jour de vos candidatures et commandes.")
    static let email = String(localized: "E-mails")
    static let emailDetail = String(localized: "À l’adresse de votre compte.")
    static let push = String(localized: "Notifications push")
    static let pushDetail = String(localized: "Sur les appareils où vous les avez autorisées.")
    static let loading = String(localized: "Chargement de vos préférences")
    static let unavailable = String(localized: "Préférences indisponibles")
    static let loadFailed = String(localized: "Vos préférences n’ont pas pu être chargées. Réessayez.")
    static let save = String(localized: "Enregistrer")
    static let retry = String(localized: "Réessayer")
    static let refresh = String(localized: "Actualiser")
    static let saved = String(localized: "Vos préférences sont enregistrées.")
    static let changed = String(localized: "Vos préférences ont changé ailleurs. Actualisez avant d’enregistrer ; votre sélection sera conservée.")
    static let uncertain = String(localized: "L’enregistrement n’a pas pu être confirmé. Actualisez pour vérifier vos préférences ; votre sélection sera conservée.")
    static let refreshed = String(localized: "Les préférences actuelles ont été chargées. Votre sélection est conservée.")
    static let current = String(localized: "Actuellement enregistrées")
    static let enabled = String(localized: "Activés")
    static let disabled = String(localized: "Désactivés")
    static let inProgress = String(localized: "Les messages déjà en cours d’envoi peuvent encore arriver.")
    static let readOnly = String(localized: "Ces préférences sont consultables mais ne peuvent plus être modifiées.")
    static let leave = String(localized: "Quitter sans conserver votre sélection ?")
    static let leaveDetail = String(localized: "Les modifications locales seront perdues.")
    static let discard = String(localized: "Quitter")
    static let keep = String(localized: "Continuer")
    static let bell = "bell"
    static let refreshIcon = "arrow.clockwise"
}
