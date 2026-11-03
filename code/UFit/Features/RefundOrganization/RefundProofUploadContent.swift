import SwiftUI

struct UFitRefundProofUploadContent: View {
    @Bindable var store: UFitRefundProofUploadStore
    let onClose: () -> Void
    @State private var importing = false
    @State private var confirmingClose = false
    private var locked: Bool {store.isBusy || store.pending != nil || store.localFailed}
    var body: some View {
        VStack(spacing: .zero) {
            UFitSheetHeader(title: store.pending == nil ? UFitRefundProofCopy.title : UFitRefundOrganizationCopy.pendingTitle, onClose: requestClose).disabled(store.isBusy)
            ScrollView {
                VStack(alignment: .leading, spacing: UFitSpace.lg) {
                    Text(store.amount).font(UFitTypography.editorialTitle)
                    if let file = store.file {
                        UFitLabeledValue(UFitRefundProofCopy.title, value: file.name)
                        if store.pending == nil {UFitButton(UFitRefundProofCopy.replace) {importing = true}.ufitButtonStyle(.secondary).disabled(locked)}
                    } else {UFitButton(UFitRefundProofCopy.choose) {importing = true}.ufitButtonStyle(.secondary).disabled(locked)}
                    if let error = store.fileError {UFitFieldError(message: error)}
                    if store.pending != nil {
                        UFitLabeledValue(UFitRefundProofCopy.reference, value: store.transferReference)
                        UFitLabeledValue(UFitRefundProofCopy.date, value: store.transferredOn)
                    } else {
                        UFitTextField(label: UFitRefundProofCopy.reference, text: $store.transferReference, error: store.referenceError, isIdentifier: true).disabled(locked)
                        UFitTextField(label: UFitRefundProofCopy.date, text: $store.transferredOn, error: store.dateError, isIdentifier: true).disabled(locked)
                    }
                    Text(UFitRefundProofCopy.sharing).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
                    if let message = store.message {UFitNotice(message: message, kind: .information)}
                    if store.localFailed {UFitButton(UFitRefundOrganizationCopy.recoverLocal) {Task {await store.compare()}}.ufitButtonStyle(.secondary).disabled(store.isBusy)}
                    else if store.pending != nil {
                        UFitButton(UFitRefundOrganizationCopy.verify) {Task {await store.verify()}}.ufitButtonStyle(.secondary).disabled(store.isBusy)
                        if store.canRetry {UFitButton(UFitRefundOrganizationCopy.retryExact) {Task {await store.send()}}.ufitButtonStyle(.primary).disabled(store.isBusy)}
                    } else if store.isStale {
                        if let comparison = store.comparison?.presentation(scope: .brand) {
                            Divider(); Text(UFitRefundOrganizationCopy.current).font(UFitTypography.headline)
                            Text(comparison.status).font(UFitTypography.callout)
                            if let details = comparison.details {UFitLabeledValue(UFitRefundOrganizationCopy.sentDetails, value: details)}
                            UFitButton(UFitRefundOrganizationCopy.useCurrentVersion, action: store.useVersion).ufitButtonStyle(.secondary).disabled(store.isBusy || !store.canUseVersion)
                        } else {UFitButton(UFitRefundOrganizationCopy.compare) {Task {await store.compare()}}.ufitButtonStyle(.secondary).disabled(store.isBusy)}
                    }
                    if store.isBusy {UFitLoading(UFitRefundOrganizationCopy.saving).frame(maxWidth: .infinity)}
                }.padding(UFitSpace.page).frame(maxWidth: .infinity, alignment: .leading)
            }.scrollDismissesKeyboard(.interactively)
        }.safeAreaInset(edge: .bottom, spacing: .zero) {
            if store.pending == nil, !store.localFailed {
                UFitButton(UFitRefundProofCopy.submit) {Task {await store.save()}}.ufitButtonStyle(.primary).disabled(store.isBusy || store.isStale)
                    .padding(UFitSpace.page).background(Color.ufitCanvas).overlay(alignment: .top) {Divider()}
            }
        }.foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
            .ufitDocumentImporter(isPresented: $importing, onResult: store.select)
            .interactiveDismissDisabled(store.isBusy || store.hasChanges)
            .ufitConfirmationDialog(UFitRefundOrganizationCopy.discard, isPresented: $confirmingClose) {
                UFitButton(UFitRefundOrganizationCopy.abandon, role: .destructive, action: onClose)
                UFitButton(UFitRefundOrganizationCopy.keepEditing, role: .cancel) {}
            }.task {await store.load()}.onDisappear {store.cancelLoading()}
            .onChange(of: store.isComplete) {_, complete in if complete {onClose()}}
    }
    private func requestClose() {if store.hasChanges && store.pending == nil {confirmingClose = true} else {onClose()}}
}
