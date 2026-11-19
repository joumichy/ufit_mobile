import Foundation

enum UFitAuthenticationMode: CaseIterable, Hashable {
    case signIn, signUp, confirmEmail, recovery, recoverySent, newPassword
    var title: String {
        switch self {
        case .signIn: UFitAuthenticationCopy.signIn
        case .signUp: UFitAuthenticationCopy.signUp
        case .confirmEmail: UFitAuthenticationCopy.confirmEmail
        case .recovery: UFitAuthenticationCopy.recovery
        case .recoverySent: UFitAuthenticationCopy.recoverySent
        case .newPassword: UFitAuthenticationCopy.newPassword
        }
    }
    var awaitsEmail: Bool { self == .confirmEmail || self == .recoverySent }
}
enum UFitAuthenticationCopy {
    static let signIn = String(localized: "Se connecter")
    static let signUp = String(localized: "Créer mon compte")
    static let confirmEmail = String(localized: "Confirmez votre adresse")
    static let recovery = String(localized: "Retrouver mon compte")
    static let recoverySent = String(localized: "Consultez votre e-mail")
    static let newPassword = String(localized: "Nouveau mot de passe")
    static let confirmationDetail = String(localized: "Si un compte attend une confirmation à cette adresse, un lien vous permet de l’activer. Ouvrez-le depuis cet iPhone.")
    static let recoveryDetail = String(localized: "Si un compte correspond à cette adresse, un lien vous permet de choisir un nouveau mot de passe. Ouvrez-le depuis cet iPhone.")
    static let resend = String(localized: "Renvoyer un lien")
    static let changeEmail = String(localized: "Utiliser une autre adresse")
    static let sentAgain = String(localized: "La demande de lien a été renouvelée. Consultez votre messagerie.")
    static let cancelRecovery = String(localized: "Annuler la réinitialisation")
    static let appleFailed = String(localized: "La connexion Apple n’a pas abouti. Réessayez ou utilisez votre adresse e-mail.")
    static let accountTitle = String(localized: "Votre compte")
    static let accountAccess = String(localized: "Connectez-vous pour retrouver vos commandes et vos espaces Ufit.")
    static let accountIcon = "person.crop.circle"
    static let minimumPassword = 8
}
