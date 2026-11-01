import SwiftUI

struct UFitCreatorStudioHost: View {
    let workspace: UFitWorkspaceReference
    let store: UFitWorkspaceDashboardStore
    let onChooseExperience: () -> Void
    let onCreate: () -> Void
    let onOutfits: (UFitOutfitStatus?) -> Void
    let onPublicProfile: () -> Void
    var body: some View {
        UFitCreatorStudioContent(workspace: workspace, document: store.document, isLoading: store.isLoading, message: store.message,
            onRefresh: { Task { await store.load() } }, onCreate: onCreate, onOutfits: onOutfits,
            onPublicProfile: onPublicProfile, onChooseExperience: onChooseExperience)
            .task { await store.load() }.onDisappear { store.cancelLoading() }
    }
}
struct UFitBrandActivityHost: View {
    let workspace: UFitWorkspaceReference
    let store: UFitWorkspaceDashboardStore
    let onChooseExperience: () -> Void
    let onAddProduct: () -> Void
    let onCatalog: (UFitCatalogStatus?) -> Void
    let onOrders: () -> Void
    let onReturns: () -> Void
    let onSales: () -> Void
    var body: some View {
        UFitBrandActivityContent(workspace: workspace, document: store.document, isLoading: store.isLoading, message: store.message,
            onRefresh: { Task { await store.load() } }, onAddProduct: onAddProduct, onCatalog: onCatalog, onOrders: onOrders,
            onReturns: onReturns, onSales: onSales, onChooseExperience: onChooseExperience)
            .task { await store.load() }.onDisappear { store.cancelLoading() }
    }
}
struct UFitAdminActivityHost: View {
    let store: UFitAdminActivityStore
    let onChooseExperience: () -> Void
    let onApplications: () -> Void
    let onProducts: () -> Void
    let onOutfits: () -> Void
    let onReturns: () -> Void
    let onCommissions: () -> Void
    var body: some View {
        UFitAdminHomeContent(activity: store.activity, isLoading: store.isLoading, message: store.message,
            onRefresh: { Task { await store.load() } }, onApplications: onApplications, onProducts: onProducts,
            onOutfits: onOutfits, onReturns: onReturns, onCommissions: onCommissions, onChooseExperience: onChooseExperience)
            .task { await store.load() }.onDisappear { store.cancelLoading() }
    }
}
