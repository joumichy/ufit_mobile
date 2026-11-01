import SwiftUI

struct UFitWorkspacesHost: View {
    let store: UFitWorkspacesStore
    let canAdminister: Bool
    let onOpen: (UFitWorkspaceReference) -> Void
    let onApplications: () -> Void
    let onPayments: () -> Void
    let onAdminApplications: () -> Void
    let onCatalog: (UFitWorkspaceReference) -> Void
    let onCommercePolicy: (UFitWorkspaceReference) -> Void
    let onOrders: (UFitWorkspaceReference) -> Void
    let onReturns: (UFitWorkspaceReference) -> Void
    let onAdminReturns: () -> Void
    let onAdminProducts: () -> Void
    let onOutfits: (UFitWorkspaceReference) -> Void
    let onAdminOutfits: () -> Void
    let onPublicProfile: (UFitWorkspaceReference) -> Void
    var body: some View {
        UFitWorkspacesContent(spaces: store.spaces, hasLoaded: store.hasLoaded, isLoading: store.isLoading,
            busyIDs: store.busyIDs, message: store.message, canAdminister: canAdminister,
            onRefresh: { Task { await store.load() } }, onOpen: onOpen, onApplications: onApplications,
            onPayments: onPayments, onAdminApplications: onAdminApplications, onCatalog: onCatalog, onCommercePolicy: onCommercePolicy, onOrders: onOrders, onReturns: onReturns, onAdminReturns: onAdminReturns, onAdminProducts: onAdminProducts, onOutfits: onOutfits, onAdminOutfits: onAdminOutfits, onPublicProfile: onPublicProfile)
            .task { await store.load() }
            .onDisappear { store.cancelOpening() }
    }
}
struct UFitManagedProfileHost: View {
    @Bindable var store: UFitManagedProfileStore
    let onBack: () -> Void
    var body: some View {
        UFitManagedProfileContent(isCreator: store.document.isCreator, draft: $store.draft, errors: store.errors,
            isBusy: store.isBusy, hasChanges: store.hasChanges, message: store.message, onBack: onBack,
            onSave: { Task { await store.save() } })
    }
}
