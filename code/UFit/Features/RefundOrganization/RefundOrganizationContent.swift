import SwiftUI

struct UFitRefundOrganizationContent: View {
    let document: UFitRefundOrganizationPresentation?
    let scope: UFitRefundOrganizationScope
    let isLoading: Bool
    let isSheet: Bool
    let message: String?
    let messageIsError: Bool
    let canRecoverLocal: Bool
    let sourceTitle: String?
    let providerReference: String?
    let onClose: () -> Void
    let onRefresh: () -> Void
    let onEdit: () -> Void
    let onRecoverLocal: () -> Void
    let onSource: (() -> Void)?
    var onUploadProof: (() -> Void)? = nil
    var uploadProofTitle = UFitRefundProofCopy.upload
    var onViewProof: (() -> Void)? = nil
    var isOpeningProof = false
    var onReviewProof: (() -> Void)? = nil
    var reviewProofTitle = UFitRefundReviewCopy.title
    var onHistory: (() -> Void)? = nil
    private enum Copy {static let refusal = String(localized: "Refus du moyen d’origine"), date = String(localized: "Mis à jour le"), provider = String(localized: "Référence Stripe")}
    var body: some View {
        VStack(spacing: .zero) {
            if isSheet {UFitSheetHeader(title: UFitRefundOrganizationCopy.title, onClose: onClose)}
            else {DetailHeader(title: UFitRefundOrganizationCopy.title, onBack: onClose)}
            ScrollView {
                VStack(alignment: .leading, spacing: UFitSpace.lg) {
                    if let message {UFitNotice(message: message, kind: messageIsError ? .error : .information)}
                    if let document {
                        VStack(alignment: .leading, spacing: UFitSpace.xs) {
                            Text(document.reference).font(UFitTypography.headline)
                            Text(document.context).font(UFitTypography.subheadline).foregroundStyle(Color.ufitSecondaryText)
                        }
                        Text(document.amount).font(UFitTypography.editorialTitle)
                        Text(document.status).font(UFitTypography.headline)
                        if let method = document.method, let instructions = document.instructions {
                            section(UFitRefundOrganizationCopy.method, method)
                            section(scope == .customer ? UFitRefundOrganizationCopy.clientInstructions : UFitRefundOrganizationCopy.instructions, instructions)
                            if let details = document.details {section(UFitRefundOrganizationCopy.sentDetails, details)}
                            if scope == .customer, document.details != nil, document.proof == nil {Text(UFitRefundOrganizationCopy.noPaymentYet).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)}
                        } else if scope != .administrator {Text(UFitRefundOrganizationCopy.unorganized).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)}
                        if let proof = document.proof {
                            UFitRefundProofFactsContent(proof: proof, showsStatus: false)
                            if let onViewProof {UFitActionButton(title: UFitRefundProofCopy.view, kind: onUploadProof == nil && onReviewProof == nil && document.actionTitle == nil ? .primary : .secondary, isBusy: isOpeningProof, action: onViewProof)}
                        }
                        if let onReviewProof {UFitButton(reviewProofTitle, action: onReviewProof).ufitButtonStyle(.primary).disabled(isLoading)}
                        if let onUploadProof {UFitButton(uploadProofTitle, action: onUploadProof).ufitButtonStyle(.primary).disabled(isLoading)}
                        if canRecoverLocal {UFitButton(UFitRefundOrganizationCopy.recoverLocal, action: onRecoverLocal).ufitButtonStyle(.secondary).disabled(isLoading)}
                        else if let title = document.actionTitle {UFitButton(title, action: onEdit).ufitButtonStyle(.primary).disabled(isLoading)}
                        if let onHistory {UFitButton(UFitRefundProofCopy.history, action: onHistory).ufitButtonStyle(.text)}
                        if let date = document.updatedAt {UFitLabeledValue(Copy.date, value: date).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)}
                        if let providerReference {UFitDisclosure(Copy.refusal) {UFitLabeledValue(Copy.provider, value: providerReference).font(UFitTypography.callout)}}
                        if let sourceTitle, let onSource {UFitButton(sourceTitle, action: onSource).ufitButtonStyle(.secondary).disabled(isLoading)}
                        if isLoading {UFitLoading().frame(maxWidth: .infinity)}
                    } else if isLoading {UFitLoading(UFitRefundOrganizationCopy.loading).frame(maxWidth: .infinity).padding(.vertical, UFitSpace.xl)}
                    else {UFitEmptyState(title: UFitRefundOrganizationCopy.unavailable, symbol: UFitRefundRecoveryCopy.icon)}
                    if messageIsError {UFitButton(UFitRefundOrganizationCopy.refresh, action: onRefresh).ufitButtonStyle(.secondary).disabled(isLoading)}
                }.padding(UFitSpace.page).frame(maxWidth: .infinity, alignment: .leading)
            }.ufitRefreshable(isEnabled: !isLoading, title: UFitRefundOrganizationCopy.refresh) { onRefresh() }
        }.foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
    }
    private func section(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: UFitSpace.xs) {Text(title).font(UFitTypography.subheadline.weight(.semibold)); Text(text).font(UFitTypography.callout).textSelection(.enabled)}
    }
}
struct UFitRefundOrganizationFormContent: View {
    let action: UFitRefundOrganizationAction
    let reference: String
    let amount: String
    @Binding var draft: UFitRefundOrganizationDraft
    let hasChanges: Bool
    let allowsInitialValidation: Bool
    let isSaving: Bool
    let isLoading: Bool
    let isStale: Bool
    let isUncertain: Bool
    let canRetryExact: Bool
    let replacesDetails: Bool
    let comparison: UFitRefundOrganizationPresentation?
    let errors: [UFitRefundOrganizationField: String]
    let message: String?
    let messageIsError: Bool
    let onClose: () -> Void
    let onSave: () -> Void
    let onCompare: () -> Void
    let onUseVersion: () -> Void
    let onVerify: () -> Void
    let onRetryExact: () -> Void
    @State private var confirmingClose = false
    private var locked: Bool {isSaving || isLoading || isUncertain}
    var body: some View {
        VStack(spacing: .zero) {
            UFitSheetHeader(title: isUncertain ? UFitRefundOrganizationCopy.pendingTitle : action == .arrange ? UFitRefundOrganizationCopy.arrange : UFitRefundOrganizationCopy.details, onClose: requestClose).disabled(isSaving)
            ScrollView {
                VStack(alignment: .leading, spacing: UFitSpace.lg) {
                    Text(reference).font(UFitTypography.headline)
                    Text(amount).font(UFitTypography.title2)
                    if action == .arrange {
                        if replacesDetails {UFitNotice(message: UFitRefundOrganizationCopy.changedInstructions, kind: .information)}
                        if isUncertain {
                            UFitLabeledValue(UFitRefundOrganizationCopy.method, value: draft.methodLabel)
                            pendingValue(UFitRefundOrganizationCopy.instructions, draft.instructions)
                        } else {
                            UFitTextField(label: UFitRefundOrganizationCopy.method, text: $draft.methodLabel, error: errors[.method]).disabled(locked)
                            UFitMultilineField(label: UFitRefundOrganizationCopy.instructions, text: $draft.instructions, error: errors[.instructions]).disabled(locked)
                        }
                    } else {
                        Text(UFitRefundOrganizationCopy.privacy).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
                        if isUncertain {pendingValue(UFitRefundOrganizationCopy.details, draft.details)}
                        else {UFitMultilineField(label: UFitRefundOrganizationCopy.details, text: $draft.details, error: errors[.details], isIdentifier: true).disabled(locked)}
                    }
                    if let message {UFitNotice(message: message, kind: messageIsError ? .error : .information)}
                    if isUncertain {
                        UFitButton(UFitRefundOrganizationCopy.verify, action: onVerify).ufitButtonStyle(.secondary).disabled(isSaving || isLoading)
                        if canRetryExact {UFitButton(UFitRefundOrganizationCopy.retryExact, action: onRetryExact).ufitButtonStyle(.primary).disabled(isSaving || isLoading)}
                    } else if isStale {
                        if let comparison {
                            Divider()
                            Text(UFitRefundOrganizationCopy.current).font(UFitTypography.headline)
                            if let method = comparison.method {UFitLabeledValue(UFitRefundOrganizationCopy.method, value: method)}
                            if let instructions = comparison.instructions {Text(instructions).font(UFitTypography.callout)}
                            if let details = comparison.details {UFitLabeledValue(UFitRefundOrganizationCopy.sentDetails, value: details)}
                            UFitButton(UFitRefundOrganizationCopy.useCurrentVersion, action: onUseVersion).ufitButtonStyle(.secondary).disabled(isLoading)
                        } else {UFitButton(UFitRefundOrganizationCopy.compare, action: onCompare).ufitButtonStyle(.secondary).disabled(isLoading)}
                    }
                    if isSaving || isLoading {UFitLoading(isSaving ? UFitRefundOrganizationCopy.saving : UFitRefundOrganizationCopy.loading).frame(maxWidth: .infinity)}
                }.padding(UFitSpace.page).frame(maxWidth: .infinity, alignment: .leading)
            }.scrollDismissesKeyboard(.interactively)
        }.safeAreaInset(edge: .bottom, spacing: .zero) {
            if !isUncertain {
                UFitButton(action == .arrange ? UFitRefundOrganizationCopy.saveInstructions : UFitRefundOrganizationCopy.saveReply, action: onSave)
                    .ufitButtonStyle(.primary).disabled(isSaving || isLoading || isStale || (!hasChanges && !allowsInitialValidation))
                    .padding(UFitSpace.page).background(Color.ufitCanvas).overlay(alignment: .top) {Divider()}
            }
        }.foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
            .ufitConfirmationDialog(UFitRefundOrganizationCopy.discard, isPresented: $confirmingClose) {
                UFitButton(UFitRefundOrganizationCopy.abandon, role: .destructive, action: onClose)
                UFitButton(UFitRefundOrganizationCopy.keepEditing, role: .cancel) {}
            }
    }
    private func pendingValue(_ title: String, _ value: String) -> some View {VStack(alignment: .leading, spacing: UFitSpace.xs) {Text(title).font(UFitTypography.subheadline.weight(.semibold)); Text(value).font(UFitTypography.callout).textSelection(.enabled)}}
    private func requestClose() {if hasChanges && !isUncertain {confirmingClose = true} else {onClose()}}
}
