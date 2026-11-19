import SwiftUI

struct UFitUserAdministrationHost: View {
    let store: UFitUserAdministrationStore
    let onBack: () -> Void
    let onOpen: (UFitUserAdministrationDetailStore) -> Void
    var body: some View {
        @Bindable var list = store
        Group {
            if store.isCurrentAccount {
                UFitUserAdministrationContent(users: store.users.map(\.row), search: $list.search,
                    status: Binding(get: { store.status }, set: { value in Task { await store.filter(status: value, role: store.role) } }),
                    role: Binding(get: { store.role }, set: { value in Task { await store.filter(status: store.status, role: value) } }),
                    isLoading: store.isLoading, hasLoaded: store.hasLoaded, openingIDs: store.openingIDs, hasMore: store.nextCursor != nil,
                    message: store.message, onBack: onBack, onSearch: { Task { await store.load() } }, onRefresh: { Task { await store.load() } },
                    onReset: { store.search = String(); Task { await store.filter(status: nil, role: nil) } },
                    onOpen: { id in Task { if let detail = await store.open(id) { onOpen(detail) } } },
                    onMore: { Task { await store.load(refresh: false) } })
            } else {
                UFitEmptyState(title: UFitUserAdministrationCopy.unavailable, actionTitle: UFitUserAdministrationCopy.back, action: onBack)
            }
        }.task { await store.load() }.onDisappear { store.cancelLoading() }
            .onChange(of: store.search) { previous, current in
                if !UFitServerTextInput.trimmed(previous).isEmpty && UFitServerTextInput.trimmed(current).isEmpty {
                    Task { await store.load() }
                }
            }
    }
}

struct UFitUserAdministrationDetailHost: View {
    let store: UFitUserAdministrationDetailStore
    let onBack: () -> Void
    let onDecide: (UFitUserAccessDecision) -> Void
    @State private var showingProfiles = false
    @State private var profiles: UFitProfileAdministrationStore
    init(store: UFitUserAdministrationDetailStore, onBack: @escaping () -> Void, onDecide: @escaping (UFitUserAccessDecision) -> Void) {
        self.store = store; self.onBack = onBack; self.onDecide = onDecide
        let kind: UFitAdministeredProfileKind = store.user.roles.contains(.creator) ? .creator :
            (store.user.roles.contains(.brandOwner) || store.user.roles.contains(.brandManager) ? .brand : .creator)
        _profiles = State(initialValue: UFitProfileAdministrationStore(collection: store.collection, userID: store.user.id, initialKind: kind))
    }
    var body: some View {
        Group {
            if store.isCurrentAccount, showingProfiles {
                UFitProfileAdministrationHost(store: profiles, onBack: { showingProfiles = false })
            } else if store.isCurrentAccount {
                UFitUserAdministrationDetailContent(document: store.user.document, history: store.history.map(\.row),
                    isLoading: store.isLoading, hasLoadedHistory: store.hasLoadedHistory, hasMore: store.nextCursor != nil,
                    message: store.message, onBack: onBack, onRefresh: { Task { await store.load() } }, onDecide: onDecide,
                    onMore: { Task { await store.load(refresh: false) } }, onProfiles: { showingProfiles = true })
            } else {
                UFitEmptyState(title: UFitUserAdministrationCopy.unavailable, actionTitle: UFitUserAdministrationCopy.back, action: onBack)
            }
        }.task { await store.load() }.onDisappear { store.cancelLoading() }
    }
}

struct UFitUserAccessDecisionHost: View {
    let store: UFitUserAccessDecisionStore
    let onBack: () -> Void
    let onSaved: (UFitAdministeredUserDTO) -> Void
    var body: some View {
        @Bindable var form = store
        Group {
            if store.isCurrentAccount {
                UFitUserAccessDecisionContent(user: store.original.row, decision: store.decision, reason: $form.reason,
                    reasonError: store.reasonError, message: store.message, messageIsError: store.messageIsError,
                    isBusy: store.isBusy, isReloading: store.isReloading, canDecide: store.canDecide, hasChanges: store.hasChanges,
                    onBack: onBack, onSave: { Task { if let result = await store.save() { onSaved(result) } } },
                    onReload: { Task { await store.reloadReference() } })
                    .onChange(of: store.reason) { _, _ in store.clearReasonError() }
            } else {
                UFitEmptyState(title: UFitUserAdministrationCopy.unavailable, actionTitle: UFitUserAdministrationCopy.back, action: onBack)
            }
        }.onDisappear { store.cancelLoading() }
    }
}
