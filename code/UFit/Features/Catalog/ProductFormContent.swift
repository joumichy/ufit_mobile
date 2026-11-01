import SwiftUI

struct UFitCatalogProductFormContent: View {
    @Binding var draft: UFitCatalogProductDraft
    let isNew: Bool
    let changesPublishedProduct: Bool
    let currencies: [UFitCurrency]
    let errors: [UFitCatalogField: String]
    let hasChanges: Bool
    let isBusy: Bool
    let message: String?
    let onBack: () -> Void
    let onSave: () -> Void
    let onReloadCurrencies: () -> Void
    let onAddPhotos: () -> Void
    let onRetryPhoto: (UUID) -> Void
    let onRemovePhoto: (UUID) -> Void
    @State private var confirmingDiscard = false
    @State private var showingCurrencies = false
    @State private var editingVariant: UFitCatalogVariantDraft?
    @State private var initialVariant: UFitCatalogVariantDraft?
    @State private var variantErrors: [UFitCatalogVariantField: String] = [:]
    private enum Copy {
        static let new = String(localized: "Nouveau produit"); static let edit = String(localized: "Modifier le produit"); static let save = String(localized: "Enregistrer le brouillon")
        static let saving = String(localized: "Enregistrement du produit"); static let name = String(localized: "Nom du produit"); static let description = String(localized: "Description")
        static let category = String(localized: "Catégorie"); static let gender = String(localized: "Public (facultatif)"); static let unspecified = String(localized: "Non précisé")
        static let price = String(localized: "Prix du produit"); static let currency = String(localized: "Devise"); static let reloadCurrencies = String(localized: "Recharger les devises")
        static let changesPublication = String(localized: "Enregistrer ces modifications remettra le produit en brouillon. Une nouvelle validation sera nécessaire.")
        static let variants = String(localized: "Variantes"); static let addVariant = String(localized: "Ajouter une variante"); static let editVariant = String(localized: "Modifier la variante")
        static let remove = String(localized: "Retirer"); static let emptyVariants = String(localized: "Aucune variante"); static let stock = String(localized: "Stock"); static let details = String(localized: "Détails facultatifs")
        static let material = String(localized: "Matière"); static let care = String(localized: "Entretien")
        static let discardTitle = String(localized: "Abandonner les modifications ?"); static let discard = String(localized: "Abandonner"); static let keep = String(localized: "Continuer la saisie")
    }
    private enum Layout { static let page: CGFloat = 24; static let gap: CGFloat = 16; static let small: CGFloat = 8; static let touch: CGFloat = 44; static let editor: CGFloat = 130; static let radius: CGFloat = 12; static let title: CGFloat = 28 }
    private enum Icon { static let currency = "chevron.right" }
    private var selectedCurrency: UFitCurrency? { currencies.first { $0.code == draft.currency } }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: isNew ? Copy.new : Copy.edit, onBack: { if hasChanges { confirmingDiscard = true } else { onBack() } }).disabled(isBusy)
            if let message { Text(message).font(.callout).padding(Layout.gap).frame(maxWidth: .infinity, alignment: .leading).background(Color.ufitBackground) }
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.page) {
                    UFitTextField(label: Copy.name, text: $draft.name, error: errors[.name])
                    VStack(alignment: .leading, spacing: Layout.small) {
                        Text(Copy.description).font(.subheadline.weight(.medium))
                        TextEditor(text: $draft.description).frame(minHeight: Layout.editor).padding(Layout.small)
                            .overlay { RoundedRectangle(cornerRadius: Layout.radius).stroke(Color.ufitBorder) }.accessibilityLabel(Copy.description)
                        errorText(errors[.description])
                    }
                    UFitTextField(label: Copy.category, text: $draft.category, error: errors[.category])
                    VStack(alignment: .leading, spacing: Layout.small) {
                        Text(Copy.gender).font(.subheadline.weight(.medium))
                        Picker(Copy.gender, selection: $draft.gender) {
                            Text(Copy.unspecified).tag(Optional<UFitGenderTarget>.none)
                            ForEach(UFitGenderTarget.allCases) { Text($0.label).tag(Optional($0)) }
                        }.pickerStyle(.menu).frame(minHeight: Layout.touch)
                    }
                    VStack(alignment: .leading, spacing: Layout.small) {
                        Button { showingCurrencies = true } label: { HStack { Text(Copy.currency); Spacer(); Text(draft.currency); Image(systemName: Icon.currency) }.frame(minHeight: Layout.touch) }.disabled(currencies.isEmpty)
                        errorText(errors[.currency])
                        if currencies.isEmpty { Button(Copy.reloadCurrencies, action: onReloadCurrencies).frame(minHeight: Layout.touch) }
                        UFitTextField(label: Copy.price, text: $draft.price, error: errors[.price], keyboard: .decimalPad, isIdentifier: true)
                    }
                    UFitCatalogPhotosContent(photos: $draft.photos, error: errors[.photos], onAdd: onAddPhotos, onRetry: onRetryPhoto, onRemove: onRemovePhoto)
                    variants
                    DisclosureGroup(Copy.details) {
                        VStack(spacing: Layout.gap) {
                            UFitTextField(label: Copy.material, text: $draft.material, error: errors[.material])
                            UFitTextField(label: Copy.care, text: $draft.care, error: errors[.care])
                        }.padding(.top, Layout.gap)
                    }
                    if changesPublishedProduct { Text(Copy.changesPublication).font(.callout).foregroundStyle(Color.ufitMuted) }
                    if isBusy { ProgressView(Copy.saving) }
                    else { Button(action: onSave) { Text(Copy.save).frame(maxWidth: .infinity) }.buttonStyle(PrimaryButtonStyle()).disabled(!hasChanges || selectedCurrency == nil) }
                }.padding(Layout.page).disabled(isBusy)
            }.scrollDismissesKeyboard(.interactively)
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.white)
            .confirmationDialog(Copy.discardTitle, isPresented: $confirmingDiscard, titleVisibility: .visible) {
                Button(Copy.discard, role: .destructive, action: onBack)
                Button(Copy.keep, role: .cancel) {}
            }
            .sheet(isPresented: $showingCurrencies) { UFitCurrencySelectionContent(currencies: currencies, selected: draft.currency) { draft.currency = $0.code } }
            .sheet(item: $editingVariant) { variant in
                if let currency = selectedCurrency {
                    UFitCatalogVariantFormContent(draft: Binding(get: { editingVariant ?? variant }, set: { editingVariant = $0; variantErrors = [:] }), currency: currency, errors: variantErrors, hasChanges: editingVariant != initialVariant, onBack: { editingVariant = nil }, onSave: { saveVariant(currency: currency) })
                        .interactiveDismissDisabled(editingVariant != initialVariant)
                }
            }
    }
    private var variants: some View {
        VStack(alignment: .leading, spacing: Layout.gap) {
            Text(Copy.variants).font(.title2.weight(.medium))
            if draft.variants.isEmpty { Text(Copy.emptyVariants).font(.callout).foregroundStyle(Color.ufitMuted) }
            ForEach(draft.variants) { variant in
                VStack(alignment: .leading, spacing: Layout.small) {
                    Text(variant.title).font(.headline)
                    Text(variant.status.label).font(.caption).foregroundStyle(Color.ufitMuted)
                    LabeledContent(Copy.stock, value: variant.stock).font(.callout)
                    HStack {
                        Button(Copy.editVariant) { openVariant(variant) }.frame(minHeight: Layout.touch).disabled(selectedCurrency == nil)
                        if variant.serverID == nil { Spacer(); Button(Copy.remove) { draft.variants.removeAll { $0.id == variant.id } }.frame(minHeight: Layout.touch) }
                    }
                    Divider()
                }
            }
            if draft.variants.count < UFitCatalogInput.variantsMax { Button(Copy.addVariant) { openVariant(UFitCatalogVariantDraft()) }.frame(minHeight: Layout.touch).disabled(selectedCurrency == nil) }
            errorText(errors[.variants])
        }
    }
    private func openVariant(_ variant: UFitCatalogVariantDraft) { initialVariant = variant; variantErrors = [:]; editingVariant = variant }
    private func saveVariant(currency: UFitCurrency) {
        guard let variant = editingVariant else { return }
        variantErrors = UFitCatalogDraftValidation.variant(variant, currency: currency)
        guard variantErrors.isEmpty else { return }
        if let index = draft.variants.firstIndex(where: { $0.id == variant.id }) { draft.variants[index] = variant }
        else { draft.variants.append(variant) }
        editingVariant = nil
    }
    @ViewBuilder private func errorText(_ text: String?) -> some View { if let text { Text(text).font(.caption) } }
}
