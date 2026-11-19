import SwiftUI

struct UFitCreatorGradeFormContent: View {
    @Binding var draft: UFitCreatorGradeDraft
    let reference: UFitCreatorGradeRow?
    let errors: [UFitCreatorGradeField: String]
    let hasChanges: Bool
    let isBusy: Bool
    let isReloading: Bool
    let referenceIsStale: Bool
    let message: String?
    let messageIsError: Bool
    let onBack: () -> Void
    let onSave: () -> Void
    let onReload: () -> Void
    @State private var confirmingDiscard = false
    private var isNew: Bool { reference == nil }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: isNew ? UFitCreatorGradeAdminCopy.create : UFitCreatorGradeAdminCopy.edit,
                onBack: { if hasChanges { confirmingDiscard = true } else { onBack() } }).disabled(isBusy)
            ScrollView {
                VStack(alignment: .leading, spacing: UFitSpace.xl) {
                    if let message { UFitNotice(message: message, kind: messageIsError ? .error : .information) }
                    if let reference {
                        VStack(alignment: .leading, spacing: UFitSpace.md) {
                            UFitLabeledValue(UFitCreatorGradeAdminCopy.code, value: reference.id)
                            Text(CreatorGradePresentationCopy.readOnlyCode).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                            UFitDisclosure(CreatorGradePresentationCopy.currentDefinition) {
                                VStack(alignment: .leading, spacing: UFitSpace.sm) {
                                    Text(reference.label).font(UFitTypography.headline)
                                    UFitLabeledValue(CreatorGradePresentationCopy.version) { Text(reference.version, format: .number) }
                                    UFitLabeledValue(UFitCreatorGradeAdminCopy.rank) { Text(reference.rank, format: .number) }
                                    Text(reference.assignable ? UFitCreatorGradeAdminCopy.assignable : UFitCreatorGradeAdminCopy.unavailable)
                                }
                            }
                            if let error = errors[.code] { UFitFieldError(message: error) }
                            if referenceIsStale || messageIsError {
                                UFitActionButton(title: CreatorGradePresentationCopy.reload, kind: .secondary,
                                    isBusy: isReloading, disabled: isBusy, action: onReload)
                            }
                        }.font(UFitTypography.subheadline)
                    } else {
                        VStack(alignment: .leading, spacing: UFitSpace.xs) {
                            UFitTextField(label: UFitCreatorGradeAdminCopy.code, text: $draft.code, error: errors[.code], isIdentifier: true)
                            Text(CreatorGradePresentationCopy.codeHint).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                        }
                    }
                    UFitTextField(label: UFitCreatorGradeAdminCopy.label, text: $draft.label, error: errors[.label])
                    VStack(alignment: .leading, spacing: UFitSpace.xs) {
                        UFitTextField(label: UFitCreatorGradeAdminCopy.rank, text: $draft.rank, error: errors[.rank], keyboard: .numberPad)
                        Text(CreatorGradePresentationCopy.rankHint).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                    }
                    VStack(alignment: .leading, spacing: UFitSpace.xs) {
                        UFitToggle(UFitCreatorGradeAdminCopy.activation, isOn: $draft.assignable).disabled(reference?.isInitial == true)
                        Text(reference?.isInitial == true ? UFitCreatorGradeAdminCopy.initialExplanation : UFitCreatorGradeAdminCopy.existingAssignments)
                            .font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                    }
                    UFitMultilineField(label: UFitCreatorGradeAdminCopy.reason, text: $draft.reason, error: errors[.reason])
                    if !isNew { Text(CreatorGradePresentationCopy.definitionConsequence).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText) }
                }.padding(UFitSpace.page).frame(maxWidth: .infinity, alignment: .leading).disabled(isBusy)
            }.scrollDismissesKeyboard(.interactively)
        }.safeAreaInset(edge: .bottom, spacing: .zero) {
            UFitActionButton(title: isNew ? UFitCreatorGradeAdminCopy.save : UFitCreatorGradeAdminCopy.revise,
                isBusy: isBusy, disabled: !hasChanges || isReloading || referenceIsStale, action: onSave)
                .padding(UFitSpace.md).background(Color.ufitCanvas)
                .overlay(alignment: .top) { Rectangle().fill(Color.ufitBorder).frame(height: UFitSpace.hairline) }
        }.ufitButtonStyle(.text).foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
            .ufitConfirmationDialog(UFitCreatorGradeAdminCopy.discardTitle, isPresented: $confirmingDiscard) {
                UFitButton(UFitCreatorGradeAdminCopy.discard, role: .destructive, action: onBack)
                UFitButton(UFitCreatorGradeAdminCopy.keepEditing, role: .cancel) {}
            }
    }
}
