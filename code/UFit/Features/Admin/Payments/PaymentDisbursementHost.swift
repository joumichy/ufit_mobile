import SwiftUI

struct UFitPaymentDisbursementHost: View {
    let store: UFitPaymentDisbursementStore
    let onBack: () -> Void
    let onAllocation: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        UFitPaymentDisbursementContent(store: store, onBack: onBack, onAllocation: onAllocation)
            .task { await store.load() }
            .task(id: store.shouldPoll) {
                while store.shouldPoll && !Task.isCancelled {
                    do { try await Task.sleep(for: UFitPaymentDisbursementHTTP.pollInterval) } catch { return }
                    guard store.shouldPoll, !Task.isCancelled else { return }
                    await store.load(quiet: true)
                }
            }
            .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await store.refresh() } } }
            .onDisappear { store.cancelLoading() }
    }
}
