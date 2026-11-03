import SwiftUI

struct UFitPaymentSettlementHost: View {
    let store: UFitPaymentSettlementStore
    let onBack: () -> Void
    var onAllocation: (() -> Void)? = nil
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        UFitPaymentSettlementContent(document: store.document, isLoading: store.isLoading, isSending: store.isSending,
            message: store.message, needsStatusRefresh: store.needsStatusRefresh, onBack: onBack,
            onRefresh: { Task { await store.refresh() } }, onSynchronize: { Task { await store.synchronize() } }, onAllocation: onAllocation)
            .task { await store.load() }
            .task(id: store.shouldPoll) {
                while store.shouldPoll && !Task.isCancelled {
                    do { try await Task.sleep(for: UFitPaymentSettlementHTTP.pollInterval) } catch { return }
                    guard store.shouldPoll, !Task.isCancelled else { return }
                    await store.load(quiet: true)
                }
            }
            .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await store.refresh() } } }
            .onDisappear { store.cancelLoading() }
    }
}
