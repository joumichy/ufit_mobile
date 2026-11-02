import SwiftUI

struct UFitStylePreferencesHost: View {
    @Bindable var store: UFitStylePreferencesStore
    let onBack: () -> Void
    var onComplete: (() -> Void)? = nil
    private typealias Copy = UFitStylePreferencesCopy
    private var primaryTitle: String {
        if store.pending != nil { return store.canRetry ? Copy.retrySave : Copy.verify }
        if store.requiresReload { return Copy.reload }
        if store.comparison != nil { return Copy.keepMine }
        return onComplete == nil ? Copy.save : Copy.discover
    }
    var body: some View {
        VStack(spacing: .zero) {
            if onComplete == nil { DetailHeader(title: Copy.title, onBack: onBack) }
            ScrollView {
                VStack(alignment: .leading, spacing: UFitSpace.lg) {
                    if onComplete != nil { UFitEditorialHeading(title: Copy.onboardingTitle) }
                    Text(store.scope == .guest ? Copy.guestDetail : Copy.accountDetail)
                        .font(UFitTypography.body).foregroundStyle(Color.ufitSecondaryText)
                    if !store.hasLoaded && store.pending == nil {
                        if store.isLoading || !store.isCurrent { UFitLoading(Copy.loading).frame(maxWidth: .infinity) }
                        else {
                            UFitEmptyState(title: Copy.failedTitle, message: store.message, symbol: Copy.errorIcon,
                                actionTitle: Copy.retry, action: { Task { await store.load() } })
                        }
                    } else {
                        if let message = store.message { UFitNotice(message: message, kind: store.messageKind) }
                        if let comparison = store.comparison {
                            UFitLabeledValue(Copy.current, value: store.summary(comparison))
                        }
                        if store.styles.isEmpty { UFitNotice(message: Copy.noneAvailable) }
                        else {
                            VStack(spacing: UFitSpace.xs) {
                                ForEach(store.styles) { style in
                                    UFitToggle(style.label, isOn: Binding(get: { store.draft.contains(style.id) }, set: { selected in
                                        if selected { store.draft.insert(style.id) } else { store.draft.remove(style.id) }
                                    })).disabled(!store.allowsEditing)
                                }
                            }
                        }
                        UFitActionButton(title: primaryTitle, isBusy: store.isBusy,
                            disabled: !store.isCurrent || (store.pending == nil && !store.requiresReload && store.comparison == nil
                                && (!store.allowsEditing || (!store.hasChanges && onComplete == nil))), action: apply)
                        if store.comparison != nil {
                            UFitActionButton(title: Copy.useCurrent, kind: .secondary, action: { store.keepCurrent() }).disabled(store.isBusy)
                        }
                    }
                    if let onComplete, store.pending == nil {
                        HStack {
                            UFitButton(Copy.back, action: onBack)
                            Spacer(minLength: UFitSpace.md)
                            UFitButton(Copy.skip) { store.discardDraft(); onComplete() }
                        }.ufitButtonStyle(.text).disabled(store.isSaving)
                    }
                }.padding(UFitSpace.page)
            }.scrollIndicators(.hidden)
        }.foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
            .task {
                if store.isCurrent && store.hasLoaded { await store.load() }
                else { await store.activate() }
            }
    }
    private func apply() {
        Task {
            if store.pending != nil {
                if store.canRetry { _ = await store.retry() } else { await store.load() }
            } else if store.requiresReload { await store.load(); return }
            else {
                if store.comparison != nil { store.keepMine() }
                guard await store.save() else { return }
            }
            if store.pending == nil, store.comparison == nil, store.hasLoaded, !store.hasChanges { onComplete?() }
        }
    }
}
