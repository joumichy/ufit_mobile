import SwiftUI

// Presentation projections only. Hosts map the canonical DTO fields without inventing missing history.
struct UFitCreatorGradeAssignmentPresentation: Identifiable {
    let id: String
    let displayName: String
    let slug: String
    let creatorStatus: UFitProfileStatus
    let accountStatus: UFitAccountStatus
    let gradeCode: String
    let gradeLabel: String
    let gradeRank: Int
    let version: Int
}

struct UFitCreatorGradeChangePresentation: Identifiable {
    let id: String
    let version: Int?
    let sourceLabel: String?
    let fromGradeCode: String?
    let fromGradeLabel: String?
    let toGradeCode: String
    let toGradeLabel: String?
    let actorID: String?
    let reason: String?
    let recordedAt: String
}

enum UFitCreatorGradeAdministrationSection: Hashable { case assignments, definitions }

enum CreatorGradePresentationCopy {
    static let back = String(localized: "Retour")
    static let section = String(localized: "Administration des grades")
    static let assignments = String(localized: "Attributions")
    static let definitions = String(localized: "Grades")
    static let search = String(localized: "Rechercher")
    static let searchCreator = String(localized: "Rechercher un créateur")
    static let clear = String(localized: "Effacer la recherche et les filtres")
    static let all = String(localized: "Tous les grades")
    static let availability = String(localized: "Attribution")
    static let loading = String(localized: "Chargement des grades")
    static let loadingAssignments = String(localized: "Chargement des attributions")
    static let loadingHistory = String(localized: "Chargement de l’historique")
    static let unavailable = String(localized: "Grades indisponibles")
    static let assignmentsUnavailable = String(localized: "Attributions indisponibles")
    static let emptyDefinitions = String(localized: "Aucun grade")
    static let emptyDefinitionsSearch = String(localized: "Aucun grade pour cette sélection")
    static let emptyAssignments = String(localized: "Aucune attribution")
    static let emptyAssignmentsSearch = String(localized: "Aucun créateur pour cette recherche")
    static let emptyChoices = String(localized: "Aucun autre grade disponible")
    static let emptyChoicesMessage = String(localized: "Un autre grade attribuable est nécessaire pour effectuer ce changement.")
    static let noHistory = String(localized: "Aucun événement dans l’historique")
    static let revise = String(localized: "Modifier le grade")
    static let change = String(localized: "Changer le grade")
    static let confirmChange = String(localized: "Confirmer l’attribution")
    static let currentGrade = String(localized: "Grade actuel")
    static let newGrade = String(localized: "Nouveau grade")
    static let chooseGrade = String(localized: "Choisir un grade")
    static let chooseAnother = String(localized: "Choisir un autre grade")
    static let creator = String(localized: "Créateur")
    static let account = String(localized: "Compte")
    static let profile = String(localized: "Profil créateur")
    static let version = String(localized: "Version")
    static let currentRevision = String(localized: "Révision actuelle")
    static let currentDefinition = String(localized: "Définition actuelle")
    static let previousGrade = String(localized: "Grade précédent")
    static let attributedGrade = String(localized: "Grade attribué")
    static let actor = String(localized: "Identifiant de l’administrateur")
    static let sourceUnknown = String(localized: "Origine non renseignée")
    static let sourceApplication = String(localized: "Candidature acceptée")
    static let sourceAdministration = String(localized: "Administration")
    static let readOnlyCode = String(localized: "Le code identifie le grade et ne peut pas être modifié.")
    static let codeHint = String(localized: "Une lettre minuscule, puis des lettres minuscules, des chiffres ou des tirets.")
    static let rankHint = String(localized: "Un entier positif ou nul.")
    static let reload = String(localized: "Actualiser le grade")
    static let reloadAssignment = String(localized: "Actualiser l’attribution")
    static let retainedInput = String(localized: "Votre saisie est conservée. Vérifiez la nouvelle référence avant de confirmer.")
    static let selectedUnavailable = String(localized: "Le grade sélectionné n’est plus disponible. Choisissez un autre grade.")
    static let changeConsequence = String(localized: "Le nouveau grade remplace le grade actuel du créateur. Les achats passés conservent leurs règles de commission.")
    static let definitionConsequence = String(localized: "Cette révision modifie la définition du grade. Les achats passés conservent leurs règles de commission.")
    static let emptySymbol = "tag"
    static let creatorSymbol = "person.crop.circle"
    static let historySymbol = "clock.arrow.circlepath"
    static let errorSymbol = "exclamationmark.circle"
    static let refreshSymbol = "arrow.clockwise"
    static let addSymbol = "plus"
    static let nextSymbol = "chevron.right"
    static let checkSymbol = "checkmark"
    static let sectionOptions: [UFitSelectionOption<UFitCreatorGradeAdministrationSection>] = [
        .init(value: .assignments, title: assignments), .init(value: .definitions, title: definitions)
    ]
    static let availabilityOptions: [UFitSelectionOption<Bool?>] = [
        .init(value: nil, title: all),
        .init(value: true, title: UFitCreatorGradeAdminCopy.assignable),
        .init(value: false, title: UFitCreatorGradeAdminCopy.unavailable)
    ]
    static func version(_ value: Int) -> String { String(localized: "Version \(value)") }
}

struct UFitCreatorGradeFacts: View {
    let grade: UFitCreatorGradeRow
    var body: some View {
        VStack(alignment: .leading, spacing: UFitSpace.md) {
            Text(grade.label).font(UFitTypography.title2).accessibilityAddTraits(.isHeader)
            Text(grade.id).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText).textSelection(.enabled)
            UFitLabeledValue(UFitCreatorGradeAdminCopy.rank) { Text(grade.rank, format: .number).monospacedDigit() }
            UFitLabeledValue(CreatorGradePresentationCopy.availability, value: grade.assignable ? UFitCreatorGradeAdminCopy.assignable : UFitCreatorGradeAdminCopy.unavailable)
            UFitLabeledValue(UFitCreatorGradeAdminCopy.assignedCreators) { Text(grade.assignedCreators, format: .number).monospacedDigit() }
            UFitLabeledValue(CreatorGradePresentationCopy.version) { Text(grade.version, format: .number).monospacedDigit() }
            if grade.isInitial { Text(UFitCreatorGradeAdminCopy.initialExplanation).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText) }
        }.font(UFitTypography.subheadline).frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct UFitCreatorGradeAssignmentFacts: View {
    let assignment: UFitCreatorGradeAssignmentPresentation
    var body: some View {
        VStack(alignment: .leading, spacing: UFitSpace.md) {
            Text(assignment.displayName).font(UFitTypography.title2).accessibilityAddTraits(.isHeader)
            Text(assignment.slug).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
            UFitLabeledValue(CreatorGradePresentationCopy.currentGrade, value: assignment.gradeLabel)
            UFitLabeledValue(UFitCreatorGradeAdminCopy.code, value: assignment.gradeCode)
            UFitLabeledValue(UFitCreatorGradeAdminCopy.rank) { Text(assignment.gradeRank, format: .number).monospacedDigit() }
            UFitLabeledValue(CreatorGradePresentationCopy.account, value: assignment.accountStatus.label)
            UFitLabeledValue(CreatorGradePresentationCopy.profile, value: assignment.creatorStatus.label)
            UFitLabeledValue(CreatorGradePresentationCopy.version) { Text(assignment.version, format: .number).monospacedDigit() }
        }.font(UFitTypography.subheadline).frame(maxWidth: .infinity, alignment: .leading)
    }
}
