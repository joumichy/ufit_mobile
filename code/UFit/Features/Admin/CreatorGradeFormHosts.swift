import SwiftUI

struct UFitCreatorGradeFormHost: View {
    let store: UFitCreatorGradeFormStore
    let onBack: () -> Void
    let onSaved: (UFitCreatorGradeDTO) -> Void
    var body: some View {
        @Bindable var form = store
        Group {
            if store.isCurrentAccount {
                UFitCreatorGradeFormContent(draft: $form.draft, reference: store.original?.row, errors: store.errors,
                    hasChanges: store.hasChanges, isBusy: store.isBusy, isReloading: store.isReloading,
                    referenceIsStale: store.referenceIsStale, message: store.message, messageIsError: store.messageIsError,
                    onBack: onBack, onSave: { Task { if let result = await store.save() { onSaved(result) } } },
                    onReload: { Task { await store.reloadReference() } })
                    .onChange(of: store.draft.code) { _, _ in store.clearError(.code) }
                    .onChange(of: store.draft.label) { _, _ in store.clearError(.label) }
                    .onChange(of: store.draft.rank) { _, _ in store.clearError(.rank) }
                    .onChange(of: store.draft.reason) { _, _ in store.clearError(.reason) }
            } else { UFitCreatorGradeAccessUnavailable(onBack: onBack) }
        }.onDisappear { store.cancelLoading() }
    }
}

struct UFitCreatorGradeChangeHost: View {
    let store: UFitCreatorGradeChangeStore
    let onBack: () -> Void
    let onSaved: (UFitCreatorGradeAssignmentDTO) -> Void
    @State private var choosingGrade = false
    var body: some View {
        @Bindable var form = store
        Group {
            if store.isCurrentAccount {
                UFitCreatorGradeChangeContent(draft: $form.draft, reference: store.reference.presentation, errors: store.errors,
                    hasChanges: store.hasChanges, canChangeGrade: store.canChangeGrade, ineligibilityMessage: store.reference.ineligibilityMessage,
                    isBusy: store.isBusy, isReloading: store.isReloading, referenceIsStale: store.referenceIsStale,
                    message: store.message, messageIsError: store.messageIsError, onBack: onBack,
                    onChooseGrade: { choosingGrade = true }, onReload: { Task { await store.reloadReference() } },
                    onSave: { Task { if let result = await store.save() { onSaved(result) } } })
                    .onChange(of: store.draft.reason) { _, _ in store.clearError(.reason) }
            } else { UFitCreatorGradeAccessUnavailable(onBack: onBack) }
        }.onDisappear { store.cancelLoading() }
            .ufitSheet(isPresented: $choosingGrade) {
                UFitCreatorGradeChoiceHost(store: store, onClose: { choosingGrade = false })
            }
    }
}

struct UFitCreatorGradeChoiceHost: View {
    let store: UFitCreatorGradeChangeStore
    let onClose: () -> Void
    var body: some View {
        @Bindable var choices = store.choices
        Group {
            if store.isCurrentAccount && store.choices.isCurrentAccount {
                UFitCreatorGradeChoiceContent(grades: choices.rows, search: $choices.search, currentGradeCode: store.reference.gradeCode,
                    selectedGradeCode: store.draft.grade?.id, selectableIDs: Set(choices.rows.filter(store.canSelect).map(\.id)),
                    hasLoaded: choices.hasLoaded, isLoading: choices.isLoading, hasMore: choices.nextCursor != nil, message: choices.message,
                    onClose: onClose, onSearch: { Task { await choices.load() } },
                    onReset: { choices.search = String(); Task { await choices.filter(assignable: true) } },
                    onChoose: { grade in
                        store.choose(grade)
                        if store.draft.grade?.id == grade.id { onClose() }
                    }, onMore: { Task { await choices.load(refresh: false) } })
            } else { UFitCreatorGradeAccessUnavailable(onBack: onClose) }
        }.task {
            if choices.assignable == true { await choices.load() }
            else { await choices.filter(assignable: true) }
        }.onDisappear { choices.cancelLoading() }
            .onChange(of: choices.search) { previous, current in
                if !UFitServerTextInput.trimmed(previous).isEmpty && UFitServerTextInput.trimmed(current).isEmpty { Task { await choices.load() } }
            }
    }
}
