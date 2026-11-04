import SwiftUI

struct OutfitDetailView: View {
    let outfit: Outfit
    let shopping: UFitOutfitShoppingStore
    let session: UFitSessionStore
    let cart: UFitCartStore
    let onAuthor: (OutfitAuthor) -> Void
    let onBrand: (String) -> Void
    let onBack: () -> Void
    let onCart: () -> Void
    let onSignIn: () -> Void
    var focusedItemID: String? = nil
    private enum Copy {
        static let replace = String(localized: "Remplacer le panier ?")
        static let confirm = String(localized: "Remplacer")
        static let cancel = String(localized: "Annuler")
        static let consequence = String(localized: "Un panier contient une seule marque et une seule devise. Les pièces actuelles seront retirées du panier actif.")
    }
    var body: some View {
        UFitOutfitShoppingContent(title: shopping.detail?.title ?? outfit.title,
            photos: presentedPhotos,
            description: shopping.detail?.description ?? outfit.description, author: presentedAuthor,
            prices: shopping.detail.map { UFitOutfitPresentation.priceSummary(prices: $0.prices, items: $0.items) } ?? outfit.price,
            pieces: shopping.pieces, cartCount: cart.count, isLoading: shopping.isLoading,
            message: shopping.message, onBack: onBack, onAuthor: { if let author = presentedAuthor { onAuthor(author) } }, onBrand: onBrand, onCart: onCart,
            onRetry: { Task { await shopping.load(id: outfit.id) } },
            onSelect: shopping.choose, onQuantity: shopping.setQuantity,
            onAdd: { id in add(id: id) }, focusedItemID: focusedItemID)
            .task(id: outfit.id) {
                if shopping.detail == nil { await shopping.load(id: outfit.id) }
                if session.user != nil { await cart.load() }
            }
            .ufitConfirmationDialog(Copy.replace, isPresented: Binding(get: { shopping.pendingReplacementItemID != nil }, set: { if !$0 { shopping.pendingReplacementItemID = nil } }), titleVisibility: .visible) {
                if let id = shopping.pendingReplacementItemID {
                    UFitButton(Copy.confirm, role: .destructive) { add(id: id, replacing: true) }
                }
                UFitButton(Copy.cancel, role: .cancel) { shopping.pendingReplacementItemID = nil }
            } message: { Text(Copy.consequence) }
    }
    private var presentedAuthor: OutfitAuthor? { if let detail = shopping.detail { detail.author } else { outfit.author } }
    private var presentedPhotos: [UFitOutfitGalleryPhoto] {
        if let detail = shopping.detail { detail.images.sorted { $0.position < $1.position } }
        else { outfit.photos }
    }
    private func add(id: String, replacing: Bool = false) {
        guard session.user != nil else { onSignIn(); return }
        Task {
            let userID = session.user?.id
            if let updated = await shopping.add(itemID: id, replacing: replacing), session.user?.id == userID {
                await cart.receive(updated)
            }
        }
    }
}
