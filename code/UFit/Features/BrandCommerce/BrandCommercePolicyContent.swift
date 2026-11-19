import SwiftUI

struct UFitBrandCommercePolicyContent: View {
    let brandName: String
    @Binding var draft: UFitBrandCommerceDraft
    let countries: [UFitCountry]
    let currencies: [UFitCurrency]
    let hasChanges: Bool
    let isLoading: Bool
    let isSaving: Bool
    let errors: [UFitBrandCommerceField: String]
    let message: String?
    let onBack: () -> Void
    let onReload: () -> Void
    let onSave: () -> Void
    @State private var editingRate: UFitBrandShippingRateDraft?
    @State private var leaving: LeavingAction?
    private enum LeavingAction: Equatable { case back, reload }
    private enum Copy {
        static let title = String(localized: "Conditions de vente"); static let reload = String(localized: "Actualiser les conditions")
        static let returns = String(localized: "Retours"); static let days = String(localized: "Délai de retour (jours)")
        static let returnPolicy = String(localized: "Conditions de retour"); static let taxes = String(localized: "Fiscalité")
        static let includeTaxes = String(localized: "Les prix incluent les taxes")
        static let taxNotice = String(localized: "Informations fiscales"); static let customs = String(localized: "Informations douanières")
        static let destinations = String(localized: "Pays de livraison et tarifs"); static let add = String(localized: "Ajouter une destination")
        static let empty = String(localized: "Aucune destination configurée."); static let incomplete = String(localized: "Tarif à compléter")
        static let remove = String(localized: "Retirer cette destination"); static let issue = String(localized: "Vérifiez ce tarif.")
        static let save = String(localized: "Enregistrer les conditions"); static let saving = String(localized: "Enregistrement des conditions")
        static let discardTitle = String(localized: "Abandonner les modifications ?")
        static let reloadTitle = String(localized: "Actualiser et abandonner les modifications ?")
        static let discard = String(localized: "Abandonner"); static let reloadDiscard = String(localized: "Actualiser et abandonner")
        static let keep = String(localized: "Continuer la saisie")
    }
    private enum Layout {
        static let page: CGFloat = UFitSpace.xl; static let gap: CGFloat = UFitSpace.md; static let small: CGFloat = UFitSpace.xs; static let touch: CGFloat = UFitControlSize.touch; static let title: CGFloat = UFitTypography.Size.editorial
        static let disabledOpacity = 0.4; static let enabledOpacity = 1.0
    }
    private enum Icon { static let chevron = "chevron.right" }
    private var locked: Bool { isLoading || isSaving }
    @ViewBuilder
    var body: some View {
        if let rate = editingRate {
            UFitBrandShippingRateContent(rate: rate, isNew: !draft.rates.contains(where: { $0.id == rate.id }), pricesIncludeTaxes: draft.pricesIncludeTaxes,
                countries: countries, currencies: currencies, otherRates: draft.rates, onClose: { editingRate = nil }, onSave: { value in
                    if let index = draft.rates.firstIndex(where: { $0.id == value.id }) { draft.rates[index] = value }
                    else { draft.rates.append(value) }
                    editingRate = nil
                })
        } else {
            policy
        }
    }
    private var policy: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: Copy.title, onBack: { requestLeaving(.back) }) {
                if isLoading { UFitLoading().frame(width: Layout.touch, height: Layout.touch) }
            }.disabled(isSaving)
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.page) {
                    Text(brandName).ufitFont(size: Layout.title, design: .serif)
                    VStack(alignment: .leading, spacing: Layout.gap) {
                        Text(Copy.returns).font(UFitTypography.title2.weight(.medium))
                        UFitTextField(label: Copy.days, text: $draft.returnWindowDays, error: errors[.returnWindowDays], keyboard: .numberPad)
                        UFitMultilineField(label: Copy.returnPolicy, text: $draft.returnPolicy, error: errors[.returnPolicy])
                    }
                    VStack(alignment: .leading, spacing: Layout.gap) {
                        Text(Copy.taxes).font(UFitTypography.title2.weight(.medium))
                        UFitPolicyBooleanField(label: Copy.includeTaxes, value: $draft.pricesIncludeTaxes, error: errors[.pricesIncludeTaxes])
                        UFitMultilineField(label: Copy.taxNotice, text: $draft.taxNotice, error: errors[.taxNotice])
                        UFitMultilineField(label: Copy.customs, text: $draft.customsNotice, error: errors[.customsNotice])
                    }
                    VStack(alignment: .leading, spacing: Layout.gap) {
                        Text(Copy.destinations).font(UFitTypography.title2.weight(.medium))
                        if draft.rates.isEmpty { Text(Copy.empty).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText) }
                        ForEach(draft.rates) { rate in
                            VStack(alignment: .leading, spacing: Layout.small) {
                                UFitButton { editingRate = rate } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: Layout.small) {
                                            Text(countries.first(where: { $0.id == rate.country })?.name ?? rate.country).font(UFitTypography.headline)
                                            Text(rate.currency.isEmpty || rate.amount.isEmpty ? Copy.incomplete : rate.currency + UFitBrandCommerceInput.space + rate.amount).font(UFitTypography.subheadline)
                                        }
                                        Spacer(); UFitIcon(systemName: Icon.chevron)
                                    }.frame(minHeight: Layout.touch).contentShape(Rectangle())
                                }.ufitButtonStyle(.text)
                                if errors[.destinations] != nil && !rateErrors(rate).isEmpty { Text(Copy.issue).font(UFitTypography.caption) }
                                UFitButton(Copy.remove, role: .destructive) { draft.rates.removeAll { $0.id == rate.id } }
                                    .ufitButtonStyle(.secondary, compact: true)
                                Divider()
                            }
                        }
                        if let error = errors[.destinations] { UFitFieldError(message: error) }
                        UFitActionButton(title: Copy.add, kind: .secondary, action: { editingRate = UFitBrandShippingRateDraft() })
                    }
                }.padding(Layout.page).frame(maxWidth: .infinity, alignment: .leading).disabled(locked)
            }.scrollDismissesKeyboard(.interactively)
                .ufitRefreshable(isEnabled: !locked, title: Copy.reload) { requestLeaving(.reload) }
        }.safeAreaInset(edge: .bottom, spacing: .zero) {
            VStack(alignment: .leading, spacing: Layout.small) {
                if let message { Text(message).font(UFitTypography.callout) }
                if isSaving { UFitLoading(Copy.saving).frame(maxWidth: .infinity, minHeight: Layout.touch) }
                else {
                    UFitButton(action: onSave) { Text(Copy.save).frame(maxWidth: .infinity) }.ufitButtonStyle(.primary).disabled(!hasChanges || isLoading)
                        .opacity(!hasChanges || isLoading ? Layout.disabledOpacity : Layout.enabledOpacity)
                }
            }.padding(Layout.gap).background(Color.ufitCanvas).overlay(alignment: .top) { Divider() }
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.ufitCanvas)
            .ufitConfirmationDialog(leaving == .reload ? Copy.reloadTitle : Copy.discardTitle,
                isPresented: Binding(get: { leaving != nil }, set: { if !$0 { leaving = nil } }), titleVisibility: .visible, presenting: leaving) { action in
                    UFitButton(action == .reload ? Copy.reloadDiscard : Copy.discard, role: .destructive) {
                        if action == .reload { onReload() } else { onBack() }; leaving = nil
                    }
                    UFitButton(Copy.keep, role: .cancel) { leaving = nil }
                }
    }
    private func requestLeaving(_ action: LeavingAction) {
        if hasChanges { leaving = action }
        else if action == .reload { onReload() }
        else { onBack() }
    }
    private func rateErrors(_ value: UFitBrandShippingRateDraft) -> [UFitBrandShippingRateField: String] {
        UFitBrandCommerceValidation.rate(value, pricesIncludeTaxes: draft.pricesIncludeTaxes, countries: countries, currencies: currencies, others: draft.rates)
    }

}
struct UFitPolicyBooleanField: View {
    let label: String
    @Binding var value: Bool?
    let error: String?
    private enum Copy {
        static let choose = String(localized: "Choisir")
        static let yes = String(localized: "Oui")
        static let no = String(localized: "Non")
        static let clear = String(localized: "Effacer ce choix")
        static let separator = " · "
    }
    private enum Icon { static let clear = "xmark.circle" }
    private enum Layout { static let gap: CGFloat = UFitSpace.xs; static let touch: CGFloat = UFitControlSize.touch }
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.gap) {
            HStack(spacing: UFitSpace.sm) {
                Text(label).font(UFitTypography.subheadline.weight(.medium))
                Spacer(minLength: UFitSpace.xs)
                if value != nil {
                    UFitButton { value = nil } label: { UFitIcon(systemName: Icon.clear).font(UFitTypography.callout) }
                        .ufitButtonStyle(.text).accessibilityLabel(Copy.clear + Copy.separator + label)
                }
            }
            UFitInlineChoice(title: label, selection: $value,
                options: [.init(value: Optional(true), title: Copy.yes), .init(value: Optional(false), title: Copy.no)])
                .accessibilityValue(value.map { $0 ? Copy.yes : Copy.no } ?? Copy.choose)
            if let error { UFitFieldError(message: error) }
        }
    }
}

struct UFitBrandCommercePreparationContent: View {
    let isLoading: Bool
    let message: String?
    let onBack: () -> Void
    let onRetry: () -> Void
    private enum Copy { static let title = String(localized: "Conditions de vente"); static let loading = String(localized: "Chargement des conditions"); static let retry = String(localized: "Réessayer") }
    private enum Layout { static let page: CGFloat = UFitSpace.xl; static let gap: CGFloat = UFitSpace.md; static let touch: CGFloat = UFitControlSize.touch }
    var body: some View {
        VStack(spacing: Layout.gap) {
            DetailHeader(title: Copy.title, onBack: onBack)
            if isLoading { UFitLoading(Copy.loading) }
            if let message { Text(message).font(UFitTypography.callout).padding(.horizontal, Layout.page) }
            if !isLoading { UFitActionButton(title: Copy.retry, kind: .secondary, action: onRetry) }
            Spacer()
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.ufitCanvas)
    }
}
