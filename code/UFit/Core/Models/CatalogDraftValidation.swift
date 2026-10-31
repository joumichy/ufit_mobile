import Foundation

enum UFitCatalogDraftValidation {
    static func product(_ draft: UFitCatalogProductDraft, currencies: [UFitCatalogCurrency]) -> [UFitCatalogField: String] {
        var errors: [UFitCatalogField: String] = [:]
        if !UFitCatalogInput.countValid(draft.name, minimum: UFitCatalogInput.nameMin, maximum: UFitCatalogInput.nameMax) { errors[.name] = Copy.name }
        if !UFitCatalogInput.countValid(draft.description, minimum: UFitCatalogInput.descriptionMin, maximum: UFitCatalogInput.descriptionMax) { errors[.description] = Copy.description }
        if !UFitCatalogInput.countValid(draft.category, minimum: UFitCatalogInput.categoryMin, maximum: UFitCatalogInput.categoryMax) { errors[.category] = Copy.category }
        for (text, field) in [(draft.material, UFitCatalogField.material), (draft.care, .care)] {
            if !UFitCatalogInput.countValid(text, minimum: UFitCatalogInput.integerMin, maximum: UFitCatalogInput.detailsMax) { errors[field] = Copy.details }
        }
        if let currency = currencies.first(where: { $0.code == draft.currency }) {
            if UFitCatalogInput.minorUnits(draft.price, currency: currency) == nil { errors[.price] = priceError(currency) }
            if draft.variants.contains(where: { !variant($0, currency: currency).isEmpty }) { errors[.variants] = Copy.variants }
        } else { errors[.currency] = Copy.currency }
        if draft.variants.count > UFitCatalogInput.variantsMax { errors[.variants] = Copy.variantsLimit }
        let skus = draft.variants.map { UFitCatalogInput.trimmed($0.sku) }
        if Set(skus).count != skus.count { errors[.variants] = Copy.duplicateSKU }
        if draft.photos.count > UFitCatalogInput.photosMax { errors[.photos] = Copy.photosLimit }
        else if draft.photos.contains(where: { $0.transfer != .ready || $0.url == nil }) { errors[.photos] = Copy.photosPending }
        return errors
    }
    static func variant(_ draft: UFitCatalogVariantDraft, currency: UFitCatalogCurrency) -> [UFitCatalogVariantField: String] {
        var errors: [UFitCatalogVariantField: String] = [:]
        if !UFitCatalogInput.countValid(draft.sku, minimum: UFitCatalogInput.skuMin, maximum: UFitCatalogInput.skuMax) { errors[.sku] = Copy.sku }
        for (text, field) in [(draft.size, UFitCatalogVariantField.size), (draft.color, .color)] {
            if !UFitCatalogInput.countValid(text, minimum: UFitCatalogInput.integerMin, maximum: UFitCatalogInput.optionMax) { errors[field] = Copy.option }
        }
        if UFitCatalogInput.integer(draft.stock) == nil { errors[.stock] = Copy.stock }
        if !UFitCatalogInput.trimmed(draft.priceOverride).isEmpty && UFitCatalogInput.minorUnits(draft.priceOverride, currency: currency) == nil { errors[.price] = priceError(currency) }
        return errors
    }
    static func priceError(_ currency: UFitCatalogCurrency) -> String { String(localized: "Saisissez un montant positif ou nul, avec au plus \(currency.minorUnitDigits) décimale(s), dans la limite autorisée.") }
    enum Copy {
        static let name = String(localized: "Saisissez un nom de 2 à 120 caractères.")
        static let description = String(localized: "Saisissez une description de 1 à 6 000 caractères.")
        static let category = String(localized: "Saisissez une catégorie de 1 à 100 caractères.")
        static let details = String(localized: "Limitez ce texte à 2 000 caractères.")
        static let currency = String(localized: "Choisissez une devise disponible.")
        static let variants = String(localized: "Corrigez les variantes avant d’enregistrer.")
        static let variantsLimit = String(localized: "Un produit peut contenir au plus 100 variantes.")
        static let duplicateSKU = String(localized: "Chaque variante doit avoir une référence SKU distincte.")
        static let photosLimit = String(localized: "Un produit peut contenir au plus 12 photos.")
        static let photosPending = String(localized: "Terminez les envois de photos ou retirez les photos en erreur.")
        static let sku = String(localized: "Saisissez une référence SKU de 1 à 120 caractères.")
        static let option = String(localized: "Limitez cette valeur à 100 caractères.")
        static let stock = String(localized: "Saisissez une quantité entière de 0 à 2 147 483 647.")
    }
}
