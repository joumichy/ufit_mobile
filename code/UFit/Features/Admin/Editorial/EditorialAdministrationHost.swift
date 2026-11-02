import SwiftUI

struct UFitEditorialAdministrationHost: View {
    @Bindable var store: UFitEditorialAdministrationStore
    let onBack: () -> Void
    @State private var confirmingDiscard = false
    @State private var picker: UFitEditorialReferencePickerStore?
    var body: some View {
        Group {
            if !store.isCurrentAccount {
                VStack {
                    DetailHeader(title: UFitEditorialAdminCopy.title, onBack: onBack)
                    UFitEmptyState(title: UFitEditorialAdminCopy.access, symbol: UFitEditorialAdminCopy.icon)
                    Spacer()
                }
            } else if let editor = store.editor {
                UFitEditorialEditorContent(store: store, editor: editor, onBack: back,
                    onAdd: { picker = UFitEditorialReferencePickerStore(collection: store) })
            } else if let detail = store.detail {
                UFitEditorialAdminDetailContent(store: store, detail: detail, onBack: back)
            } else { UFitEditorialAdminListContent(store: store, onBack: back) }
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.ufitCanvas).ufitButtonStyle(.text)
            .task { await store.activate() }.onDisappear { store.cancelLoading() }
            .ufitSheet(item: $picker) { value in
                UFitEditorialReferencePickerContent(store: value, onClose: { picker = nil })
            }
            .ufitConfirmationDialog(UFitEditorialAdminCopy.discard, isPresented: $confirmingDiscard) {
                UFitButton(UFitEditorialAdminCopy.discard, role: .destructive, action: performBack)
                UFitButton(UFitEditorialAdminCopy.keepEditing, role: .cancel) {}
            }
    }
    private func back() {
        if store.editor?.hasChanges == true, store.pending == nil { confirmingDiscard = true }
        else { performBack() }
    }
    private func performBack() { if !store.back() { onBack() } }
}

struct UFitEditorialAdminFeedback: View {
    let store: UFitEditorialAdministrationStore
    var body: some View {
        if store.message != nil || store.pending != nil || !store.storageReady {
            VStack(alignment: .leading, spacing: UFitSpace.sm) {
                if let message = store.message { UFitNotice(message: message, kind: store.messageKind) }
                if let pending = store.pending {
                    if store.isWorking { UFitLoading(UFitEditorialAdminCopy.processing) }
                    else {
                        if store.message == nil { UFitNotice(message: UFitEditorialAdminCopy.pending) }
                        if let draft = pending.draft { Text(draft.title).font(UFitTypography.headline) }
                        UFitActionButton(title: store.canRetry ? UFitEditorialAdminCopy.retrySend : UFitEditorialAdminCopy.verify,
                            action: { Task { if store.canRetry { await store.retry() } else { await store.recover() } } })
                        if store.canRetry { UFitButton(UFitEditorialAdminCopy.verify) { Task { await store.recover() } } }
                    }
                } else if !store.storageReady {
                    UFitActionButton(title: UFitFeedbackCopy.retry, kind: .secondary) { Task { await store.activate() } }
                }
            }.padding(.horizontal, UFitSpace.page).padding(.bottom, UFitSpace.md)
        }
    }
}
struct UFitEditorialReferenceRow: View {
    let reference: UFitEditorialReference
    var body: some View {
        HStack(spacing: UFitSpace.md) {
            Rectangle().fill(Color.ufitSecondary).overlay {
                if let image = reference.imageURL { FashionImage(source: image).clipped() }
                else { UFitIcon(systemName: UFitEditorialAdminCopy.photoIcon).foregroundStyle(Color.ufitSecondaryText) }
            }.frame(width: Layout.width, height: Layout.height).clipped().accessibilityHidden(true)
            VStack(alignment: .leading, spacing: UFitSpace.xs) {
                Text(reference.kind == .outfit ? UFitEditorialCopy.outfit : UFitEditorialCopy.product).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                Text(reference.title).font(UFitTypography.headline).fixedSize(horizontal: false, vertical: true)
                if !reference.available { Text(UFitEditorialAdminCopy.unavailable).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText) }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private enum Layout { static let width: CGFloat = 64, height: CGFloat = 84 }
}
