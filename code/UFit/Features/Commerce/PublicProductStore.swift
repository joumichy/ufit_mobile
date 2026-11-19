import Foundation
import Observation

@MainActor @Observable
final class UFitPublicProductStore {
    let id: String
    private(set) var product: UFitPublicProductDTO?
    private(set) var brand: UFitPublicBrandDTO?
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var loadError: String?
    private(set) var isUnavailable = false
    private(set) var isAdding = false
    private(set) var added = false
    private(set) var additionUnconfirmed = false
    private(set) var hasCartConflict = false
    private(set) var addError: String?
    private(set) var selectedVariantID: String?
    private(set) var quantity = Limits.minimum
    @ObservationIgnored private let client: UFitAPIClient
    @ObservationIgnored private let session: UFitSessionStore
    private enum Limits { static let minimum = 1; static let separator = " · "; static let photoSeparator = ":"; static let imageProtocols = ["http", "https"]; static let clientErrorMinimum = 400; static let serverErrorMinimum = 500; static let missing = 404 }
    init(id: String, client: UFitAPIClient, session: UFitSessionStore) { self.id = id; self.client = client; self.session = session }
    var photos: [UFitOutfitGalleryPhoto] {
        (product?.images ?? []).sorted { $0.position < $1.position }.map {
            .init(url: $0.url, position: $0.position, id: id + Limits.photoSeparator + String($0.position))
        }
    }
    var piece: UFitShoppingPiece? {
        guard let product else { return nil }
        let variant = product.variants.first { $0.id == selectedVariantID }
        return .init(id: product.id, itemType: nil, name: product.name, brand: brand?.brandName, brandID: product.brandId,
            image: product.images.sorted { $0.position < $1.position }.first?.url,
            price: variant.map { UFitMoney.format($0.price, currency: product.price.currency) } ?? UFitMoney.ranges([product.price]),
            note: nil, variants: product.variants.map { variant in
                let values = [variant.size, variant.color].compactMap { $0 }.filter { !$0.isEmpty }
                return .init(id: variant.id, label: values.isEmpty ? UFitPublicProductCopy.standard : values.joined(separator: Limits.separator), isAvailable: variant.stockQuantity > .zero)
            }, selectedVariantID: selectedVariantID, quantity: quantity, maximumQuantity: variant?.stockQuantity ?? Limits.minimum,
            isBusy: isAdding, wasAdded: added, issue: addError)
    }
    func load() async {
        guard !isLoading, !isAdding else { return }
        isLoading = true; hasLoaded = false; isUnavailable = false; loadError = nil
        defer { isLoading = false }
        do {
            let value = try await client.fetchPublicProduct(id: id)
            try validate(value)
            let owner = try await client.fetchPublicBrand(id: value.brandId)
            try Task.checkCancellation()
            guard owner.id == value.brandId else { throw ProductFailure.contract }
            product = value; brand = owner; hasLoaded = true; isUnavailable = false
            if let selectedVariantID, !value.variants.contains(where: { $0.id == selectedVariantID && $0.stockQuantity >= quantity }) {
                self.selectedVariantID = nil; quantity = Limits.minimum; addError = UFitPublicProductCopy.optionUnavailable
            }
        } catch is CancellationError {} catch {
            if case .requestFailed(Limits.missing, _, _) = error as? UFitAPIError {
                product = nil; brand = nil; isUnavailable = true; hasLoaded = true
            } else { loadError = UFitPublicProductCopy.loadFailed }
        }
    }
    func choose(_ id: String) {
        guard !isAdding, !isLoading, !additionUnconfirmed, !hasCartConflict, product?.variants.contains(where: { $0.id == id && $0.stockQuantity > .zero }) == true else { return }
        selectedVariantID = id; quantity = Limits.minimum; added = false; addError = nil
    }
    func setQuantity(_ value: Int) {
        guard !isAdding, !isLoading, !additionUnconfirmed, !hasCartConflict, let variant = product?.variants.first(where: { $0.id == selectedVariantID }),
              (Limits.minimum...max(Limits.minimum, variant.stockQuantity)).contains(value) else { return }
        quantity = value; added = false; addError = nil
    }
    func add() async -> UFitCartDTO? {
        guard !isAdding, !isLoading, !additionUnconfirmed, !hasCartConflict, let userID = session.user?.id,
              let variant = product?.variants.first(where: { $0.id == selectedVariantID }), variant.stockQuantity >= quantity else { return nil }
        isAdding = true; addError = nil; added = false
        defer { isAdding = false }
        do {
            let cart = try await client.addCartItem(.init(productVariantId: variant.id, quantity: quantity, sourceOutfitId: nil))
            guard session.user?.id == userID else { return nil }
            added = true
            return cart
        } catch {
            guard session.user?.id == userID else { return nil }
            if case .authenticationRequired = error as? UFitAPIError {
                addError = UFitAPIError.authenticationRequired.localizedDescription
            } else if case .requestFailed(let status, _, _) = error as? UFitAPIError,
               (Limits.clientErrorMinimum..<Limits.serverErrorMinimum).contains(status) {
                hasCartConflict = (error as? UFitAPIError)?.isCartConflict == true
                addError = hasCartConflict ? error.localizedDescription : UFitPublicProductCopy.rejected
            } else {
                additionUnconfirmed = true; addError = UFitPublicProductCopy.unconfirmed
            }
            return nil
        }
    }
    func reconcileCart(_ cart: UFitCartStore) {
        guard hasCartConflict, cart.hasLoaded, !cart.isLoading, cart.loadError == nil, let product else { return }
        if let current = cart.cart, !current.items.isEmpty {
            guard current.brandId == product.brandId, current.currency == product.price.currency else { return }
        }
        hasCartConflict = false; addError = nil
    }
    private func validate(_ value: UFitPublicProductDTO) throws {
        let ids = [value.id, value.brandId] + value.variants.map(\.id)
        guard value.id == id, ids.allSatisfy({ UUID(uuidString: $0)?.uuidString.lowercased() == $0 }),
              !value.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              value.price.min >= .zero, value.price.max >= value.price.min,
              value.price.currency.range(of: UFitCurrency.codePattern, options: .regularExpression) != nil,
              Set(value.variants.map(\.id)).count == value.variants.count,
              value.variants.allSatisfy({ $0.stockQuantity >= .zero && $0.price >= .zero }),
              Set(value.images.map(\.position)).count == value.images.count,
              value.images.allSatisfy({ image in
                  guard image.position >= .zero, let url = URL(string: image.url), let scheme = url.scheme else { return false }
                  return Limits.imageProtocols.contains(scheme) && url.host != nil && url.user == nil && url.password == nil
              }) else { throw ProductFailure.contract }
        if !value.variants.isEmpty {
            guard value.variants.map(\.price).min() == value.price.min, value.variants.map(\.price).max() == value.price.max else { throw ProductFailure.contract }
        }
    }
    private enum ProductFailure: Error { case contract }
}

enum UFitPublicProductCopy {
    static let refresh = String(localized: "Actualiser")
    static let icon = "tag"; static let errorIcon = "wifi.exclamationmark"
    static let photos = String(localized: "Photos de la pièce")
    static func selection(_ option: String, quantity: Int) -> String { String(localized: "Sélection : \(option), quantité \(quantity)") }
    static let title = String(localized: "La pièce")
    static let loading = String(localized: "Chargement de la pièce")
    static let failed = String(localized: "Pièce indisponible")
    static let loadFailed = String(localized: "Cette pièce n’a pas pu être chargée. Réessayez.")
    static let unavailable = String(localized: "Cette pièce n’est plus disponible")
    static let noVariants = String(localized: "Aucune option disponible")
    static let standard = String(localized: "Standard")
    static let optionUnavailable = String(localized: "L’option choisie n’est plus disponible. Choisissez-en une autre.")
    static let rejected = String(localized: "Cette pièce n’a pas pu être ajoutée. Actualisez ses options avant de réessayer.")
    static let unconfirmed = String(localized: "Ajout non confirmé. Consultez votre panier avant un nouvel ajout.")
    static let cart = String(localized: "Voir le panier")
    static let brandChevron = "chevron.right"
}
