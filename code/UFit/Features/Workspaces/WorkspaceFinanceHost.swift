import SwiftUI

struct UFitWorkspaceDashboardHost: View {
    @Bindable var store: UFitWorkspaceDashboardStore
    let title: String
    let onBack: () -> Void
    let onCommissions: () -> Void
    var body: some View {
        UFitWorkspaceDashboardContent(document: store.document, isLoading: store.isLoading, message: store.message,
            revenue: store.revenue, revenuePeriod: $store.revenuePeriod, isRevenueLoading: store.isRevenueLoading, revenueMessage: store.revenueMessage,
            onRevenueRetry: { Task { await store.loadRevenue() } },
            onBack: onBack, onRefresh: { Task { await store.refresh() } }, onCommissions: onCommissions, sectionTitle: title, showsActivity: false)
            .task { await store.refresh() }
            .onChange(of: store.revenuePeriod) { _, _ in Task { await store.changeRevenuePeriod() } }
            .onDisappear { store.cancelLoading() }
    }
}
struct UFitWorkspaceCommissionsHost: View {
    @Bindable var store: UFitWorkspaceCommissionsStore
    let onBack: () -> Void
    var body: some View {
        UFitWorkspaceCommissionsContent(name: store.name, selectedState: $store.selectedState, asOf: store.asOf, entries: store.entries, isLoading: store.isLoading,
            hasLoaded: store.hasLoaded, hasMore: store.hasMore, message: store.message, onBack: onBack,
            onRefresh: { Task { store.cancelLoading(); await store.load() } }, onRetry: { Task { await store.retry() } }, onMore: { Task { await store.load(refresh: false) } })
            .task { await store.load() }
            .onChange(of: store.selectedState) { _, _ in Task { store.cancelLoading(); await store.load() } }
            .onDisappear { store.cancelLoading() }
    }
}
