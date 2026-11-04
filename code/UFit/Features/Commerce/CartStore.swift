import Foundation
import Observation

@MainActor @Observable
final class UFitCartStore {
    private(set) var cart: UFitCartDTO?
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var busyItems = Set<String>()
    private(set) var loadError: String?
    private(set) var checkoutRecovery: UFitCheckoutRecoveryNotice?
    var message: String?
    private var products = [String: UFitPublicProductDTO]()
    @ObservationIgnored private let client: UFitAPIClient
    @ObservationIgnored private let session: UFitSessionStore
    private enum Copy {
        static let unavailable = String(localized: "Pièce indisponible")
        static let standard = String(localized: "Standard")
        static let separator = " · "
    }
    private enum Quantity { static let minimum = 1 }
    init(client: UFitAPIClient, session: UFitSessionStore) { self.client = client; self.session = session }
    var count: Int { cart?.items.reduce(.zero) { $0 + $1.quantity } ?? .zero }
    var subtotal: String { cart.map { UFitMoney.format($0.subtotalAmount, currency: $0.currency) } ?? String() }
    var lines: [UFitCartPresentationLine] {
        (cart?.items ?? []).map { line in
            let product = products[line.productId]
            let variant = product?.variants.first { $0.id == line.productVariantId }
            let options = [variant?.size, variant?.color].compactMap { $0 }.filter { !$0.isEmpty }
            return UFitCartPresentationLine(id: line.id, name: product?.name ?? Copy.unavailable,
                variant: options.isEmpty ? Copy.standard : options.joined(separator: Copy.separator),
                image: product?.images.sorted { $0.position < $1.position }.first?.url,
                quantity: line.quantity, maximumQuantity: max(Quantity.minimum, variant?.stockQuantity ?? line.quantity),
                amount: UFitMoney.format(line.unitPrice * line.quantity, currency: line.currency),
                isBusy: busyItems.contains(line.id), isAvailable: (variant?.stockQuantity ?? .zero) > .zero)
        }
    }
    func reset() { cart = nil; products = [:]; busyItems = []; message = nil; loadError = nil; hasLoaded = false; checkoutRecovery = nil }
    func load() async {
        guard !isLoading, let userID = session.user?.id else { return }
        isLoading = true
        defer { isLoading = false }
        readCheckoutRecovery(userID: userID)
        do {
            let response = try await client.fetchCart()
            guard session.user?.id == userID else { return }
            cart = response.cart
            hasLoaded = true
            loadError = nil
            message = nil
            await hydrate(userID: userID)
        } catch { if session.user?.id == userID { loadError = error.localizedDescription } }
    }
    func receive(_ response: UFitCartDTO) async {
        guard let userID = session.user?.id else { return }
        readCheckoutRecovery(userID: userID)
        cart = response; hasLoaded = true; loadError = nil; message = nil
        await hydrate(userID: userID)
    }
    private func hydrate(userID: String) async {
        var loaded = [String: UFitPublicProductDTO]()
        for id in Set(cart?.items.map(\.productId) ?? []) {
            if let product = try? await client.fetchPublicProduct(id: id) { loaded[id] = product }
        }
        guard session.user?.id == userID else { return }
        products = loaded
    }
    private func readCheckoutRecovery(userID: String) {
        do {
            let record = try UFitCheckoutJournal(userID: userID, endpoint: client.configuration.baseURL).read()
            checkoutRecovery = record.map { .pending(amount: UFitMoney.format($0.amount, currency: $0.currency)) }
        } catch { checkoutRecovery = .unavailable }
    }
    func update(id: String, quantity: Int) async {
        guard !busyItems.contains(id), let userID = session.user?.id else { return }
        busyItems.insert(id)
        defer { busyItems.remove(id) }
        do {
            let response = try await client.setCartQuantity(itemID: id, quantity: quantity)
            guard session.user?.id == userID else { return }
            cart = response; hasLoaded = true; loadError = nil; message = nil
            await hydrate(userID: userID)
        } catch { if session.user?.id == userID { message = error.localizedDescription } }
    }
    func remove(id: String) async {
        guard !busyItems.contains(id), let userID = session.user?.id else { return }
        busyItems.insert(id)
        defer { busyItems.remove(id) }
        do {
            let response = try await client.removeCartItem(id: id)
            guard session.user?.id == userID else { return }
            cart = response; hasLoaded = true; loadError = nil; message = nil
            await hydrate(userID: userID)
        } catch { if session.user?.id == userID { message = error.localizedDescription } }
    }
}
