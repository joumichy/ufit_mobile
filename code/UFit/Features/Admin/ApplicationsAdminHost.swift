import SwiftUI

struct UFitApplicationQueueHost: View {
    let store: UFitApplicationQueueStore
    let onBack: () -> Void
    let onOpen: (UFitApplicationQueueItem) -> Void
    var body: some View {
        UFitApplicationQueueContent(items: store.items, filter: store.filter, kind: store.kind, isLoading: store.isLoading,
            hasLoaded: store.hasLoaded, hasMore: store.nextCursor != nil, message: store.message, onBack: onBack,
            onFilter: { filter in Task { await store.select(filter: filter) } }, onKind: { kind in Task { await store.select(kind: kind) } },
            onRefresh: { Task { await store.load() } }, onMore: { Task { await store.load(reset: false) } }, onOpen: onOpen)
            .task { await store.load() }
    }
}
struct UFitApplicationReviewHost: View {
    @Bindable var store: UFitApplicationReviewStore
    let onBack: () -> Void
    var body: some View {
        UFitApplicationReviewContent(application: store.application, notes: $store.notes, isLoading: store.isLoading,
            isDeciding: store.isDeciding, allowsDecision: store.allowsDecision, message: store.message, onBack: onBack,
            onRefresh: { Task { await store.load() } }, onDecide: { decision in Task { await store.decide(decision) } })
            .task { await store.load() }
    }
}
