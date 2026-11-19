import SwiftUI

struct UFitCommissionRuleFormContent: View {
    @Binding var draft: UFitCommissionRuleDraft
    let errors: [UFitCommissionRuleField: String]
    let isNew: Bool
    let isBusy: Bool
    let isReloading: Bool
    let reference: UFitCommissionRuleDocument?
    let referenceIsStale: Bool
    let messageIsError: Bool
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
                    if let message { UFitNotice(message: message, kind: messageIsError ? .error : .information) }
                    VStack(alignment: .leading, spacing: Layout.gap) {
                        if isNew {
                            Text(UFitCommissionAdminCopy.scope).font(UFitTypography.title2)
                            ForEach(UFitCommissionReferenceKind.allCases) { kind in
                                UFitButton { onChoose(kind) } label: { scopeLabel(kind) }
                                    .disabled(kind == .product && draft.brand == nil).accessibilityLabel(kind.title)
                                    .accessibilityValue(reference(kind)?.title ?? kind.unselectedTitle)
                                Divider()
                            }
                            if let error = errors[.brand] { UFitFieldError(message: error) }
                            if draft.brand == nil { Text(FormCopy.chooseBrand).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText) }
                        } else if let reference {
                            Text(reference.rule.brand).font(UFitTypography.title2).accessibilityAddTraits(.isHeader)
                            UFitLabeledValue(UFitCommissionAdminCopy.product, value: reference.rule.product ?? UFitCommissionAdminCopy.allProducts)
                                .font(UFitTypography.subheadline)
                            UFitLabeledValue(UFitCommissionAdminCopy.grade, value: reference.rule.grade ?? UFitCommissionAdminCopy.allGrades)
                                .font(UFitTypography.subheadline)
                        }
                        if let reference {
                            UFitDisclosure(UFitCommissionAdminCopy.currentValues) {
                                VStack(spacing: Layout.gap) {
                                    UFitLabeledValue(UFitCommissionAdminCopy.current) { Text(reference.rule.revision, format: .number) }
                                    UFitLabeledValue(UFitCommissionAdminCopy.baseRate, value: reference.baseRate)
                                    UFitLabeledValue(UFitCommissionAdminCopy.bonusRate, value: reference.bonusRate)
                                    UFitLabeledValue(UFitCommissionAdminCopy.maximumRate, value: reference.maximumRate ?? UFitCommissionAdminCopy.noMaximum)
                                    Text(reference.rule.active ? UFitCommissionAdminCopy.active : UFitCommissionAdminCopy.inactive)
                                }.font(UFitTypography.subheadline)
                            }
                            if referenceIsStale || messageIsError {
                                UFitActionButton(title: UFitCommissionAdminCopy.reloadReference, kind: .secondary,
                                    isBusy: isReloading, disabled: isBusy, action: onReload)
                            }
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
                    Text(UFitCommissionAdminCopy.futurePurchases).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                }.padding(Layout.page).disabled(isBusy)
            }.scrollDismissesKeyboard(.interactively)
        }.safeAreaInset(edge: .bottom, spacing: .zero) {
            UFitActionButton(title: isNew ? UFitCommissionAdminCopy.save : UFitCommissionAdminCopy.revise,
                isBusy: isBusy, disabled: !hasChanges || isReloading || referenceIsStale, action: onSave)
                .padding(UFitSpace.md).background(Color.ufitCanvas)
                .overlay(alignment: .top) { Rectangle().fill(Color.ufitBorder).frame(height: UFitSpace.hairline) }
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
