import SwiftUI

struct UFitNotificationPreferencesHost: View {
    @Bindable var store: UFitNotificationPreferencesStore
    let onBack: () -> Void
    var body: some View {
        UFitNotificationPreferencesContent(choices: $store.draft, hasLoaded: store.document != nil, hasChanges: store.hasChanges,
            isLoading: store.isLoading, isSaving: store.isSaving, requiresReload: store.requiresReload,
            allowsEditing: store.document?.allowsEditing ?? false, comparison: store.comparison,
            disablesChannel: store.document.map { ($0.emailEnabled && !store.draft.emailEnabled) || ($0.pushEnabled && !store.draft.pushEnabled) } ?? false,
            message: store.message, messageKind: store.messageKind, onBack: onBack,
            onReload: { Task { await store.load() } }, onSave: { Task { await store.save() } })
            .task { if store.document == nil { await store.load() } }
            .onDisappear { store.cancelLoading() }
    }
}
