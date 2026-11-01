import Foundation

enum UFitOutfitResponseStatus { static let invalid = 400; static let forbidden = 403; static let missing = 404 }
private enum UFitOutfitFailureCode: String {
    case owner = "outfit_owner_required", access = "outfit_owner_access_required", changed = "outfit_version_changed"
    case state = "outfit_state_unavailable", request = "outfit_creation_request_changed", incomplete = "outfit_submission_incomplete"
    case items = "outfit_items_invalid", images = "outfit_images_invalid", tags = "outfit_tags_invalid", reason = "outfit_rejection_reason_required"
    case mediaOwner = "media_outfit_owner_required", mediaAccess = "media_outfit_access_required"
    case mediaRequest = "media_outfit_upload_request_changed", mediaFile = "media_outfit_image_invalid", mediaImage = "media_outfit_image_unavailable"
    case mediaUnavailable = "media_outfit_storage_unavailable", mediaConfiguration = "media_outfit_configuration_required"
}
extension UFitAPIError {
    var outfitFailureDescription: String? {
        guard case .requestFailed(_, _, let raw) = self, let raw, let code = UFitOutfitFailureCode(rawValue: raw) else { return nil }
        switch code {
        case .owner, .access, .mediaOwner, .mediaAccess: return String(localized: "Votre accès à ce profil a changé. Revenez aux espaces et actualisez.")
        case .changed: return String(localized: "Cette tenue a changé. Votre saisie est conservée ; revenez à sa fiche et actualisez avant de modifier.")
        case .state: return String(localized: "Cette action est indisponible dans l’état actuel de la tenue. Actualisez sa fiche.")
        case .request: return String(localized: "Cet enregistrement existe déjà. Vérifiez le brouillon avant de continuer.")
        case .incomplete: return String(localized: "Le profil doit être actif et la tenue doit contenir une description, une photo et une pièce avant validation.")
        case .items: return String(localized: "Une pièce n’est plus disponible. Vérifiez les produits sélectionnés ou remplacez-la par une pièce d’inspiration.")
        case .images, .mediaImage: return String(localized: "Une photo n’est plus disponible pour ce profil. Retirez-la ou choisissez une autre image.")
        case .tags: return String(localized: "Les styles ont changé. Rechargez-les avant d’enregistrer.")
        case .reason: return String(localized: "Ajoutez un motif pour refuser cette tenue.")
        case .mediaRequest: return String(localized: "Cette photo correspond à un autre envoi. Retirez-la et choisissez-la à nouveau.")
        case .mediaFile: return String(localized: "Cette photo n’a pas pu être envoyée. Choisissez une autre image.")
        case .mediaUnavailable, .mediaConfiguration: return String(localized: "L’envoi des photos est momentanément indisponible. Réessayez plus tard.")
        }
    }
    var isMissingOutfitResource: Bool { if case .requestFailed(UFitOutfitResponseStatus.missing, _, _) = self { true } else { false } }
    var isDefinitiveOutfitCreationFailure: Bool {
        guard case .requestFailed(let status, _, _) = self else { return false }
        return [UFitOutfitResponseStatus.invalid, UFitOutfitResponseStatus.forbidden, UFitOutfitResponseStatus.missing].contains(status)
    }
}
