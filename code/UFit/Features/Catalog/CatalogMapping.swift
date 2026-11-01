import Foundation

extension UFitManagedProduct {
    func row() -> UFitCatalogRow {
        .init(id: id, name: product.name, status: product.status, price: UFitMoney.format(product.basePrice, currency: product.currency), image: images.first?.displayUrl)
    }
    func presentation() -> UFitCatalogProductPresentation {
        .init(id: id, version: product.version, brandName: brand.brandName, brandStatus: brand.status, name: product.name, description: product.description, category: product.category, status: product.status,
            price: UFitMoney.format(product.basePrice, currency: product.currency), material: product.material, careInstructions: product.careInstructions,
            rejectionReason: product.rejectionReason, images: images.map { .init(id: $0.id, source: $0.displayUrl, kindLabel: $0.kind.label) },
            variants: variants.map { variantPresentation($0) }, submissionIssue: submissionIssue)
    }
    func variantPresentation(_ variant: Variant) -> UFitCatalogVariant {
        let parts = [variant.size, variant.color].compactMap { $0 }.filter { !$0.isEmpty }
        return .init(id: variant.id, title: parts.isEmpty ? variant.sku : parts.joined(separator: Copy.variantSeparator), sku: variant.sku,
            stockQuantity: variant.stockQuantity, price: UFitMoney.format(variant.priceOverride ?? product.basePrice, currency: product.currency), status: variant.status)
    }
    func draft(currencies: [UFitCatalogCurrency]) throws -> UFitCatalogProductDraft {
        guard let currency = currencies.first(where: { $0.code == product.currency }) else { throw UFitCatalogContractError.currencies }
        var value = UFitCatalogProductDraft()
        value.name = product.name; value.description = product.description; value.category = product.category; value.gender = product.genderTarget
        value.currency = currency.code; value.price = UFitCatalogInput.amountText(product.basePrice, currency: currency)
        value.material = product.material ?? String(); value.care = product.careInstructions ?? String()
        value.variants = variants.map { variant in
            .init(serverID: variant.id, expectedStockQuantity: variant.stockQuantity, sku: variant.sku, size: variant.size ?? String(), color: variant.color ?? String(),
                stock: String(variant.stockQuantity), priceOverride: variant.priceOverride.map { UFitCatalogInput.amountText($0, currency: currency) } ?? String(), status: variant.status)
        }
        value.photos = images.map { .init(id: UUID(), serverID: $0.id, source: $0.displayUrl, url: $0.url, kind: $0.kind, transfer: .ready) }
        return value
    }
    private var submissionIssue: String? {
        if images.isEmpty { return Copy.photoRequired }
        if !variants.contains(where: { $0.status == .active }) { return Copy.variantRequired }
        return nil
    }
    private enum Copy {
        static let variantSeparator = " · "
        static let photoRequired = String(localized: "Ajoutez une photo avant l’envoi à validation.")
        static let variantRequired = String(localized: "Ajoutez ou activez une variante avant l’envoi à validation.")
    }
}
