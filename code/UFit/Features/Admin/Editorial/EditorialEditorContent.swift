import SwiftUI

struct UFitEditorialEditorContent: View {
    let store: UFitEditorialAdministrationStore
    @Bindable var editor: UFitEditorialEditor
    let onBack: () -> Void
    let onAdd: () -> Void
    private typealias Copy = UFitEditorialAdminCopy
    private var editable: Bool { store.allowsMutation && !editor.requiresReload && editor.comparison == nil }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: editor.targetID == nil ? Copy.new : Copy.edit, onBack: onBack).disabled(store.isWorking)
            UFitEditorialAdminFeedback(store: store)
            if editor.requiresReload && editor.comparison == nil && store.pending == nil {
                UFitActionButton(title: Copy.readCurrent, kind: .secondary, isBusy: store.isRefreshingDetail) { Task { await store.refreshDetail() } }
                    .padding(.horizontal, UFitSpace.page)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: UFitSpace.xl) {
                    if let current = editor.comparison { comparison(current) }
                    VStack(alignment: .leading, spacing: UFitSpace.md) {
                        UFitTextField(label: Copy.name, text: $editor.draft.title, error: editor.errors[.title])
                        UFitTextField(label: Copy.subtitle, text: $editor.draft.subtitle, error: editor.errors[.subtitle])
                        UFitMultilineField(label: Copy.description, text: $editor.draft.description, error: editor.errors[.description])
                    }.disabled(!editable)
                    VStack(alignment: .leading, spacing: UFitSpace.md) {
                        UFitEditorialHeading(title: Copy.references, editorial: false)
                        ForEach(Array(editor.draft.references.enumerated()), id: \.element.id) { index, reference in
                            VStack(spacing: UFitSpace.sm) {
                                UFitEditorialReferenceRow(reference: reference)
                                HStack {
                                    referenceAction(Copy.up(reference.title), icon: Copy.upIcon, disabled: index == .zero) { editor.move(reference.id, direction: Copy.up) }
                                    referenceAction(Copy.down(reference.title), icon: Copy.downIcon, disabled: index == editor.draft.references.count - Copy.step) { editor.move(reference.id, direction: Copy.step) }
                                    Spacer()
                                    referenceAction(Copy.remove(reference.title), icon: Copy.removeIcon) { editor.draft.references.removeAll { $0.id == reference.id } }
                                }
                                Divider()
                            }
                        }
                        if editor.draft.references.isEmpty { UFitEmptyState(title: Copy.noReferences, symbol: Copy.icon) }
                        if let error = editor.errors[.references] { UFitFieldError(message: error) }
                        UFitActionButton(title: Copy.add, kind: .secondary, disabled: editor.draft.references.count >= UFitEditorialHTTP.maximumItems, action: onAdd)
                    }.disabled(!editable)
                    UFitDisclosure(Copy.cover) {
                        VStack(alignment: .leading, spacing: UFitSpace.sm) {
                            UFitTextField(label: Copy.coverURL, text: $editor.draft.coverURL, error: editor.errors[.cover], keyboard: .URL, isIdentifier: true)
                            Text(Copy.coverRule).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
                        }
                    }.disabled(!editable)
                }.padding(UFitSpace.page)
            }.scrollDismissesKeyboard(.interactively)
        }.safeAreaInset(edge: .bottom, spacing: .zero) {
            if store.pending == nil {
                VStack(spacing: UFitSpace.sm) {
                    if editable && editor.original?.collection.status == .published { UFitNotice(message: Copy.publishedEdit) }
                    UFitActionButton(title: Copy.save, isBusy: store.isWorking,
                        disabled: !editable || (editor.targetID != nil && !editor.hasChanges)) { Task { await store.save() } }
                }.padding(UFitSpace.md).background(Color.ufitCanvas)
            }
        }
    }
    private func referenceAction(_ title: String, icon: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        UFitButton(action: action) { UFitIcon(systemName: icon).frame(minWidth: UFitControlSize.touch, minHeight: UFitControlSize.touch) }
            .accessibilityLabel(title).disabled(disabled)
    }
    private func comparison(_ current: UFitManagedEditorialDetail) -> some View {
        VStack(alignment: .leading, spacing: UFitSpace.md) {
            UFitDisclosure(Copy.current) {
                VStack(alignment: .leading, spacing: UFitSpace.sm) {
                    Text(current.collection.title).font(UFitTypography.title3)
                    Text(current.collection.status.title).font(UFitTypography.caption)
                    if let subtitle = current.collection.subtitle { Text(subtitle) }
                    Text(current.collection.description)
                    if let cover = current.collection.coverImageUrl { UFitLabeledValue(Copy.cover, value: cover) }
                    ForEach(current.items) { item in UFitEditorialReferenceRow(reference: item.reference) }
                }
            }
            if current.collection.status != .archived {
                UFitActionButton(title: Copy.mine, kind: .secondary) { store.useComparison(keepDraft: true) }
            }
            UFitActionButton(title: Copy.useCurrent, kind: .secondary) { store.useComparison(keepDraft: false) }
        }
    }
}
