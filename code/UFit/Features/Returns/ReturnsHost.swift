import SwiftUI

struct UFitReturnsHost: View {
    let store: UFitReturnsStore
    let onBack: () -> Void
    let onOpen: (String) -> Void
    let onCreate: () -> Void
    private var canCreate: Bool { if case .customer = store.scope { true } else { false } }
    var body: some View {
        UFitReturnsContent(context: store.context, returns: store.summaries, selectedStatus: store.filter, hasLoaded: store.hasLoaded,
            isLoading: store.isLoading, hasMore: store.nextCursor != nil, message: store.message, canCreate: canCreate, onBack: onBack,
            onRefresh: { Task { await store.load() } }, onMore: { Task { await store.load(reset: false) } }, onSelect: onOpen,
            onStatus: { status in Task { await store.select(status) } }, onCreate: onCreate)
            .task { await store.load() }
    }
}
struct UFitReturnDetailHost: View {
    let store: UFitReturnDetailStore
    let onBack: () -> Void
    @State private var form: UFitReturnActionStore?
    @State private var openingMessage: String?
    @State private var refundOrganization: UFitRefundOrganizationStore?
    var body: some View {
        UFitReturnDetailContent(detail: store.presentation, isLoading: store.isLoading, activeAction: store.activeAction,
            message: openingMessage ?? store.message, onBack: onBack, onRefresh: { openingMessage = nil; Task { await store.load() } }, onCommand: { command in
                openingMessage = nil
                if command.action.requiresForm {
                    do { form = try .init(parent: store, command: command) } catch { openingMessage = error.localizedDescription }
                } else { Task { _ = await store.perform(command) } }
            }, onRefundOrganization: canOrganizeRefund ? showRefundOrganization : nil).task { await store.load() }
            .ufitSheet(item: $form) { item in
                UFitReturnActionHost(store: item, onClose: { form = nil }, onRefresh: { form = nil; Task { await store.load() } })
            }
            .ufitSheet(item: $refundOrganization, onDismiss: {Task {await store.load()}}) {current in
                UFitRefundOrganizationHost(store: current, onClose: {refundOrganization = nil})
            }
    }
    private var canOrganizeRefund: Bool {store.detail?.externalSettlement != nil || (store.detail?.status == .refundFailed && store.detail?.refund?.providerStatus != .canceled)}
    private func showRefundOrganization() {
        guard canOrganizeRefund, store.isCurrentAccount else {return}
        refundOrganization = .init(scope: store.list.scope.refundOrganizationScope, reference: .init(kind: .orderReturn, id: store.id), session: store.list.session)
    }
}
private struct UFitReturnActionHost: View {
    @Bindable var store: UFitReturnActionStore
    let onClose: () -> Void
    let onRefresh: () -> Void
    var body: some View {
        UFitReturnActionContent(action: store.command.action, items: store.items, amount: store.amount, draft: $store.draft, hasChanges: store.hasChanges,
            isSaving: store.isSaving, isStale: store.isStale, errors: store.errors, message: store.message, canRefresh: store.canRefresh,
            onClose: onClose, onSave: { Task { if await store.save() { onClose() } } }, onRefresh: onRefresh)
    }
}
struct UFitReturnCreationHost: View {
    @Bindable var store: UFitReturnCreationStore
    let onClose: () -> Void
    let onCreated: (UFitReturnDetailDTO) -> Void
    let onOpenExisting: (String) -> Void
    var body: some View {
        UFitReturnCreationContent(options: store.presentation, draft: $store.draft, preview: store.preview, hasChanges: store.hasChanges,
            isLoading: store.isLoading, isSaving: store.isSaving, isUnresolved: store.isUnresolved, errors: store.errors, message: store.message,
            onClose: onClose, onRefresh: { Task { await store.load() } }, onPreview: { Task { await store.verify() } }, onSubmit: {
                Task { if let result = await store.submit() { onCreated(result) } }
            }, onEdit: store.edit, onOpenExisting: { if let id = store.options?.openReturnId { onOpenExisting(id) } })
            .task { await store.load() }
    }
}
