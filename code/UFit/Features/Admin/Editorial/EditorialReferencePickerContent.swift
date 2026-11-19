import SwiftUI

struct UFitEditorialReferencePickerContent: View {
    @Bindable var store: UFitEditorialReferencePickerStore
    let onClose: () -> Void
    private typealias Copy = UFitEditorialAdminCopy
    private var selectedIDs: Set<String> { Set(store.collection.editor?.draft.references.map(\.id) ?? []) }
    var body: some View {
        VStack(spacing: UFitSpace.md) {
            UFitSheetHeader(title: Copy.choose, onClose: onClose)
            VStack(spacing: UFitSpace.md) {
                UFitChoiceBar(title: Copy.kind, selection: Binding(get: { store.kind }, set: { value in Task { await store.filter(value) } }), options: [
                    .init(value: .outfit, title: Copy.outfits), .init(value: .product, title: Copy.products)])
                UFitSearchField(query: $store.search, prompt: Copy.search).onSubmit { Task { await store.load() } }
                UFitActionButton(title: Copy.searchAction, kind: .secondary, disabled: store.isLoading) { Task { await store.load() } }
            }.padding(.horizontal, UFitSpace.page)
            if let message = store.message, !store.moreFailed {
                VStack(spacing: UFitSpace.sm) {
                    UFitNotice(message: message, kind: .error)
                    UFitActionButton(title: UFitFeedbackCopy.retry, kind: .secondary) { Task { await store.load() } }
                }.padding(.horizontal, UFitSpace.page)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: UFitSpace.md) {
                    if store.isLoading { UFitLoading() }
                    if store.hasLoaded && store.rows.isEmpty && store.message == nil && !store.isLoading { UFitEmptyState(title: Copy.noResults, symbol: Copy.icon) }
                    LazyVStack(spacing: UFitSpace.md) {
                        ForEach(store.rows) { reference in
                            UFitButton { if store.select(reference) { onClose() } } label: {
                                VStack(alignment: .leading, spacing: UFitSpace.sm) {
                                    UFitEditorialReferenceRow(reference: reference)
                                    if selectedIDs.contains(reference.id) { Text(Copy.alreadyAdded).font(UFitTypography.caption) }
                                }
                            }.disabled(selectedIDs.contains(reference.id) || !store.collection.allowsMutation)
                                .accessibilityLabel(Copy.add(reference.title))
                            Divider()
                        }
                    }
                    if let message = store.message, store.moreFailed {
                        UFitNotice(message: message, kind: .error)
                        UFitActionButton(title: UFitFeedbackCopy.retry, kind: .secondary) { Task { await store.load(more: true) } }
                    }
                    if store.isLoadingMore { UFitLoading() }
                    else if store.nextCursor != nil && store.message == nil {
                        UFitActionButton(title: UFitEditorialCopy.more, kind: .secondary) { Task { await store.load(more: true) } }
                    }
                }.padding(UFitSpace.page)
            }
        }.foregroundStyle(Color.ufitInk).background(Color.ufitCanvas).ufitButtonStyle(.text)
            .task { await store.load() }.onDisappear { store.cancel() }
    }
}
