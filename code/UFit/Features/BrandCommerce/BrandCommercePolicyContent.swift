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
        static let page: CGFloat = 24; static let gap: CGFloat = 16; static let small: CGFloat = 8; static let touch: CGFloat = 44; static let title: CGFloat = 30
        static let disabledOpacity = 0.4; static let enabledOpacity = 1.0
    }
    private enum Icon { static let reload = "arrow.clockwise"; static let chevron = "chevron.right" }
    private var locked: Bool { isLoading || isSaving }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: Copy.title, onBack: { requestLeaving(.back) }) {
                if isLoading { ProgressView().frame(width: Layout.touch, height: Layout.touch) }
                else { Button { requestLeaving(.reload) } label: { Image(systemName: Icon.reload).frame(width: Layout.touch, height: Layout.touch) }.accessibilityLabel(Copy.reload) }
            }.disabled(isSaving)
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.page) {
                    Text(brandName).font(.system(size: Layout.title, design: .serif))
                    VStack(alignment: .leading, spacing: Layout.gap) {
                        Text(Copy.returns).font(.title2.weight(.medium))
                        UFitTextField(label: Copy.days, text: $draft.returnWindowDays, error: errors[.returnWindowDays], keyboard: .numberPad)
                        PolicyText(label: Copy.returnPolicy, text: $draft.returnPolicy, error: errors[.returnPolicy])
                    }
                    VStack(alignment: .leading, spacing: Layout.gap) {
                        Text(Copy.taxes).font(.title2.weight(.medium))
                        UFitPolicyBooleanField(label: Copy.includeTaxes, value: $draft.pricesIncludeTaxes, error: errors[.pricesIncludeTaxes])
                        PolicyText(label: Copy.taxNotice, text: $draft.taxNotice, error: errors[.taxNotice])
                        PolicyText(label: Copy.customs, text: $draft.customsNotice, error: errors[.customsNotice])
                    }
                    VStack(alignment: .leading, spacing: Layout.gap) {
                        Text(Copy.destinations).font(.title2.weight(.medium))
                        if draft.rates.isEmpty { Text(Copy.empty).font(.callout).foregroundStyle(Color.ufitMuted) }
                        ForEach(draft.rates) { rate in
                            VStack(alignment: .leading, spacing: Layout.small) {
                                Button { editingRate = rate } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: Layout.small) {
                                            Text(countries.first(where: { $0.id == rate.country })?.name ?? rate.country).font(.headline)
                                            Text(rate.currency.isEmpty || rate.amount.isEmpty ? Copy.incomplete : rate.currency + UFitBrandCommerceInput.space + rate.amount).font(.subheadline)
                                        }
                                        Spacer(); Image(systemName: Icon.chevron)
                                    }.frame(minHeight: Layout.touch).contentShape(Rectangle())
                                }.buttonStyle(.plain)
                                if errors[.destinations] != nil && !rateErrors(rate).isEmpty { Text(Copy.issue).font(.caption) }
                                Button(Copy.remove) { draft.rates.removeAll { $0.id == rate.id } }.font(.callout).frame(minHeight: Layout.touch)
                                Divider()
                            }
                        }
                        if let error = errors[.destinations] { Text(error).font(.caption) }
                        Button(Copy.add) { editingRate = UFitBrandShippingRateDraft() }.frame(minHeight: Layout.touch)
                    }
                }.padding(Layout.page).frame(maxWidth: .infinity, alignment: .leading).disabled(locked)
            }.scrollDismissesKeyboard(.interactively)
        }.safeAreaInset(edge: .bottom, spacing: .zero) {
            VStack(alignment: .leading, spacing: Layout.small) {
                if let message { Text(message).font(.callout) }
                if isSaving { ProgressView(Copy.saving).frame(maxWidth: .infinity, minHeight: Layout.touch) }
                else {
                    Button(action: onSave) { Text(Copy.save).frame(maxWidth: .infinity) }.buttonStyle(PrimaryButtonStyle()).disabled(!hasChanges || isLoading)
                        .opacity(!hasChanges || isLoading ? Layout.disabledOpacity : Layout.enabledOpacity)
                }
            }.padding(Layout.gap).background(Color.white).overlay(alignment: .top) { Divider() }
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.white)
            .sheet(item: $editingRate) { rate in
                UFitBrandShippingRateContent(rate: rate, isNew: !draft.rates.contains(where: { $0.id == rate.id }), pricesIncludeTaxes: draft.pricesIncludeTaxes,
                    countries: countries, currencies: currencies, otherRates: draft.rates, onClose: { editingRate = nil }, onSave: { value in
                        if let index = draft.rates.firstIndex(where: { $0.id == value.id }) { draft.rates[index] = value }
                        else { draft.rates.append(value) }
                        editingRate = nil
                    })
            }
            .confirmationDialog(leaving == .reload ? Copy.reloadTitle : Copy.discardTitle,
                isPresented: Binding(get: { leaving != nil }, set: { if !$0 { leaving = nil } }), titleVisibility: .visible, presenting: leaving) { action in
                    Button(action == .reload ? Copy.reloadDiscard : Copy.discard, role: .destructive) {
                        if action == .reload { onReload() } else { onBack() }; leaving = nil
                    }
                    Button(Copy.keep, role: .cancel) { leaving = nil }
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
    private struct PolicyText: View {
        let label: String
        @Binding var text: String
        let error: String?
        private enum Shape { static let minimumLines = 3; static let maximumLines = 8; static let radius: CGFloat = 12 }
        var body: some View {
            VStack(alignment: .leading, spacing: Layout.small) {
                Text(label).font(.subheadline.weight(.medium))
                TextField(label, text: $text, axis: .vertical).lineLimit(Shape.minimumLines...Shape.maximumLines).padding(Layout.gap)
                    .overlay { RoundedRectangle(cornerRadius: Shape.radius).stroke(Color.ufitBorder) }.accessibilityLabel(label)
                if let error { Text(error).font(.caption) }
            }
        }
    }
}
struct UFitPolicyBooleanField: View {
    let label: String
    @Binding var value: Bool?
    let error: String?
    private enum Copy { static let choose = String(localized: "Choisir"); static let yes = String(localized: "Oui"); static let no = String(localized: "Non") }
    private enum Layout { static let gap: CGFloat = 8; static let touch: CGFloat = 44 }
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.gap) {
            Text(label).font(.subheadline.weight(.medium))
            Picker(label, selection: $value) {
                Text(Copy.choose).tag(Optional<Bool>.none)
                Text(Copy.yes).tag(Optional(true)); Text(Copy.no).tag(Optional(false))
            }.labelsHidden().pickerStyle(.menu).frame(minHeight: Layout.touch).accessibilityLabel(label)
                .accessibilityValue(value.map { $0 ? Copy.yes : Copy.no } ?? Copy.choose)
            if let error { Text(error).font(.caption) }
        }
    }
}

struct UFitBrandCommercePreparationContent: View {
    let isLoading: Bool
    let message: String?
    let onBack: () -> Void
    let onRetry: () -> Void
    private enum Copy { static let title = String(localized: "Conditions de vente"); static let loading = String(localized: "Chargement des conditions"); static let retry = String(localized: "Réessayer") }
    private enum Layout { static let page: CGFloat = 24; static let gap: CGFloat = 16; static let touch: CGFloat = 44 }
    var body: some View {
        VStack(spacing: Layout.gap) {
            DetailHeader(title: Copy.title, onBack: onBack)
            if isLoading { ProgressView(Copy.loading) }
            if let message { Text(message).font(.callout).padding(.horizontal, Layout.page) }
            if !isLoading { Button(Copy.retry, action: onRetry).frame(minHeight: Layout.touch) }
            Spacer()
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.white)
    }
}
