import SwiftUI

struct UFitRefundOrganizationHost: View {
    @Bindable var store: UFitRefundOrganizationStore
    @State private var proofUpload: UFitRefundProofUploadStore?
    let onClose: () -> Void
    var isSheet = true
    var sourceTitle: String?
    var providerReference: String?
    var onSource: (() -> Void)?
    var body: some View {
        Group {
            if store.isEditing, let action = store.action {
                UFitRefundOrganizationFormContent(action: action, reference: store.document?.summary.orderNumber ?? String(), amount: store.document.map {UFitMoney.format($0.summary.amount, currency: $0.summary.currency)} ?? String(), draft: Binding(get: {store.pending?.draft ?? store.draft}, set: {if !store.isSaving && !store.isUncertain {store.draft = $0}}),
                    hasChanges: store.hasChanges, allowsInitialValidation: store.document?.organization == nil || (action == .provideDetails && store.document?.organization?.customerDetails == nil), isSaving: store.isSaving, isLoading: store.isLoading, isStale: store.isStale, isUncertain: store.isUncertain,
                    canRetryExact: store.canRetryExact, replacesDetails: store.document?.organization?.customerDetails != nil, comparison: store.comparison?.presentation(scope: store.scope), errors: store.errors, message: store.message, messageIsError: store.messageIsError,
                    onClose: {if store.isUncertain {onClose()} else {store.cancelEdit()}}, onSave: {Task {await store.save()}}, onCompare: {Task {await store.load()}}, onUseVersion: store.useComparedVersion,
                    onVerify: {Task {await store.verifyPending()}}, onRetryExact: {Task {await store.sendPending()}})
            } else {
                UFitRefundOrganizationContent(document: store.document?.presentation(scope: store.scope), scope: store.scope, isLoading: store.isLoading, isSheet: isSheet,
                    message: store.message, messageIsError: store.messageIsError, canRecoverLocal: store.localRecordFailed, sourceTitle: sourceTitle, providerReference: providerReference, onClose: onClose,
                    onRefresh: {Task {await store.load()}}, onEdit: store.edit, onRecoverLocal: {Task {await store.recoverLocalRecord()}}, onSource: onSource,
                    onUploadProof: canUploadProof ? showProofUpload : nil, uploadProofTitle: store.hasProofRequest ? UFitRefundProofCopy.resume : UFitRefundProofCopy.upload, onViewProof: store.document?.proof == nil ? nil : {Task {await store.openProof()}}, isOpeningProof: store.isOpeningProof)
            }
        }.interactiveDismissDisabled(store.isSaving || store.hasChanges)
            .task {await store.load()}.onDisappear {store.cancelLoading(); store.clearProofPreview()}
            .ufitSheet(item: $proofUpload, onDismiss: {Task {await store.load()}}) {current in
                UFitRefundProofUploadContent(store: current, onClose: {proofUpload = nil})
            }.ufitDocumentPreview($store.previewURL)
            .onChange(of: store.previewURL) {_, url in if url == nil {store.clearProofPreview()}}
    }
    private var canUploadProof: Bool {store.scope == .brand && (store.hasProofRequest || (store.document?.organization?.status == .ready && store.document?.proof == nil))}
    private func showProofUpload() {
        guard store.isCurrentAccount, canUploadProof, let document = store.document, let actorID = store.session.user?.id else {return}
        proofUpload = .init(document: document, session: store.session, actorID: actorID)
    }
}
extension UFitReturnScope {
    var refundOrganizationScope: UFitRefundOrganizationScope {switch self {case .administrator: .administrator; case .customer: .customer; case .brand: .brand}}
}
extension UFitOrderCancellationDTO {
    var refundOrganizationReference: UFitRefundRecoveryReference? {
        guard refund?.providerStatus != .cancelled, refund?.state == .failed || refund?.state == .blocked else {return nil}
        return .init(kind: .cancellation, id: id)
    }
}
