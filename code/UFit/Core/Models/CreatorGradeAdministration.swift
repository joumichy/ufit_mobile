import Foundation

struct UFitCreatorGradeDraft: Equatable {
    var code = String()
    var label = String()
    var rank = String()
    var assignable = true
    var reason = String()
}
enum UFitCreatorGradeField: Hashable { case code, label, rank, reason }
struct UFitCreatorGradeRow: Identifiable, Equatable {
    let id: String; let label: String; let rank: Int; let assignable: Bool; let isInitial: Bool; let assignedCreators: Int; let version: Int
}
struct UFitCreatorGradeChangeDraft: Equatable {
    var grade: UFitCreatorGradeRow?
    var reason = String()
}
enum UFitCreatorGradeChangeField: Hashable { case grade, reason }
struct UFitCreatorGradeRevisionRow: Identifiable {
    let id: String; let version: Int; let label: String; let rank: Int; let assignable: Bool; let reason: String?; let recordedAt: String; let isCurrent: Bool
}
enum UFitCreatorGradeAdminCopy {
    static let definitionChanged = String(localized: "Ce grade a changé. Actualisez le grade avant de réessayer. Votre saisie est conservée.")
    static let definitionUpdated = String(localized: "Le grade est à jour. Vérifiez votre saisie avant d’enregistrer.")
    static let assignmentChanged = String(localized: "Le grade, le créateur ou son accès a changé. Actualisez l’attribution avant de réessayer. Votre saisie est conservée.")
    static let assignmentUpdated = String(localized: "L’attribution est à jour. Vérifiez le grade choisi et votre motif avant de confirmer.")
    static let title = String(localized: "Grades créateurs")
    static let definitions = String(localized: "Grades")
    static let assignments = String(localized: "Créateurs")
    static let create = String(localized: "Nouveau grade")
    static let edit = String(localized: "Modifier le grade")
    static let save = String(localized: "Créer le grade")
    static let revise = String(localized: "Enregistrer la révision")
    static let code = String(localized: "Code")
    static let label = String(localized: "Nom du grade")
    static let rank = String(localized: "Rang")
    static let assignable = String(localized: "Attribuable")
    static let unavailable = String(localized: "Non attribuable")
    static let activation = String(localized: "Autoriser les nouvelles attributions")
    static let initial = String(localized: "Grade initial")
    static let initialExplanation = String(localized: "Attribué après acceptation d’une candidature. Il reste disponible.")
    static let assignedCreators = String(localized: "Créateurs associés")
    static let reason = String(localized: "Motif")
    static let history = String(localized: "Historique")
    static let revision = String(localized: "Révision")
    static let retry = String(localized: "Réessayer")
    static let refresh = String(localized: "Actualiser")
    static let more = String(localized: "Afficher la suite")
    static let empty = String(localized: "Aucun grade pour cette recherche.")
    static let search = String(localized: "Rechercher un grade")
    static let reloadReference = String(localized: "Actualiser la référence")
    static let separateRates = String(localized: "Les taux de commission se configurent séparément, par marque et grade.")
    static let existingAssignments = String(localized: "Désactiver ce choix conserve les grades déjà attribués.")
    static let discardTitle = String(localized: "Abandonner les modifications ?")
    static let discard = String(localized: "Abandonner")
    static let keepEditing = String(localized: "Continuer la modification")
}
