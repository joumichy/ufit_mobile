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
    private var issues = [String: String]()
    private var selections = [String: String]()
    private var quantities = [String: Int]()
    private enum Defaults { static let quantity = 1; static let none = String(); static let separator = " · "; static let concurrentProducts = 4 }
    private enum ProductRead {
        case loaded(UFitPublicProductDTO)
        case failed(itemID: String, message: String)
    }
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
            return UFitShoppingPiece(id: item.id, itemType: item.itemType, name: product?.name ?? item.label,
                brand: item.product?.brandName, brandID: item.product?.brandId, image: product?.images.sorted { $0.position < $1.position }.first?.url,
                price: price, note: item.stylingNote, variants: (product?.variants ?? []).map { value in
                    let options = [value.size, value.color].compactMap { $0 }.filter { !$0.isEmpty }
                    return UFitVariantChoice(id: value.id, label: options.isEmpty ? Copy.standard : options.joined(separator: Defaults.separator), isAvailable: value.stockQuantity > .zero)
                }, selectedVariantID: selected, quantity: quantities[item.id] ?? Defaults.quantity,
                maximumQuantity: variant?.stockQuantity ?? Defaults.quantity, isBusy: busyItems.contains(item.id), wasAdded: addedItems.contains(item.id),
                issue: issues[item.id])
        }
    }

    func load(id: String, focusedItemID: String? = nil) async {
        guard !isLoading else { return }
        isLoading = true
        message = nil
        defer { isLoading = false }
        do {
            let document = try await client.fetchOutfitDetail(id: id)
            detail = document
            products = [:]; issues = [:]
            let requested = document.items.filter { $0.isShoppable && (focusedItemID == nil || $0.id == focusedItemID) }
            let client = self.client
            await withTaskGroup(of: ProductRead.self) { group in
                var remaining = requested.makeIterator()
                func enqueue(_ item: UFitOutfitItemDTO) {
                    group.addTask {
                        do {
                            guard let reference = item.product else { throw UFitOutfitContractError.document }
                            let product = try await client.fetchPublicProduct(id: reference.id)
                            guard product.id == reference.id, product.brandId == reference.brandId else { throw UFitOutfitContractError.document }
                            return .loaded(product)
                        } catch { return .failed(itemID: item.id, message: error.localizedDescription) }
                    }
                }
                for _ in .zero..<min(Defaults.concurrentProducts, requested.count) {
                    if let item = remaining.next() { enqueue(item) }
                }
                for await result in group {
                    if !Task.isCancelled {
                        switch result {
                        case .loaded(let product): products[product.id] = product
                        case .failed(let itemID, let message): issues[itemID] = message
                        }
                    }
                    if !Task.isCancelled, let item = remaining.next() { enqueue(item) }
                }
            }
        } catch is CancellationError {} catch { message = error.localizedDescription }
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
