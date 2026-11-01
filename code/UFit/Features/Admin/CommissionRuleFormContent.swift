import SwiftUI

struct UFitCommissionRuleFormContent: View {
    @Binding var draft: UFitCommissionRuleDraft
    let errors: [UFitCommissionRuleField: String]
    let isNew: Bool
    let isBusy: Bool
    let isReloading: Bool
    let referenceRevision: Int?
    let hasChanges: Bool
    let message: String?
    let onBack: () -> Void
    let onSave: () -> Void
    let onReload: () -> Void
    let onChoose: (UFitCommissionReferenceKind) -> Void
    @State private var confirmingDiscard = false
    private enum Layout { static let page: CGFloat = UFitSpace.xl; static let gap: CGFloat = UFitSpace.md; static let small: CGFloat = UFitSpace.xs; static let touch: CGFloat = UFitControlSize.touch }
    private enum Icon { static let next = "chevron.right" }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: isNew ? UFitCommissionAdminCopy.create : UFitCommissionAdminCopy.edit,
                onBack: { if hasChanges { confirmingDiscard = true } else { onBack() } }).disabled(isBusy)
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.page) {
                    if let message { Text(message).font(UFitTypography.callout) }
                    VStack(alignment: .leading, spacing: Layout.gap) {
                        Text(UFitCommissionAdminCopy.scope).font(UFitTypography.title2)
                        ForEach(UFitCommissionReferenceKind.allCases) { kind in
                            if isNew {
                                UFitButton { onChoose(kind) } label: { scopeLabel(kind) }
                                    .disabled(kind == .product && draft.brand == nil).accessibilityLabel(kind.title)
                                    .accessibilityValue(reference(kind)?.title ?? kind.unselectedTitle)
                            } else { scopeLabel(kind).accessibilityElement(children: .combine) }
                            Divider()
                        }
                        if let error = errors[.brand] { UFitFieldError(message: error) }
                        if isNew && draft.brand == nil { Text(FormCopy.chooseBrand).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText) }
                        if let referenceRevision {
                            HStack { Text(UFitCommissionAdminCopy.current); Spacer(); Text(referenceRevision, format: .number) }.font(UFitTypography.subheadline)
                        }
                        if !isNew {
                            UFitButton(action: onReload) {
                                if isReloading { UFitLoading() } else { Text(UFitCommissionAdminCopy.reloadReference) }
                            }.frame(minHeight: Layout.touch).environment(\.ufitButtonIsBusy, isReloading).disabled(isBusy || isReloading)
                        }
                    }
                    VStack(alignment: .leading, spacing: Layout.gap) {
                        Text(UFitCommissionAdminCopy.rates).font(UFitTypography.title2)
                        UFitTextField(label: UFitCommissionAdminCopy.baseRate, text: $draft.baseRate, error: errors[.baseRate], keyboard: .decimalPad)
                        UFitTextField(label: UFitCommissionAdminCopy.bonusRate, text: $draft.bonusRate, error: errors[.bonusRate], keyboard: .decimalPad)
                        UFitTextField(label: UFitCommissionAdminCopy.maximumRate, text: $draft.maximumRate, error: errors[.maximumRate], keyboard: .decimalPad)
                        Text(UFitCommissionAdminCopy.rateFormula).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                        UFitToggle(UFitCommissionAdminCopy.activation, isOn: $draft.active).frame(minHeight: Layout.touch)
                    }
                    UFitMultilineField(label: UFitCommissionAdminCopy.reason, text: $draft.reason, error: errors[.reason])
                }.padding(Layout.page).disabled(isBusy)
            }.scrollDismissesKeyboard(.interactively)
        }.safeAreaInset(edge: .bottom, spacing: .zero) {
            VStack(alignment: .leading, spacing: UFitSpace.xs) {
                Text(UFitCommissionAdminCopy.futurePurchases).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                UFitActionButton(title: isNew ? UFitCommissionAdminCopy.save : UFitCommissionAdminCopy.revise, isBusy: isBusy, disabled: !hasChanges || isReloading, action: onSave)
            }.padding(UFitSpace.md).background(Color.ufitCanvas).overlay(alignment: .top) { Rectangle().fill(Color.ufitBorder).frame(height: UFitSpace.hairline) }
        }.ufitButtonStyle(.text).foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.ufitCanvas)
            .ufitConfirmationDialog(UFitCommissionAdminCopy.discardTitle, isPresented: $confirmingDiscard, titleVisibility: .visible) {
                UFitButton(UFitCommissionAdminCopy.discard, role: .destructive, action: onBack)
                UFitButton(UFitCommissionAdminCopy.keepEditing, role: .cancel) {}
            }
    }
    private func reference(_ kind: UFitCommissionReferenceKind) -> UFitCommissionReference? {
        switch kind { case .brand: draft.brand; case .product: draft.product; case .grade: draft.grade }
    }
    private func scopeLabel(_ kind: UFitCommissionReferenceKind) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Layout.small) {
                Text(kind.title).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                Text(reference(kind)?.title ?? kind.unselectedTitle)
            }
            Spacer()
            if isNew { UFitIcon(systemName: Icon.next).font(UFitTypography.caption) }
        }.frame(maxWidth: .infinity, minHeight: Layout.touch, alignment: .leading)
    }
}

private enum FormCopy { static let chooseBrand = String(localized: "Choisissez une marque pour cibler un article.") }
