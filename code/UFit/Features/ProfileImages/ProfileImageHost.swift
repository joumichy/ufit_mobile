import SwiftUI
import PhotosUI

struct UFitProfileImageHost: View {
    @Bindable var store: UFitProfileImageStore
    var name: String?
    var detail: String?
    @State private var editing = false
    @Environment(\.scenePhase) private var scenePhase
    private enum Layout { static let photo: CGFloat = 72; static let gap: CGFloat = UFitSpace.md }
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.gap) {
            HStack(alignment: .center, spacing: Layout.gap) {
                UFitProfilePhoto(source: store.document?.image?.displayUrl, size: Layout.photo, isLogo: store.scope.kind == .brand,
                    onRetry: { await store.refresh() })
                VStack(alignment: .leading, spacing: UFitSpace.xs) {
                    Text(name ?? UFitProfileImageCopy.title(store.scope.kind)).font(UFitTypography.headline)
                    if let detail { Text(detail).font(UFitTypography.subheadline).foregroundStyle(Color.ufitSecondaryText) }
                    if store.isLoading { UFitLoading(UFitProfileImageCopy.loading) }
                    else if store.document != nil {
                        if store.document?.image == nil { Text(UFitProfileImageCopy.empty).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText) }
                        UFitButton(store.pending == nil ? UFitProfileImageCopy.edit : UFitProfileImageCopy.verify) { editing = true }
                            .ufitButtonStyle(.secondary, compact: true).disabled(!store.hasAccess)
                    } else {
                        UFitButton(UFitProfileImageCopy.retry) { Task { await store.refresh() } }.ufitButtonStyle(.secondary, compact: true)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            if let message = store.message { UFitNotice(message: message) }
        }
        .task { if store.document == nil { await store.refresh() } }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await store.refresh() } } }
        .ufitSheet(isPresented: $editing) { UFitProfileImageEditor(store: store, onClose: { editing = false }) }
        .onChange(of: store.hasAccess) { _, access in if !access { editing = false } }
    }
}

private struct UFitProfileImageEditor: View {
    @Bindable var store: UFitProfileImageStore
    let onClose: () -> Void
    @State private var picking = false
    @State private var selection = [PhotosPickerItem]()
    @State private var confirmingClose = false
    private enum Layout { static let preview: CGFloat = 232; static let current: CGFloat = 56; static let gap: CGFloat = UFitSpace.xl; static let maximumPhotos = 1 }
    var body: some View {
        VStack(spacing: .zero) {
            UFitSheetHeader(title: UFitProfileImageCopy.title(store.scope.kind), onClose: close).disabled(store.isBusy)
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.gap) {
                    UFitProfilePhoto(source: store.wantsRemoval ? nil : store.document?.image?.displayUrl, previewData: store.previewData,
                        size: Layout.preview, isLogo: store.scope.kind == .brand, onRetry: { await store.refresh() })
                        .frame(maxWidth: .infinity)
                    Text(store.scope.kind == .account ? UFitProfileImageCopy.privatePhoto : UFitProfileImageCopy.publicPhoto)
                        .font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
                    if store.hasChanges && store.pending == nil {
                        Text(store.wantsRemoval ? UFitProfileImageCopy.removalPreview : UFitProfileImageCopy.preview).font(UFitTypography.subheadline)
                    }
                    if store.hasConflict {
                        UFitNotice(message: UFitProfileImageCopy.conflict)
                        HStack(spacing: UFitSpace.md) {
                            UFitProfilePhoto(source: store.document?.image?.displayUrl, size: Layout.current, isLogo: store.scope.kind == .brand,
                                onRetry: { await store.refresh() })
                            Text(store.document?.image == nil ? UFitProfileImageCopy.empty : UFitProfileImageCopy.current).font(UFitTypography.subheadline)
                        }
                    } else if let message = store.message { UFitNotice(message: message) }
                    if store.isLoading { UFitLoading(UFitProfileImageCopy.loading) }
                    if store.isBusy && !store.hasChanges { UFitLoading(store.activityLabel) }
                    if store.hasChanges {
                        UFitActionButton(title: store.isBusy ? store.activityLabel : store.actionTitle, isBusy: store.isBusy,
                            disabled: !store.canSave) { Task { await store.save() } }
                    }
                    if store.pending == nil {
                        UFitActionButton(title: store.previewData == nil && store.document?.image == nil ? UFitProfileImageCopy.choose : UFitProfileImageCopy.replace,
                            kind: .secondary, disabled: !store.canChoose) { selection = []; picking = true }
                        if store.document?.image != nil || store.previewData != nil {
                            UFitActionButton(title: UFitProfileImageCopy.remove, kind: .secondary, role: .destructive, disabled: !store.canChoose || store.wantsRemoval) { store.remove() }
                        }
                    }
                    if store.pending != nil && store.mayRetryCommand && !store.received {
                        UFitActionButton(title: UFitProfileImageCopy.verify, kind: .secondary, disabled: store.isBusy || store.isLoading) { Task { await store.refresh() } }
                    } else if store.pending == nil && (store.message != nil || store.hasConflict) {
                        UFitActionButton(title: UFitProfileImageCopy.refresh, kind: .secondary, disabled: store.isBusy || store.isLoading) { Task { await store.refresh() } }
                    }
                }.padding(Layout.gap).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
        .interactiveDismissDisabled(store.hasChanges || store.isBusy)
        .ufitPhotosPicker(isPresented: $picking, selection: $selection, limit: Layout.maximumPhotos)
        .onChange(of: selection) { _, items in if let first = items.first { Task { await store.choose(first) } } }
        .task { await store.refresh() }
        .ufitConfirmationDialog(UFitProfileImageCopy.discardTitle, isPresented: $confirmingClose, titleVisibility: .visible) {
            UFitButton(UFitProfileImageCopy.discard, role: .destructive) { store.abandonPreview(); onClose() }
            UFitButton(UFitProfileImageCopy.stay, role: .cancel) {}
        } message: { Text(store.pending == nil ? UFitProfileImageCopy.discardMessage : UFitProfileImageCopy.pendingMessage) }
    }
    private func close() {
        guard !store.isBusy else { return }
        if store.hasChanges { confirmingClose = true } else { onClose() }
    }
}
