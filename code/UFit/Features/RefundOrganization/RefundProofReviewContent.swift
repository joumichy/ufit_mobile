import SwiftUI

struct UFitRefundProofReviewContent: View {
    @Bindable var store: UFitRefundProofReviewStore
    let onClose: () -> Void
    let onOpenProof: () -> Void
    let isOpeningProof: Bool
    let proofMessage: String?
    @State private var confirming = false
    @State private var confirmingClose = false
    private var locked: Bool {store.isBusy || store.pending != nil || store.localFailed}
    var body: some View {
        VStack(spacing: .zero) {
            UFitSheetHeader(title: store.pending == nil ? UFitRefundReviewCopy.title : UFitRefundOrganizationCopy.pendingTitle, onClose: requestClose).disabled(store.isBusy)
            ScrollView {
                VStack(alignment: .leading, spacing: UFitSpace.lg) {
                    Text(store.document.summary.orderNumber).font(UFitTypography.headline)
                    Text(store.amount).font(UFitTypography.editorialTitle)
                    if let proof = store.document.proof {
                        UFitLabeledValue(UFitRefundProofCopy.reference, value: proof.transferReference)
                        UFitLabeledValue(UFitRefundProofCopy.dateLabel, value: proof.presentation.date)
                        UFitActionButton(title: UFitRefundProofCopy.view, kind: .secondary, isBusy: isOpeningProof, action: onOpenProof)
                        if let proofMessage {UFitNotice(message: proofMessage, kind: .error)}
                    }
                    if let pending = store.pending {
                        UFitLabeledValue(UFitRefundReviewCopy.decision, value: pending.decision == .reject ? UFitRefundReviewCopy.reject : UFitRefundReviewCopy.confirm)
                        UFitLabeledValue(UFitRefundReviewCopy.reason, value: pending.reason)
                        if let reference = pending.verificationReference {UFitLabeledValue(UFitRefundReviewCopy.verification, value: reference)}
                    } else {
                        VStack(alignment: .leading, spacing: UFitSpace.xs) {
                            Text(UFitRefundReviewCopy.decision).font(UFitTypography.subheadline.weight(.semibold))
                            UFitInlineChoice(title: UFitRefundReviewCopy.decision, selection: $store.decision, options: [
                                .init(value: .some(.reject), title: UFitRefundReviewCopy.reject), .init(value: .some(.confirm), title: UFitRefundReviewCopy.confirm)
                            ]).disabled(locked)
                            if let error = store.decisionError {UFitFieldError(message: error)}
                        }
                        UFitMultilineField(label: UFitRefundReviewCopy.reason, text: $store.reason, error: store.reasonError).disabled(locked)
                        if store.decision == .confirm {
                            UFitTextField(label: UFitRefundReviewCopy.verification, text: $store.verificationReference, error: store.referenceError, isIdentifier: true).disabled(locked)
                            Text(UFitRefundReviewCopy.consequence).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
                        }
                    }
                    if let message = store.message {UFitNotice(message: message, kind: .information)}
                    if store.localFailed {UFitButton(UFitRefundOrganizationCopy.recoverLocal) {Task {await store.compare()}}.ufitButtonStyle(.secondary).disabled(store.isBusy)}
                    else if store.pending != nil {
                        UFitButton(UFitRefundOrganizationCopy.verify) {Task {await store.verify()}}.ufitButtonStyle(.secondary).disabled(store.isBusy)
                        if store.canRetry {UFitButton(UFitRefundOrganizationCopy.retryExact) {Task {await store.send()}}.ufitButtonStyle(.primary).disabled(store.isBusy)}
                    } else if store.isStale {
                        if let current = store.comparison {
                            Divider(); Text(UFitRefundOrganizationCopy.current).font(UFitTypography.headline)
                            Text(current.presentation(scope: .administrator).status).font(UFitTypography.callout)
                            if let proof = current.proof {UFitLabeledValue(UFitRefundProofCopy.reference, value: proof.transferReference)}
                            if let reason = current.proof?.review?.reason {UFitLabeledValue(UFitRefundReviewCopy.reason, value: reason)}
                            if store.canUseVersion {UFitButton(UFitRefundOrganizationCopy.useCurrentVersion, action: store.useVersion).ufitButtonStyle(.secondary).disabled(store.isBusy)}
                        } else {UFitButton(UFitRefundOrganizationCopy.compare) {Task {await store.compare()}}.ufitButtonStyle(.secondary).disabled(store.isBusy)}
                    }
                    if store.isBusy {UFitLoading(UFitRefundOrganizationCopy.saving).frame(maxWidth: .infinity)}
                }.padding(UFitSpace.page).frame(maxWidth: .infinity, alignment: .leading)
            }.scrollDismissesKeyboard(.interactively)
        }.safeAreaInset(edge: .bottom, spacing: .zero) {
            if store.pending == nil && !store.localFailed {
                UFitButton(store.decision == .reject ? UFitRefundReviewCopy.reject : store.decision == .confirm ? UFitRefundReviewCopy.confirm : UFitRefundReviewCopy.submit) {
                    if store.decision == .confirm {
                        if store.validateDraft() {confirming = true}
                    } else {Task {await store.save()}}
                }.ufitButtonStyle(.primary).disabled(store.isBusy || store.isStale)
                    .padding(UFitSpace.page).background(Color.ufitCanvas).overlay(alignment: .top) {Divider()}
            }
        }.foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
            .interactiveDismissDisabled(store.isBusy || store.hasChanges)
            .ufitConfirmationDialog(UFitRefundReviewCopy.confirmation, isPresented: $confirming) {
                UFitButton(UFitRefundReviewCopy.confirm) {Task {await store.save()}}
                UFitButton(UFitRefundOrganizationCopy.cancel, role: .cancel) {}
            }.ufitConfirmationDialog(UFitRefundOrganizationCopy.discard, isPresented: $confirmingClose) {
                UFitButton(UFitRefundOrganizationCopy.abandon, role: .destructive, action: onClose)
                UFitButton(UFitRefundOrganizationCopy.keepEditing, role: .cancel) {}
            }.task {await store.load()}.onDisappear {store.cancelLoading()}
            .onChange(of: store.isComplete) {_, complete in if complete {onClose()}}
            .onChange(of: store.hasAccess) {_, allowed in if !allowed {onClose()}}
    }
    private func requestClose() {if store.hasChanges && store.pending == nil {confirmingClose = true} else {onClose()}}
}

struct UFitRefundProofHistoryContent: View {
    let store: UFitRefundOrganizationStore
    let onClose: () -> Void
    var body: some View {
        VStack(spacing: .zero) {
            UFitSheetHeader(title: UFitRefundProofCopy.history, onClose: onClose)
            ScrollView {
                VStack(alignment: .leading, spacing: UFitSpace.lg) {
                    if let message = store.historyMessage {UFitNotice(message: message, kind: .error)}
                    ForEach(store.proofHistory, id: \.id) {proof in
                        VStack(alignment: .leading, spacing: UFitSpace.sm) {
                            Text(UFitRefundReviewCopy.proofNumber(proof.sequence)).font(UFitTypography.headline)
                            UFitRefundProofFactsContent(proof: proof.presentation)
                            if let message = store.proofDownloadErrors[proof.id] {UFitNotice(message: message, kind: .error)}
                            UFitActionButton(title: UFitRefundProofCopy.view, kind: .secondary, isBusy: store.openingProofIDs.contains(proof.id)) {Task {await store.openProof(proof)}}
                        }
                        Divider()
                    }
                    if store.isLoadingHistory {UFitLoading().frame(maxWidth: .infinity)}
                    else if store.proofHistory.isEmpty && store.historyMessage == nil {UFitEmptyState(title: UFitRefundProofCopy.historyEmpty)}
                    if store.historyCursor != nil {UFitButton(UFitRefundProofCopy.historyMore) {Task {await store.loadHistory(reset: false)}}.ufitButtonStyle(.secondary).disabled(store.isLoadingHistory)}
                    UFitButton(UFitRefundOrganizationCopy.refresh) {Task {await store.loadHistory(reset: true)}}.ufitButtonStyle(.secondary).disabled(store.isLoadingHistory)
                }.padding(UFitSpace.page).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.foregroundStyle(Color.ufitInk).background(Color.ufitCanvas).task {await store.loadHistory(reset: true)}
    }
}
struct UFitRefundProofFactsContent: View {
    let proof: UFitRefundProofPresentation
    var showsStatus = true
    var body: some View {
        VStack(alignment: .leading, spacing: UFitSpace.sm) {
            if showsStatus {Text(proof.status).font(UFitTypography.subheadline.weight(.semibold))}
            UFitLabeledValue(UFitRefundProofCopy.reference, value: proof.reference)
            UFitLabeledValue(UFitRefundProofCopy.dateLabel, value: proof.date)
            if let reason = proof.decisionReason {
                VStack(alignment: .leading, spacing: UFitSpace.xs) {
                    Text(UFitRefundReviewCopy.reason).font(UFitTypography.subheadline.weight(.semibold))
                    Text(reason).font(UFitTypography.callout).textSelection(.enabled)
                }
            }
            if let reference = proof.verificationReference {UFitLabeledValue(UFitRefundReviewCopy.verification, value: reference)}
            if let reviewedAt = proof.reviewedAt {UFitLabeledValue(UFitRefundReviewCopy.reviewedAt, value: reviewedAt).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)}
        }
    }
}
