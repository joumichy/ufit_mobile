import Foundation

enum UFitCatalogResponseStatus { static let invalid = 400; static let forbidden = 403; static let missing = 404; static let conflict = 409 }
private enum UFitCatalogFailureCode: String {
    case access = "product_brand_access_required", version = "product_version_changed", stock = "product_stock_changed", state = "product_state_unavailable"
    case incomplete = "product_submission_incomplete", sku = "product_sku_unavailable", images = "product_image_mismatch", variants = "product_variant_mismatch"
    case request = "product_creation_request_changed", reason = "product_rejection_reason_required"
    case mediaAccess = "media_brand_access_required", mediaRequest = "media_upload_request_changed", mediaFile = "media_image_invalid"
    case mediaOwnership = "media_image_unavailable", mediaUnavailable = "media_storage_unavailable", mediaConfiguration = "media_configuration_required"
}
extension UFitAPIError {
    var catalogFailureDescription: String? {
        guard case .requestFailed(_, _, let raw) = self, let raw, let code = UFitCatalogFailureCode(rawValue: raw) else { return nil }
        switch code {
        case .access, .mediaAccess: return String(localized: "Votre accès à cette marque a changé. Revenez aux espaces et actualisez.")
        case .version: return String(localized: "Cette fiche a changé. Revenez à la fiche et actualisez avant de réessayer.")
        case .stock: return String(localized: "Le stock a changé. Revenez à la fiche et actualisez les quantités avant de réessayer.")
        case .state: return String(localized: "Cette action est indisponible dans l’état actuel du produit. Actualisez sa fiche.")
        case .incomplete: return String(localized: "Ajoutez une photo et une variante active avant l’envoi à validation.")
        case .sku: return String(localized: "Une référence SKU est déjà utilisée. Choisissez une référence distincte pour chaque variante.")
        case .images, .variants: return String(localized: "Les photos ou variantes ont changé. Revenez à la fiche et actualisez avant de modifier.")
        case .request: return String(localized: "Cet enregistrement existe déjà avec un autre contenu. Reprenez sa fiche avant de modifier.")
        case .reason: return String(localized: "Ajoutez un motif pour refuser ce produit.")
        case .mediaRequest: return String(localized: "Cette photo correspond à un autre enregistrement. Retirez-la et choisissez-la à nouveau.")
        case .mediaFile: return String(localized: "Cette photo n’a pas pu être envoyée. Retirez-la et choisissez-la à nouveau.")
        case .mediaOwnership: return String(localized: "Une photo n’est plus disponible pour cette marque. Retirez-la ou choisissez une autre image.")
        case .mediaUnavailable, .mediaConfiguration: return String(localized: "L’envoi de photos est momentanément indisponible. Réessayez plus tard.")
        }
    }
    var isMissingCatalogResource: Bool { if case .requestFailed(UFitCatalogResponseStatus.missing, _, _) = self { true } else { false } }
    var isDefinitiveCatalogCreationFailure: Bool {
        guard case .requestFailed(let status, _, let code) = self else { return false }
        if [UFitCatalogResponseStatus.invalid, UFitCatalogResponseStatus.forbidden, UFitCatalogResponseStatus.missing].contains(status) { return true }
        return status == UFitCatalogResponseStatus.conflict && code == UFitCatalogFailureCode.sku.rawValue
    }
}
