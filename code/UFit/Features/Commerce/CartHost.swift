import SwiftUI

struct UFitCartHost: View {
    let store: UFitCartStore
    let onBack: () -> Void
    var onCheckout: (() -> Void)?
    var body: some View {
        UFitCartContent(lines: store.lines, subtotal: store.subtotal, isLoading: store.isLoading,
            message: store.message, onBack: onBack,
            onRefresh: { Task { await store.load() } },
            onQuantity: { id, quantity in Task { await store.update(id: id, quantity: quantity) } },
            onRemove: { id in Task { await store.remove(id: id) } }, onCheckout: onCheckout)
            .task { await store.load() }
    }
}
