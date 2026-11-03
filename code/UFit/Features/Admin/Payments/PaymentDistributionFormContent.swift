import SwiftUI

struct UFitDistributionFormContent: View {
    @Bindable var store: UFitDistributionFormStore
    let onBack: () -> Void; let onSubmit: () -> Void
    @State private var confirmsDiscard = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private typealias Copy = UFitDistributionCopy
    private var bearerOptions: [UFitSelectionOption<UFitDistributionFeeBearer?>] {
        UFitDistributionFeeBearer.allCases.map { .init(value: Optional($0), title: $0.label) }
    }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: store.reference.current == nil ? Copy.configure : Copy.edit,
                onBack: { if store.hasChanges || store.pendingState != nil { confirmsDiscard = true } else { onBack() } })
                .disabled(store.isBusy || store.isReloading)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: UFitSpace.xl) {
                        Text(store.reference.brand.name).font(UFitTypography.title2).accessibilityAddTraits(.isHeader)
                        if let message = store.message { UFitNotice(message: message, kind: store.messageIsError ? .error : .information) }
                        if let policy = store.reference.current {
                            UFitDisclosure(Copy.current) {
                                VStack(alignment: .leading, spacing: UFitSpace.sm) {
                                    Text(Copy.revision(policy.revision)).font(UFitTypography.headline)
                                    UFitLabeledValue(Copy.platformShare, value: policy.rateLabel)
                                    UFitLabeledValue(Copy.feeBearer, value: policy.feeBearer.label)
                                    Text(policy.statusLabel)
                                }.font(UFitTypography.callout)
                            }
                        }
                        if store.referenceIsStale {
                            UFitActionButton(title: Copy.refreshReference, kind: .secondary, isBusy: store.isReloading) { Task { await store.reloadReference() } }
                        }
                        VStack(alignment: .leading, spacing: UFitSpace.sm) {
                            UFitTextField(label: Copy.platformRate, text: $store.draft.rate, error: store.errors[.rate], keyboard: .decimalPad)
                            Text(Copy.basis).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                        }.id(UFitDistributionField.rate)
                        VStack(alignment: .leading, spacing: UFitSpace.sm) {
                            Text(Copy.feeBearer).font(UFitTypography.headline)
                            UFitInlineChoice(title: Copy.feeBearer, selection: $store.draft.bearer, options: bearerOptions)
                            if let error = store.errors[.bearer] { UFitFieldError(message: error) }
                            if let bearer = store.draft.bearer {
                                Text(bearer == .brand ? Copy.brandCost : Copy.platformCost).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                            }
                        }.id(UFitDistributionField.bearer)
                        UFitToggle(Copy.activate, isOn: $store.draft.active)
                        UFitMultilineField(label: Copy.reason, text: $store.draft.reason, error: store.errors[.reason])
                            .id(UFitDistributionField.reason)
                        Text(Copy.future).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                    }.padding(UFitSpace.page).disabled(store.fieldsLocked)
                }.scrollDismissesKeyboard(.interactively)
                    .onChange(of: store.validationAttempt) { _, _ in
                        guard let first = [UFitDistributionField.rate, .bearer, .reason].first(where: { store.errors[$0] != nil }) else { return }
                        if reduceMotion { proxy.scrollTo(first, anchor: .top) }
                        else { withAnimation(.easeOut(duration: UFitMotion.feedback)) { proxy.scrollTo(first, anchor: .top) } }
                    }
            }
        }.safeAreaInset(edge: .bottom, spacing: .zero) {
            UFitActionButton(title: store.actionTitle, isBusy: store.isBusy, disabled: !store.canSubmit, action: onSubmit)
                .padding(UFitSpace.md).background(Color.ufitCanvas)
                .overlay(alignment: .top) { Rectangle().fill(Color.ufitBorder).frame(height: UFitSpace.hairline) }
        }.ufitButtonStyle(.text).foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
            .onChange(of: store.draft.rate) { _, _ in store.clearError(.rate) }
            .onChange(of: store.draft.bearer) { _, _ in store.clearError(.bearer) }
            .onChange(of: store.draft.reason) { _, _ in store.clearError(.reason) }
            .onDisappear { store.cancelLoading() }
            .ufitConfirmationDialog(store.pendingState != nil ? Copy.unknownLeave : Copy.discardTitle, isPresented: $confirmsDiscard, titleVisibility: .visible) {
                UFitButton(Copy.discard, role: .destructive, action: onBack).ufitButtonStyle(.secondary)
                UFitButton(Copy.keep, role: .cancel) {}.ufitButtonStyle(.primary)
            }
    }
}
