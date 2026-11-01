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
    private enum Layout { static let page: CGFloat = 24; static let gap: CGFloat = 16; static let small: CGFloat = 8; static let touch: CGFloat = 44 }
    private enum Icon { static let chevron = "chevron.right" }
    init(rate: UFitBrandShippingRateDraft, isNew: Bool, pricesIncludeTaxes: Bool?, countries: [UFitCountry], currencies: [UFitCurrency],
         otherRates: [UFitBrandShippingRateDraft], onClose: @escaping () -> Void, onSave: @escaping (UFitBrandShippingRateDraft) -> Void) {
        _draft = State(initialValue: rate); original = rate; self.isNew = isNew; self.pricesIncludeTaxes = pricesIncludeTaxes
        self.countries = countries; self.currencies = currencies; self.otherRates = otherRates; self.onClose = onClose; self.onSave = onSave
    }
    var body: some View {
        NavigationStack {
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
                    Button {
                        errors = UFitBrandCommerceValidation.rate(draft, pricesIncludeTaxes: pricesIncludeTaxes, countries: countries, currencies: currencies, others: otherRates)
                        if errors.isEmpty { onSave(draft) }
                    } label: { Text(Copy.save).frame(maxWidth: .infinity) }.buttonStyle(PrimaryButtonStyle()).padding(Layout.gap).background(Color.white)
                }
                .navigationTitle(isNew ? Copy.new : Copy.edit).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button(Copy.close) { if draft == original { onClose() } else { confirmingDiscard = true } } } }
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.white)
            .interactiveDismissDisabled(draft != original)
            .onChange(of: draft) { _, _ in errors = [:] }
            .sheet(item: $selection) { picker in
                switch picker {
                case .country: UFitCountrySelectionContent(countries: countries, selected: draft.country) { draft.country = $0.id }
                case .currency: UFitCurrencySelectionContent(currencies: currencies, selected: draft.currency) { draft.currency = $0.code }
                }
            }
            .confirmationDialog(Copy.discardTitle, isPresented: $confirmingDiscard, titleVisibility: .visible) {
                Button(Copy.discard, role: .destructive, action: onClose)
                Button(Copy.keep, role: .cancel) {}
            }
    }
    private func choice(_ label: String, value: String, error: String?, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: Layout.small) {
            Text(label).font(.subheadline.weight(.medium))
            Button(action: action) { HStack { Text(value); Spacer(); Image(systemName: Icon.chevron) }.frame(minHeight: Layout.touch).contentShape(Rectangle()) }.buttonStyle(.plain).accessibilityLabel(label + UFitBrandCommerceInput.separator + value)
            if let error { Text(error).font(.caption) }
        }
    }
}
