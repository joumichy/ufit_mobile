import SwiftUI

struct UFitPaymentAllocationHost: View {
    let store: UFitPaymentAllocationStore
    let onBack: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        UFitPaymentAllocationContent(store: store, onBack: onBack)
            .task { await store.load() }
            .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await store.refresh() } } }
            .onDisappear { store.cancelLoading() }
    }
}
