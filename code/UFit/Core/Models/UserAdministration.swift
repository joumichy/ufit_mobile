import Foundation

enum UFitUserAccessDecision: String, CaseIterable, Identifiable {
    case suspend, activate, grantAdmin, revokeAdmin
    var id: String { rawValue }
    var label: String {
        switch self {
        case .suspend: String(localized: "Suspendre le compte")
        case .activate: String(localized: "Activer le compte")
        case .grantAdmin: String(localized: "Accorder l’accès admin")
        case .revokeAdmin: String(localized: "Retirer l’accès admin")
        }
    }
    var consequence: String {
        switch self {
        case .suspend: String(localized: "Le compte ne pourra plus accéder aux fonctions authentifiées d’Ufit. Ses commandes et données restent conservées.")
        case .activate: String(localized: "Le compte retrouvera les accès liés à ses rôles. Les statuts de ses profils marque et créateur restent distincts.")
        case .grantAdmin: String(localized: "Cette personne pourra examiner les dossiers et utiliser les outils d’administration. Elle ne pourra pas attribuer des accès admin.")
        case .revokeAdmin: String(localized: "L’accès aux outils d’administration sera retiré. Les autres rôles de ce compte restent conservés.")
        }
    }
    var isDestructive: Bool { self == .suspend || self == .revokeAdmin }
    var historyLabel: String {
        switch self {
        case .suspend: String(localized: "Compte suspendu")
        case .activate: String(localized: "Compte activé")
        case .grantAdmin: String(localized: "Accès admin accordé")
        case .revokeAdmin: String(localized: "Accès admin retiré")
        }
    }
}

struct UFitAdministeredUserRow: Identifiable {
    let id: String
    let email: String
    let displayName: String?
    let status: UFitAccountStatus
    let roles: [UFitUserRole]
    let version: Int
    var name: String {
        guard let displayName, !UFitServerTextInput.trimmed(displayName).isEmpty else { return email }
        return displayName
    }
    var hasDistinctName: Bool { name != email }
}

struct UFitAdministeredUserDocument {
    let user: UFitAdministeredUserRow
    let createdAt: String
    let updatedAt: String
    let decisions: [UFitUserAccessDecision]
}

struct UFitUserAccessHistoryRow: Identifiable {
    let id: String
    let version: Int
    let decision: UFitUserAccessDecision
    let reason: String
    let date: String
    let actorID: String
}

enum UFitUserAdministrationCopy {
    static let title = String(localized: "Utilisateurs")
    static let account = String(localized: "Compte")
    static let unavailable = String(localized: "Accès indisponible")
    static let back = String(localized: "Retour")
    static let search = String(localized: "Nom ou e-mail")
    static let searchAction = String(localized: "Rechercher")
    static let status = String(localized: "Statut")
    static let role = String(localized: "Rôle")
    static let roles = String(localized: "Rôles")
    static let allStatuses = String(localized: "Tous les statuts")
    static let allRoles = String(localized: "Tous les rôles")
    static let allUsers = String(localized: "Tous les comptes")
    static let empty = String(localized: "Aucun compte")
    static let noMatches = String(localized: "Aucun compte pour cette recherche")
    static let loading = String(localized: "Chargement des comptes")
    static let loadingHistory = String(localized: "Chargement de l’historique")
    static let retry = String(localized: "Réessayer")
    static let refresh = String(localized: "Actualiser")
    static let more = String(localized: "Afficher la suite")
    static let access = String(localized: "Accès")
    static let history = String(localized: "Décisions d’accès")
    static let noHistory = String(localized: "Aucune décision d’accès enregistrée")
    static let noRoles = String(localized: "Aucun rôle attribué")
    static let accountDetails = String(localized: "Informations du compte")
    static let created = String(localized: "Création")
    static let updated = String(localized: "Mise à jour du compte")
    static let version = String(localized: "Version d’accès")
    static let author = String(localized: "Identifiant de l’auteur")
    static let details = String(localized: "Détails de la décision")
    static let reason = String(localized: "Motif")
    static let reloadReference = String(localized: "Actualiser les accès")
    static let discardTitle = String(localized: "Abandonner le motif saisi ?")
    static let discard = String(localized: "Abandonner")
    static let keepEditing = String(localized: "Continuer")
    static let roleSeparator = " · "
}

