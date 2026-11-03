import SwiftUI

struct UFitRefundRecoveryHost: View {
    let store: UFitRefundRecoveryStore
    let onBack: () -> Void
    let onOpen: (UFitRefundRecoveryReference) -> Void
    var body: some View {
        UFitRefundRecoveryContent(rows: store.rows, search: Binding(get: {store.search}, set: {store.search = $0}),
            kind: Binding(get: {store.kind}, set: {value in Task {await store.select(value)}}), totalCount: store.totalCount,
            isLoading: store.isLoading, hasLoaded: store.hasLoaded, hasMore: store.nextCursor != nil, isFiltered: store.isFiltered,
            openingIDs: store.openingIDs, message: store.message, onBack: onBack, onRefresh: {Task {await store.load()}},
            onSearch: {Task {await store.load()}}, onReset: {Task {await store.reset()}}, onMore: {Task {await store.load(reset: false)}}, onOpen: onOpen)
            .task(id: store.search) {await store.searchChanged()}.onDisappear {store.cancelLoading()}
    }
}
struct UFitRefundRecoveryDetailHost: View {
    let store: UFitRefundRecoveryDetailStore
    let onBack: () -> Void
    let onSource: () -> Void
    @State private var organization: UFitRefundOrganizationStore
    init(store: UFitRefundRecoveryDetailStore, onBack: @escaping () -> Void, onSource: @escaping () -> Void) {
        self.store = store; self.onBack = onBack; self.onSource = onSource
        _organization = State(initialValue: UFitRefundOrganizationStore(scope: .administrator, reference: store.reference, session: store.collection.session))
    }
    var body: some View {
        UFitRefundOrganizationHost(store: organization, onClose: onBack, isSheet: false, sourceTitle: store.presentation?.sourceTitle, providerReference: store.presentation?.providerReference, onSource: onSource)
            .onDisappear {store.cancelLoading()}
    }
}
