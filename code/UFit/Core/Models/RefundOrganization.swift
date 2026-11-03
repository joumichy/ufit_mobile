import Foundation

enum UFitRefundOrganizationScope: String, Codable {case administrator, customer, brand}
enum UFitRefundOrganizationStatus: String, Decodable {case awaitingCustomer = "awaiting_customer", ready}
enum UFitRefundOrganizationAction: String, Codable {case arrange, provideDetails = "provide_details"}
enum UFitRefundOrganizationField: Hashable {case method, instructions, details}
struct UFitRefundOrganizationDraft: Equatable, Codable {
    var methodLabel = String()
    var instructions = String()
    var details = String()
}
enum UFitRefundOrganizationCopy {
    static let title = String(localized: "Remboursement")
    static let follow = String(localized: "Suivre le remboursement")
    static let arrange = String(localized: "Organiser le remboursement")
    static let editInstructions = String(localized: "Modifier les instructions")
    static let reply = String(localized: "Renseigner mes coordonnées")
    static let editReply = String(localized: "Modifier mes coordonnées")
    static let method = String(localized: "Mode de remboursement convenu")
    static let instructions = String(localized: "Instructions pour le client")
    static let clientInstructions = String(localized: "Instructions de remboursement")
    static let pendingTitle = String(localized: "Demande à vérifier")
    static let details = String(localized: "Coordonnées pour ce remboursement")
    static let sentDetails = String(localized: "Coordonnées transmises")
    static let saveInstructions = String(localized: "Publier les instructions")
    static let saveReply = String(localized: "Transmettre mes coordonnées")
    static let privacy = String(localized: "Ces coordonnées sont accessibles à la marque de cette commande et à l’administration Ufit. N’indiquez aucun numéro de carte ni mot de passe.")
    static let changedInstructions = String(localized: "Le client devra répondre à ces nouvelles instructions. Ses anciennes coordonnées resteront dans l’historique du dossier.")
    static let unorganized = String(localized: "Le remboursement doit être organisé avec Ufit.")
    static let awaitingCustomer = String(localized: "Réponse du client attendue")
    static let awaitingYourDetails = String(localized: "Vos coordonnées sont attendues")
    static let ready = String(localized: "Prêt à traiter")
    static let noPaymentYet = String(localized: "Les coordonnées ont été transmises. Le remboursement n’est pas encore confirmé.")
    static let retry = String(localized: "Réessayer")
    static let loading = String(localized: "Chargement du remboursement")
    static let refresh = String(localized: "Actualiser le remboursement")
    static let unavailable = String(localized: "Ce remboursement n’est plus accessible")
    static let saved = String(localized: "Les informations ont été enregistrées.")
    static let invalid = String(localized: "Corrigez les champs indiqués.")
    static let required = String(localized: "Renseignez ce champ.")
    static let changed = String(localized: "Le dossier a changé. Votre saisie est conservée ; comparez avec les informations actuelles.")
    static let current = String(localized: "Informations actuelles")
    static let compare = String(localized: "Comparer avec le dossier actuel")
    static let useCurrentVersion = String(localized: "Reprendre ma saisie sur cette version")
    static let uncertain = String(localized: "La réponse n’a pas été confirmée. Vérifiez l’enregistrement avant de modifier la demande.")
    static let verify = String(localized: "Vérifier l’enregistrement")
    static let retryExact = String(localized: "Réessayer la même demande")
    static let notRecorded = String(localized: "Cette demande n’est pas encore enregistrée. Vous pouvez la renvoyer à l’identique.")
    static let discard = String(localized: "Abandonner la saisie ?")
    static let abandon = String(localized: "Abandonner")
    static let keepEditing = String(localized: "Continuer la saisie")
    static let cancel = String(localized: "Annuler")
    static let recoverLocal = String(localized: "Relire le dossier et reprendre")
    static let localRecovered = String(localized: "Le dossier a été relu. La demande locale illisible a été conservée à part ; vérifiez les informations avant une nouvelle saisie.")
    static let saving = String(localized: "Enregistrement en cours")
    static func tooLong(_ maximum: Int) -> String {String(localized: "Limitez ce champ à \(maximum) caractères.")}
}
enum UFitRefundOrganizationRules {
    static let methodMaximum = 120, instructionsMaximum = 4000, detailsMaximum = 2000, maximumVersion = 2147483647, firstVersion = 1, versionStep = 1
    static func errors(_ draft: UFitRefundOrganizationDraft, action: UFitRefundOrganizationAction) -> [UFitRefundOrganizationField: String] {
        let fields: [(UFitRefundOrganizationField, String, Int)] = action == .arrange ? [(.method, draft.methodLabel, methodMaximum), (.instructions, draft.instructions, instructionsMaximum)] : [(.details, draft.details, detailsMaximum)]
        return Dictionary(uniqueKeysWithValues: fields.compactMap {field, raw, maximum in
            let value = UFitServerTextInput.trimmed(raw)
            if value.isEmpty {return (field, UFitRefundOrganizationCopy.required)}
            if value.utf16.count > maximum {return (field, UFitRefundOrganizationCopy.tooLong(maximum))}
            return nil
        })
    }
}
struct UFitRefundOrganizationPresentation {
    let reference: String
    let context: String
    let amount: String
    let status: String
    let method: String?
    let instructions: String?
    let details: String?
    let updatedAt: String?
    let action: UFitRefundOrganizationAction?
    let actionTitle: String?
}
