import SwiftUI

struct UFitBrandOrdersHost: View {
    let store: UFitBrandOrdersStore
    let onBack: () -> Void
    let onOpen: (String) -> Void
    var body: some View {
        UFitBrandOrdersContent(brandName: store.brandName, orders: store.summaries, selectedStatus: store.filter,
            hasLoaded: store.hasLoaded, isLoading: store.isLoading, hasMore: store.nextCursor != nil, message: store.message,
            onBack: onBack, onRefresh: { Task { await store.load() } }, onRetry: { Task { await store.retry() } },
            onMore: { Task { await store.load(reset: false) } }, onSelect: onOpen, onStatus: { status in Task { await store.select(status) } })
            .task { if !store.hasLoaded { await store.load() } }
    }
}
struct UFitBrandOrderHost: View {
    let store: UFitBrandOrderStore
    let onBack: () -> Void
    @State private var form: UFitShipmentFormStore?
    var body: some View {
        UFitBrandOrderContent(order: store.presentation, isLoading: store.isLoading, activeAction: store.activeAction, message: store.message,
            onBack: onBack, onRefresh: { Task { await store.load() } }, onCommand: { command in
                if command.action.requiresForm {
                    do { form = try UFitShipmentFormStore(parent: store, command: command) } catch { store.recordFailure(error) }
                } else { Task { await store.perform(command) } }
            }).task { if store.order == nil { await store.load() } }
            .ufitSheet(item: $form) { current in
                UFitShipmentFormHost(store: current, onClose: {
                    form = nil
                    if current.canRefresh { Task { await store.load() } }
                }, onSaved: { form = nil }, onRefresh: { form = nil; Task { await store.load() } })
            }
    }
}
private struct UFitShipmentFormHost: View {
    @Bindable var store: UFitShipmentFormStore
    let onClose: () -> Void
    let onSaved: () -> Void
    let onRefresh: () -> Void
    var body: some View {
        UFitShipmentFormContent(action: store.command.action, draft: $store.draft, hasChanges: store.hasChanges,
            isSaving: store.isSaving, isStale: store.isStale, errors: store.errors, message: store.message, canRefresh: store.canRefresh,
            onClose: onClose, onSave: { Task { if await store.save() { onSaved() } else if store.accessLost { onClose() } } }, onRefresh: onRefresh)
    }
}
