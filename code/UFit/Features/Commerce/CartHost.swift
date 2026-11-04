import SwiftUI

struct UFitCartHost: View {
    let store: UFitCartStore
    let session: UFitSessionStore
    let onBack: () -> Void
    let onBrowse: () -> Void
    let onSignIn: () -> Void
    var onCheckout: (() -> Void)?
    var body: some View {
        if session.user == nil {
            UFitCartAccountGate(session: session, onBack: onBack, onSignIn: onSignIn)
        } else {
            UFitCartContent(lines: store.lines, subtotal: store.subtotal, isLoading: store.isLoading, hasLoaded: store.hasLoaded, loadError: store.loadError,
            message: store.message, onBack: onBack, onBrowse: onBrowse,
            onRefresh: { await store.load() },
            onQuantity: { id, quantity in Task { await store.update(id: id, quantity: quantity) } },
            onRemove: { id in Task { await store.remove(id: id) } }, onCheckout: onCheckout,
            checkoutRecovery: store.checkoutRecovery)
            .task { await store.load() }
        }
    }
}
