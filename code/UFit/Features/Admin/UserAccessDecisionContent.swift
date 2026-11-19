import SwiftUI

struct UFitUserAccessDecisionContent: View {
    let user: UFitAdministeredUserRow
    let decision: UFitUserAccessDecision
    @Binding var reason: String
    let reasonError: String?
    let message: String?
    let messageIsError: Bool
    let isBusy: Bool
    let isReloading: Bool
    let canDecide: Bool
    let hasChanges: Bool
    let onBack: () -> Void
    let onSave: () -> Void
    let onReload: () -> Void
    @State private var confirmingDiscard = false
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: decision.label, onBack: {
                if hasChanges { confirmingDiscard = true } else { onBack() }
            }).disabled(isBusy)
            ScrollView {
                VStack(alignment: .leading, spacing: UFitSpace.xl) {
                    VStack(alignment: .leading, spacing: UFitSpace.xs) {
                        Text(user.name).font(UFitTypography.title2).accessibilityAddTraits(.isHeader)
                        if user.hasDistinctName { Text(user.email).foregroundStyle(Color.ufitSecondaryText) }
                        Text(user.status.label).font(UFitTypography.caption)
                    }
                    Text(decision.consequence).font(UFitTypography.callout)
                    if let message { UFitNotice(message: message, kind: messageIsError ? .error : .information) }
                    if messageIsError || !canDecide {
                        UFitButton(UFitUserAdministrationCopy.reloadReference, action: onReload).ufitButtonStyle(.secondary).disabled(isBusy || isReloading)
                    }
                    if isReloading { UFitLoading() }
                    UFitMultilineField(label: UFitUserAdministrationCopy.reason, text: $reason, error: reasonError).disabled(isBusy)
                }.padding(UFitSpace.page).frame(maxWidth: .infinity, alignment: .leading)
            }.scrollDismissesKeyboard(.interactively)
        }.safeAreaInset(edge: .bottom, spacing: .zero) {
            UFitActionButton(title: decision.label, kind: decision.isDestructive ? .destructive : .primary,
                isBusy: isBusy, disabled: !canDecide || isReloading, action: onSave)
                .padding(UFitSpace.md).background(Color.ufitCanvas)
                .overlay(alignment: .top) { Rectangle().fill(Color.ufitBorder).frame(height: UFitSpace.hairline) }
        }.ufitButtonStyle(.text).foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
            .ufitConfirmationDialog(UFitUserAdministrationCopy.discardTitle, isPresented: $confirmingDiscard) {
                UFitButton(UFitUserAdministrationCopy.discard, role: .destructive, action: onBack)
                UFitButton(UFitUserAdministrationCopy.keepEditing, role: .cancel) {}
            }
    }
}
