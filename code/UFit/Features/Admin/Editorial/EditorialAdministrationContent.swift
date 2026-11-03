import SwiftUI

struct UFitEditorialAdminListContent: View {
    @Bindable var store: UFitEditorialAdministrationStore
    let onBack: () -> Void
    private typealias Copy = UFitEditorialAdminCopy
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: Copy.title, onBack: onBack) {
                UFitButton(UFitEditorialCopy.refresh) { Task { await store.load() } }.disabled(store.isLoading)
            }
            UFitEditorialAdminFeedback(store: store)
            if let error = store.listError, !store.moreFailed {
                VStack(spacing: UFitSpace.sm) {
                    UFitNotice(message: error, kind: .error)
                    UFitActionButton(title: UFitFeedbackCopy.retry, kind: .secondary) { Task { await store.load() } }
                }.padding(.horizontal, UFitSpace.page).padding(.bottom, UFitSpace.md)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: UFitSpace.lg) {
                    UFitSelection(Copy.filter, selection: Binding(get: { store.status }, set: { value in Task { await store.filter(value) } }),
                        options: [.init(value: nil, title: Copy.all)] + UFitEditorialStatus.allCases.map { .init(value: Optional($0), title: $0.title) })
                        .disabled(store.isWorking)
                    UFitActionButton(title: Copy.create, disabled: !store.allowsMutation, action: store.create)
                    if store.isLoading { UFitLoading(Copy.loading) }
                    if store.hasLoaded && store.rows.isEmpty && store.listError == nil && !store.isLoading {
                        UFitEmptyState(title: Copy.empty, symbol: Copy.icon)
                    }
                    LazyVStack(alignment: .leading, spacing: UFitSpace.md) {
                        ForEach(store.rows) { row in
                            VStack(alignment: .leading, spacing: UFitSpace.xs) {
                                UFitButton { Task { await store.open(row.id) } } label: {
                                    HStack(spacing: UFitSpace.md) {
                                        VStack(alignment: .leading, spacing: UFitSpace.xs) {
                                            Text(row.title).font(UFitTypography.title3).fixedSize(horizontal: false, vertical: true)
                                            Text(row.status.title).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                                        }.frame(maxWidth: .infinity, alignment: .leading)
                                        if store.openingIDs.contains(row.id) { UFitLoading() }
                                        else { UFitIcon(systemName: UFitEditorialCopy.chevron) }
                                    }.frame(minHeight: UFitControlSize.touch)
                                }.disabled(store.openingIDs.contains(row.id))
                                if let error = store.rowErrors[row.id] { UFitNotice(message: error, kind: .error) }
                                Divider()
                            }.id(row.id)
                        }
                    }.scrollTargetLayout()
                    if let error = store.listError, store.moreFailed {
                        UFitNotice(message: error, kind: .error)
                        UFitActionButton(title: UFitFeedbackCopy.retry, kind: .secondary) { Task { await store.load(more: true) } }
                    }
                    if store.isLoadingMore { UFitLoading(UFitEditorialCopy.loadingMore) }
                    else if store.nextCursor != nil && store.listError == nil {
                        UFitActionButton(title: UFitEditorialCopy.more, kind: .secondary) { Task { await store.load(more: true) } }
                    }
                }.padding(.vertical, UFitSpace.page)
            }.padding(.horizontal, UFitSpace.page).scrollPosition(id: $store.visibleRowID, anchor: .top)
        }.task { if !store.hasLoaded { await store.load() } }
    }
}

struct UFitEditorialAdminDetailContent: View {
    let store: UFitEditorialAdministrationStore
    let detail: UFitManagedEditorialDetail
    let onBack: () -> Void
    @State private var archiving = false
    private typealias Copy = UFitEditorialAdminCopy
    private var canPublish: Bool { !detail.items.isEmpty && detail.items.allSatisfy(\.available) }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: Copy.detail, onBack: onBack) {
                UFitButton(UFitEditorialCopy.refresh) { Task { await store.refreshDetail() } }.disabled(store.isRefreshingDetail || store.isWorking)
            }.disabled(store.isWorking)
            UFitEditorialAdminFeedback(store: store)
            ScrollView {
                VStack(alignment: .leading, spacing: UFitSpace.lg) {
                    UFitEditorialHeading(title: detail.collection.title, eyebrow: detail.collection.status.title)
                    if let subtitle = detail.collection.subtitle { Text(subtitle).font(UFitTypography.title3) }
                    Text(detail.collection.description).font(UFitTypography.body).fixedSize(horizontal: false, vertical: true)
                    if store.isRefreshingDetail { UFitLoading(Copy.loadingDetail) }
                    if detail.collection.status == .draft {
                        UFitActionButton(title: Copy.publish, disabled: !store.allowsMutation || !canPublish) { Task { await store.transition(.publish) } }
                        if !canPublish { UFitNotice(message: Copy.cannotPublish) }
                        UFitActionButton(title: Copy.modify, kind: .secondary, disabled: !store.allowsMutation, action: store.edit)
                    } else if detail.collection.status == .published {
                        UFitActionButton(title: Copy.modify, disabled: !store.allowsMutation, action: store.edit)
                    } else {
                        UFitActionButton(title: Copy.restore, disabled: !store.allowsMutation) { Task { await store.transition(.restore) } }
                    }
                    UFitEditorialHeading(title: Copy.references, editorial: false)
                    if detail.items.isEmpty { UFitEmptyState(title: Copy.noReferences, symbol: Copy.icon) }
                    ForEach(detail.items) { item in UFitEditorialReferenceRow(reference: item.reference); Divider() }
                    if detail.collection.status != .archived {
                        UFitActionButton(title: Copy.archive, kind: .secondary, role: .destructive, disabled: !store.allowsMutation) { archiving = true }
                    }
                }.padding(UFitSpace.page)
            }
        }.ufitConfirmationDialog(Copy.archive, isPresented: $archiving) {
            UFitButton(Copy.archive, role: .destructive) { Task { await store.transition(.archive) } }
            UFitButton(Copy.cancel, role: .cancel) {}
        } message: { Text(detail.collection.status == .published ? Copy.archiveMessage : Copy.archiveDraftMessage) }
    }
}
