import Foundation

enum UFitNotificationPermission: Equatable { case unknown, notAsked, denied, allowed }
enum UFitNotificationDevicePhase: Equatable { case idle, waitingForToken, linking, linked, failed }
enum UFitNotificationDeviceCopy {
    static let title = String(localized: "Cet iPhone")
    static let checking = String(localized: "Vérification de l’autorisation…")
    static let notAsked = String(localized: "Autorisez Ufit à afficher les mises à jour sur cet iPhone.")
    static let denied = String(localized: "Les notifications sont désactivées dans les réglages de cet iPhone.")
    static let allowed = String(localized: "Les notifications sont autorisées sur cet iPhone.")
    static let linking = String(localized: "Association de cet iPhone à votre compte…")
    static let token = String(localized: "Connexion aux notifications…")
    static let linked = String(localized: "Cet iPhone est associé à votre compte.")
    static let unavailable = String(localized: "Cet iPhone n’a pas pu être associé. Réessayez.")
    static let authorize = String(localized: "Autoriser sur cet iPhone")
    static let settings = String(localized: "Ouvrir les réglages")
    static let retry = String(localized: "Réessayer")
    static let settingsFailed = String(localized: "Les réglages n’ont pas pu être ouverts. Réessayez.")
}
