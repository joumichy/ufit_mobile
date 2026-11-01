import Foundation
import Observation

@MainActor @Observable
final class UFitOutfitShoppingStore {
    private(set) var detail: UFitOutfitDetailDTO?
    private(set) var isLoading = false
    private(set) var busyItems = Set<String>()
    private(set) var addedItems = Set<String>()
    var message: String?
    var pendingReplacementItemID: String?
    @ObservationIgnored private let client: UFitAPIClient
    @ObservationIgnored private var products = [String: UFitPublicProductDTO]()
    @ObservationIgnored private var brands = [String: UFitPublicBrandDTO]()
    private var issues = [String: String]()
    private var selections = [String: String]()
    private var quantities = [String: Int]()
    private enum Defaults { static let quantity = 1; static let none = String(); static let separator = " · " }
    private enum Copy {
        static let standard = String(localized: "Standard")
        static let inspiration = String(localized: "Pièce d’inspiration")
        static let choose = String(localized: "Choisissez une taille et une couleur disponibles.")
        static let unavailable = String(localized: "Cette pièce n’est plus disponible.")
    }
    init(client: UFitAPIClient) { self.client = client }

    var pieces: [UFitShoppingPiece] {
        (detail?.items ?? []).sorted { $0.position < $1.position }.map { item in
            let product = item.product.flatMap { products[$0.id] }
            let selected = selections[item.id]
            let variant = product?.variants.first { $0.id == selected }
            let price = product.map { value in
                variant.map { UFitMoney.format($0.price * (quantities[item.id] ?? Defaults.quantity), currency: value.price.currency) } ?? UFitMoney.ranges([value.price])
            } ?? (item.isShoppable ? Copy.unavailable : Copy.inspiration)
            return UFitShoppingPiece(id: item.id, name: product?.name ?? item.label,
                brand: product.flatMap { brands[$0.brandId]?.brandName }, brandID: product?.brandId, image: product?.images.sorted { $0.position < $1.position }.first?.url,
                price: price, note: item.stylingNote, variants: (product?.variants ?? []).map { value in
                    let options = [value.size, value.color].compactMap { $0 }.filter { !$0.isEmpty }
                    return UFitVariantChoice(id: value.id, label: options.isEmpty ? Copy.standard : options.joined(separator: Defaults.separator), isAvailable: value.stockQuantity > .zero)
                }, selectedVariantID: selected, quantity: quantities[item.id] ?? Defaults.quantity,
                maximumQuantity: variant?.stockQuantity ?? Defaults.quantity, isBusy: busyItems.contains(item.id), wasAdded: addedItems.contains(item.id),
                issue: issues[item.id] ?? (item.isShoppable && product == nil ? Copy.unavailable : nil))
        }
    }

    func load(id: String) async {
        guard !isLoading else { return }
        isLoading = true
        message = nil
        defer { isLoading = false }
        do {
            detail = try await client.fetchOutfitDetail(id: id)
            products = [:]; brands = [:]; issues = [:]
            for item in detail!.items where item.isShoppable {
                guard let productID = item.product?.id, products[productID] == nil else { continue }
                do {
                    let product = try await client.fetchPublicProduct(id: productID)
                    if brands[product.brandId] == nil { brands[product.brandId] = try await client.fetchPublicBrand(id: product.brandId) }
                    products[productID] = product
                } catch { issues[item.id] = error.localizedDescription }
            }
        } catch { message = error.localizedDescription }
    }

    func choose(itemID: String, variantID: String) {
        guard !busyItems.contains(itemID), let piece = pieces.first(where: { $0.id == itemID }),
              piece.variants.contains(where: { $0.id == variantID && $0.isAvailable }) else { return }
        selections[itemID] = variantID
        quantities[itemID] = Defaults.quantity
        addedItems.remove(itemID)
    }
    func setQuantity(itemID: String, quantity: Int) {
        guard !busyItems.contains(itemID), let piece = pieces.first(where: { $0.id == itemID }),
              quantity >= Defaults.quantity, quantity <= piece.maximumQuantity else { return }
        quantities[itemID] = quantity
        addedItems.remove(itemID)
    }
    func add(itemID: String, replacing: Bool = false) async -> UFitCartDTO? {
        guard !busyItems.contains(itemID), let item = detail?.items.first(where: { $0.id == itemID }),
              let productID = item.product?.id, let product = products[productID], let selection = selections[itemID],
              let variant = product.variants.first(where: { $0.id == selection }), variant.stockQuantity >= (quantities[itemID] ?? Defaults.quantity) else {
            message = Copy.choose; return nil
        }
        busyItems.insert(itemID)
        message = nil
        defer { busyItems.remove(itemID) }
        do {
            if replacing { _ = try await client.clearCart() }
            let cart = try await client.addCartItem(UFitAddCartItemRequest(productVariantId: variant.id, quantity: quantities[itemID] ?? Defaults.quantity, sourceOutfitId: detail?.id))
            addedItems.insert(itemID)
            issues[itemID] = nil
            pendingReplacementItemID = nil
            return cart
        } catch let error as UFitAPIError where error.isCartConflict {
            pendingReplacementItemID = itemID
            return nil
        } catch { issues[itemID] = error.localizedDescription; return nil }
    }
}
