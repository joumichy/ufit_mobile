import SwiftUI

struct UFitCreatorGradeChangeContent: View {
    @Binding var draft: UFitCreatorGradeChangeDraft
    let reference: UFitCreatorGradeAssignmentPresentation
    let errors: [UFitCreatorGradeChangeField: String]
    let hasChanges: Bool
    let canChangeGrade: Bool
    let ineligibilityMessage: String?
    let isBusy: Bool
    let isReloading: Bool
    let referenceIsStale: Bool
    let message: String?
    let messageIsError: Bool
    let onBack: () -> Void
    let onChooseGrade: () -> Void
    let onReload: () -> Void
    let onSave: () -> Void
    @State private var confirmingDiscard = false
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: CreatorGradePresentationCopy.change,
                onBack: { if hasChanges { confirmingDiscard = true } else { onBack() } }).disabled(isBusy)
            ScrollView {
                VStack(alignment: .leading, spacing: UFitSpace.xl) {
                    VStack(alignment: .leading, spacing: UFitSpace.xs) {
                        Text(reference.displayName).font(UFitTypography.title2).accessibilityAddTraits(.isHeader)
                        Text(reference.slug).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                    }
                    if let message { UFitNotice(message: message, kind: messageIsError ? .error : .information) }
                    if !canChangeGrade, let ineligibilityMessage { UFitNotice(message: ineligibilityMessage) }
                    VStack(alignment: .leading, spacing: UFitSpace.md) {
                        UFitLabeledValue(CreatorGradePresentationCopy.currentGrade, value: reference.gradeLabel)
                        UFitLabeledValue(UFitCreatorGradeAdminCopy.code, value: reference.gradeCode)
                        if referenceIsStale || messageIsError || !canChangeGrade {
                            UFitActionButton(title: CreatorGradePresentationCopy.reloadAssignment, kind: .secondary,
                                isBusy: isReloading, disabled: isBusy, action: onReload)
                        }
                    }.font(UFitTypography.subheadline)
                    VStack(alignment: .leading, spacing: UFitSpace.xs) {
                        Text(CreatorGradePresentationCopy.newGrade).font(UFitTypography.subheadline.weight(.medium))
                        UFitButton(action: onChooseGrade) {
                            HStack(alignment: .top, spacing: UFitSpace.md) {
                                VStack(alignment: .leading, spacing: UFitSpace.xs) {
                                    Text(draft.grade?.label ?? CreatorGradePresentationCopy.chooseGrade).font(UFitTypography.body)
                                    if let grade = draft.grade {
                                        Text(grade.id).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                                        UFitLabeledValue(UFitCreatorGradeAdminCopy.rank) { Text(grade.rank, format: .number) }.font(UFitTypography.caption)
                                    }
                                }.frame(maxWidth: .infinity, alignment: .leading)
                                UFitIcon(systemName: CreatorGradePresentationCopy.nextSymbol).font(UFitTypography.caption).accessibilityHidden(true)
                            }.padding(UFitSpace.md).frame(maxWidth: .infinity, minHeight: UFitControlSize.input, alignment: .leading)
                                .background(Color.ufitSecondary, in: RoundedRectangle(cornerRadius: UFitRadius.field))
                        }.disabled(!canChangeGrade || isReloading || referenceIsStale)
                            .accessibilityLabel(CreatorGradePresentationCopy.newGrade)
                            .accessibilityValue(draft.grade?.label ?? CreatorGradePresentationCopy.chooseGrade)
                        if let error = errors[.grade] { UFitFieldError(message: error) }
                    }
                    UFitMultilineField(label: UFitCreatorGradeAdminCopy.reason, text: $draft.reason, error: errors[.reason])
                    Text(CreatorGradePresentationCopy.changeConsequence).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
                }.padding(UFitSpace.page).frame(maxWidth: .infinity, alignment: .leading).disabled(isBusy)
            }.scrollDismissesKeyboard(.interactively)
        }.safeAreaInset(edge: .bottom, spacing: .zero) {
            UFitActionButton(title: CreatorGradePresentationCopy.confirmChange, isBusy: isBusy,
                disabled: !hasChanges || !canChangeGrade || isReloading || referenceIsStale, action: onSave)
                .padding(UFitSpace.md).background(Color.ufitCanvas)
                .overlay(alignment: .top) { Rectangle().fill(Color.ufitBorder).frame(height: UFitSpace.hairline) }
        }.ufitButtonStyle(.text).foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
            .ufitConfirmationDialog(UFitCreatorGradeAdminCopy.discardTitle, isPresented: $confirmingDiscard) {
                UFitButton(UFitCreatorGradeAdminCopy.discard, role: .destructive, action: onBack)
                UFitButton(UFitCreatorGradeAdminCopy.keepEditing, role: .cancel) {}
            }
    }
}
