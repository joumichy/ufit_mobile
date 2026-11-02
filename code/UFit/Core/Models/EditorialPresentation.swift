import Foundation

enum UFitEditorialCopy {
    static let title = String(localized: "Sélections")
    static let open = String(localized: "Voir les sélections Ufit")
    static let eyebrow = String(localized: "Le regard Ufit")
    static let loading = String(localized: "Chargement des sélections")
    static let loadingCollection = String(localized: "Chargement de la sélection")
    static let empty = String(localized: "Les prochaines sélections arrivent")
    static let failed = String(localized: "Sélections indisponibles")
    static let loadFailed = String(localized: "Les sélections n’ont pas pu être chargées. Réessayez.")
    static let collectionFailedTitle = String(localized: "Sélection indisponible")
    static let collectionFailed = String(localized: "Cette sélection n’a pas pu être chargée. Réessayez.")
    static let unavailable = String(localized: "Cette sélection n’est plus disponible")
    static let missing = String(localized: "Elle a été retirée ou ses contenus ne sont plus accessibles.")
    static let emptyItems = String(localized: "Aucune référence disponible")
    static let changed = String(localized: "Cette sélection a changé. Actualisez-la pour continuer.")
    static let retry = String(localized: "Réessayer")
    static let refresh = String(localized: "Actualiser")
    static let more = String(localized: "Voir la suite")
    static let loadingMore = String(localized: "Chargement de la suite")
    static let moreFailed = String(localized: "La suite n’a pas pu être chargée. Vous pouvez réessayer.")
    static let outfit = String(localized: "Tenue")
    static let product = String(localized: "Pièce")
    static let openingFailed = String(localized: "Cette référence n’a pas pu être ouverte. Réessayez ou actualisez la sélection.")
    static let icon = "rectangle.stack"; static let refreshIcon = "arrow.clockwise"; static let errorIcon = "wifi.exclamationmark"
    static let chevron = "chevron.right"; static let photo = "photo"
    private static let singularCount = 1
    static func count(_ count: Int) -> String { count == singularCount ? String(localized: "1 référence") : String(localized: "\(count) références") }
}
