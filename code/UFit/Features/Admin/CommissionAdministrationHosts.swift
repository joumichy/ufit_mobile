import SwiftUI

struct UFitCommissionRulesHost: View {
    let store: UFitCommissionRulesStore
    let onBack: () -> Void
    let onCreate: () -> Void
    let onOpen: (UFitCommissionRuleDetailStore) -> Void
    @State private var picker: UFitCommissionReferenceStore?
    var body: some View {
        UFitCommissionRulesContent(rows: store.rows, brand: store.brand, isLoading: store.isLoading, hasLoaded: store.hasLoaded, hasMore: store.nextCursor != nil,
            openingIDs: store.openingIDs, message: store.message, onBack: onBack, onRefresh: { Task { await store.load() } },
            onFilter: { picker = UFitCommissionReferenceStore(kind: .brand, selectedID: store.brand?.id, noneTitle: UFitCommissionAdminCopy.allBrands, session: store.session) },
            onCreate: onCreate, onOpen: { id in Task { if let detail = await store.open(id) { onOpen(detail) } } }, onMore: { Task { await store.load(refresh: false) } })
            .task { await store.load() }.onDisappear { store.cancelLoading() }
            .ufitSheet(item: $picker) { selection in
                UFitCommissionReferenceHost(store: selection, onClose: { picker = nil }, onChoose: { value in
                    guard selection.canSelect(value) else { return }
                    picker = nil; Task { await store.filter(value) }
                })
            }
    }
}
struct UFitCommissionRuleDetailHost: View {
    let store: UFitCommissionRuleDetailStore
    let onBack: () -> Void
    let onEdit: () -> Void
    var body: some View {
        UFitCommissionRuleDetailContent(document: store.document, history: store.history, isLoading: store.isLoading, hasMore: store.nextCursor != nil,
            message: store.message, onBack: onBack, onRefresh: { Task { await store.load() } }, onEdit: onEdit, onMore: { Task { await store.load(refresh: false) } })
            .task { await store.load() }.onDisappear { store.cancelLoading() }
    }
}
struct UFitCommissionRuleFormHost: View {
    let store: UFitCommissionRuleFormStore
    let onBack: () -> Void
    let onSaved: (UFitCommissionRuleDTO) -> Void
    @State private var picker: UFitCommissionReferenceStore?
    var body: some View {
        @Bindable var form = store
        UFitCommissionRuleFormContent(draft: $form.draft, errors: store.errors, isNew: store.isNew, isBusy: store.isBusy, isReloading: store.isReloading, referenceRevision: store.original?.revision,
            hasChanges: store.hasChanges, message: store.message, onBack: onBack, onSave: { Task { if let result = await store.save() { onSaved(result) } } },
            onReload: { Task { await store.reloadReference() } }, onChoose: { kind in
                guard store.isNew, store.isCurrentAccount, !store.isBusy, kind != .product || store.draft.brand != nil else { return }
                picker = UFitCommissionReferenceStore(kind: kind, brandID: store.draft.brand?.id, selectedID: store.reference(kind)?.id,
                    noneTitle: kind == .brand ? nil : kind.unselectedTitle, session: store.collection.session)
            }).onDisappear { store.cancelLoading() }
            .ufitSheet(item: $picker) { selection in
                UFitCommissionReferenceHost(store: selection, onClose: { picker = nil }, onChoose: { value in
                    guard selection.canSelect(value) else { return }
                    store.choose(value, kind: selection.kind); picker = nil
                })
            }
    }
}
struct UFitCommissionReferenceHost: View {
    let store: UFitCommissionReferenceStore
    let onClose: () -> Void
    let onChoose: (UFitCommissionReference?) -> Void
    var body: some View {
        @Bindable var picker = store
        UFitCommissionReferenceContent(title: store.kind.title, noneTitle: store.noneTitle, rows: store.rows, selectedID: store.selectedID,
            search: $picker.search, isLoading: store.isLoading, hasLoaded: store.hasLoaded, hasMore: store.nextCursor != nil, message: store.message,
            onClose: onClose, onSearch: { Task { await store.load() } }, onChoose: onChoose, onMore: { Task { await store.load(refresh: false) } })
            .task { await store.load() }.onDisappear { store.cancelLoading() }
    }
}
