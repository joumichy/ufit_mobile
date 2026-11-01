import SwiftUI

struct UFitWorkspaceDashboardHost: View {
    let store: UFitWorkspaceDashboardStore
    let onBack: () -> Void
    let onCommissions: () -> Void
    var body: some View {
        UFitWorkspaceDashboardContent(document: store.document, isLoading: store.isLoading, message: store.message,
            onBack: onBack, onRefresh: { Task { await store.load() } }, onCommissions: onCommissions)
            .task { await store.load() }
            .onDisappear { store.cancelLoading() }
    }
}
struct UFitWorkspaceCommissionsHost: View {
    let store: UFitWorkspaceCommissionsStore
    let onBack: () -> Void
    var body: some View {
        UFitWorkspaceCommissionsContent(name: store.name, entries: store.entries, isLoading: store.isLoading,
            hasLoaded: store.hasLoaded, hasMore: store.hasMore, message: store.message, onBack: onBack,
            onRefresh: { Task { await store.load() } }, onRetry: { Task { await store.retry() } }, onMore: { Task { await store.load(refresh: false) } })
            .task { await store.load() }
            .onDisappear { store.cancelLoading() }
    }
}
