import SwiftUI

struct UFitBrandShippingRateContent: View {
    @State private var draft: UFitBrandShippingRateDraft
    private let original: UFitBrandShippingRateDraft
    let isNew: Bool
    let pricesIncludeTaxes: Bool?
    let countries: [UFitCountry]
    let currencies: [UFitCurrency]
    let otherRates: [UFitBrandShippingRateDraft]
    let onClose: () -> Void
    let onSave: (UFitBrandShippingRateDraft) -> Void
    @State private var errors: [UFitBrandShippingRateField: String] = [:]
    @State private var selection: Selection?
    @State private var confirmingDiscard = false
    private enum Selection: String, Identifiable { case country, currency; var id: String { rawValue } }
    private enum Copy {
        static let new = String(localized: "Nouvelle destination"); static let edit = String(localized: "Modifier le tarif")
        static let country = String(localized: "Pays de livraison"); static let chooseCountry = String(localized: "Choisir un pays")
        static let currency = String(localized: "Devise"); static let chooseCurrency = String(localized: "Choisir une devise")
        static let amount = String(localized: "Frais de livraison"); static let tax = String(localized: "Taxe à ajouter (%)")
        static let taxOnShipping = String(localized: "La taxe s’applique aussi aux frais de livraison")
        static let save = String(localized: "Valider le tarif"); static let close = String(localized: "Annuler")
        static let discardTitle = String(localized: "Abandonner ce tarif ?"); static let discard = String(localized: "Abandonner")
        static let keep = String(localized: "Continuer la saisie")
    }
    private enum Layout { static let page: CGFloat = UFitSpace.xl; static let gap: CGFloat = UFitSpace.md; static let small: CGFloat = UFitSpace.xs; static let touch: CGFloat = UFitControlSize.touch }
    private enum Icon { static let chevron = "chevron.right" }
    init(rate: UFitBrandShippingRateDraft, isNew: Bool, pricesIncludeTaxes: Bool?, countries: [UFitCountry], currencies: [UFitCurrency],
         otherRates: [UFitBrandShippingRateDraft], onClose: @escaping () -> Void, onSave: @escaping (UFitBrandShippingRateDraft) -> Void) {
        _draft = State(initialValue: rate); original = rate; self.isNew = isNew; self.pricesIncludeTaxes = pricesIncludeTaxes
        self.countries = countries; self.currencies = currencies; self.otherRates = otherRates; self.onClose = onClose; self.onSave = onSave
    }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: isNew ? Copy.new : Copy.edit, onBack: { if draft == original { onClose() } else { confirmingDiscard = true } })
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.page) {
                    choice(Copy.country, value: countries.first(where: { $0.id == draft.country })?.name ?? Copy.chooseCountry,
                        error: errors[.country], action: { selection = .country })
                    choice(Copy.currency, value: draft.currency.isEmpty ? Copy.chooseCurrency : draft.currency,
                        error: errors[.currency], action: { selection = .currency })
                    UFitTextField(label: Copy.amount, text: $draft.amount, error: errors[.amount], keyboard: .decimalPad)
                    if pricesIncludeTaxes != true {
                        UFitTextField(label: Copy.tax, text: $draft.taxPercent, error: errors[.taxPercent], keyboard: .decimalPad)
                        UFitPolicyBooleanField(label: Copy.taxOnShipping, value: $draft.taxOnShipping, error: errors[.taxOnShipping])
                    }
                }.padding(Layout.page).frame(maxWidth: .infinity, alignment: .leading)
            }.scrollDismissesKeyboard(.interactively)
                .safeAreaInset(edge: .bottom) {
                    UFitButton {
                        errors = UFitBrandCommerceValidation.rate(draft, pricesIncludeTaxes: pricesIncludeTaxes, countries: countries, currencies: currencies, others: otherRates)
                        if errors.isEmpty { onSave(draft) }
                    } label: { Text(Copy.save).frame(maxWidth: .infinity) }.ufitButtonStyle(.primary).padding(Layout.gap).background(Color.ufitCanvas)
                }
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.ufitCanvas)
            .onChange(of: draft) { _, _ in errors = [:] }
            .ufitSheet(item: $selection) { picker in
                switch picker {
                case .country: UFitCountrySelectionContent(countries: countries, selected: draft.country) { draft.country = $0.id }
                case .currency: UFitCurrencySelectionContent(currencies: currencies, selected: draft.currency) { draft.currency = $0.code }
                }
            }
            .ufitConfirmationDialog(Copy.discardTitle, isPresented: $confirmingDiscard, titleVisibility: .visible) {
                UFitButton(Copy.discard, role: .destructive, action: onClose)
                UFitButton(Copy.keep, role: .cancel) {}
            }
    }
    private func choice(_ label: String, value: String, error: String?, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: Layout.small) {
            Text(label).font(UFitTypography.subheadline.weight(.medium))
            UFitButton(action: action) { HStack { Text(value); Spacer(); UFitIcon(systemName: Icon.chevron) }.frame(minHeight: Layout.touch).contentShape(Rectangle()) }.ufitButtonStyle(.text).accessibilityLabel(label + UFitBrandCommerceInput.separator + value)
            if let error { UFitFieldError(message: error) }
        }
    }
}
