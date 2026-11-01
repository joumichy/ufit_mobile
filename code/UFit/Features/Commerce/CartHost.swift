import SwiftUI

struct UFitCartHost: View {
    let store: UFitCartStore
    let onBack: () -> Void
    let onBrowse: () -> Void
    var onCheckout: (() -> Void)?
    var body: some View {
        UFitCartContent(lines: store.lines, subtotal: store.subtotal, isLoading: store.isLoading, hasLoaded: store.hasLoaded, loadError: store.loadError,
            message: store.message, onBack: onBack, onBrowse: onBrowse,
            onRefresh: { await store.load() },
            onQuantity: { id, quantity in Task { await store.update(id: id, quantity: quantity) } },
            onRemove: { id in Task { await store.remove(id: id) } }, onCheckout: onCheckout)
            .task { await store.load() }
    }
}
