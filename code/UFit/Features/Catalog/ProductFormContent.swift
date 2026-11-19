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
    var renewPhotoSource: ((UUID) async throws -> String)? = nil
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
        static let changesPublication = String(localized: "Enregistrer ces modifications remettra le produit en brouillon. Vous pourrez ensuite le publier directement.")
        static let variants = String(localized: "Variantes"); static let addVariant = String(localized: "Ajouter une variante"); static let editVariant = String(localized: "Modifier la variante")
        static let remove = String(localized: "Retirer"); static let emptyVariants = String(localized: "Aucune variante"); static let stock = String(localized: "Stock"); static let details = String(localized: "Détails facultatifs")
        static let material = String(localized: "Matière"); static let care = String(localized: "Entretien")
        static let discardTitle = String(localized: "Abandonner les modifications ?"); static let discard = String(localized: "Abandonner"); static let keep = String(localized: "Continuer la saisie")
    }
    private enum Layout { static let page: CGFloat = UFitSpace.xl; static let gap: CGFloat = UFitSpace.md; static let small: CGFloat = UFitSpace.xs; static let touch: CGFloat = UFitControlSize.touch; static let editor: CGFloat = 130; static let radius: CGFloat = UFitRadius.field; static let title: CGFloat = UFitTypography.Size.title }
    private enum Icon { static let currency = "chevron.right" }
    private var selectedCurrency: UFitCurrency? { currencies.first { $0.code == draft.currency } }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: isNew ? Copy.new : Copy.edit, onBack: { if hasChanges { confirmingDiscard = true } else { onBack() } }).disabled(isBusy)
            if let message { Text(message).font(UFitTypography.callout).padding(Layout.gap).frame(maxWidth: .infinity, alignment: .leading).background(Color.ufitCanvas) }
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.page) {
                    UFitEditorialHeading(title: ProductDesignCopy.identity, editorial: false)
                    UFitCatalogPhotosContent(photos: $draft.photos, error: errors[.photos], onAdd: onAddPhotos, onRetry: onRetryPhoto,
                        onRemove: onRemovePhoto, renewPhotoSource: renewPhotoSource)
                    UFitTextField(label: Copy.name, text: $draft.name, error: errors[.name])
                    UFitMultilineField(label: Copy.description, text: $draft.description, error: errors[.description])
                    UFitTextField(label: Copy.category, text: $draft.category, error: errors[.category])
                    VStack(alignment: .leading, spacing: Layout.small) {
                        Text(Copy.gender).font(UFitTypography.subheadline.weight(.medium))
                        UFitInlineChoice(title: Copy.gender, selection: $draft.gender, options: [.init(value: nil, title: Copy.unspecified)] + UFitGenderTarget.allCases.map { .init(value: Optional($0), title: $0.label) })
                    }
                    UFitEditorialHeading(title: ProductDesignCopy.offer, editorial: false)
                    VStack(alignment: .leading, spacing: Layout.small) {
                        UFitButton { showingCurrencies = true } label: { HStack { Text(Copy.currency); Spacer(); Text(draft.currency); UFitIcon(systemName: Icon.currency) }.frame(minHeight: Layout.touch) }.disabled(currencies.isEmpty)
                        errorText(errors[.currency])
                        if currencies.isEmpty { UFitActionButton(title: Copy.reloadCurrencies, kind: .secondary, action: onReloadCurrencies) }
                        UFitTextField(label: Copy.price, text: $draft.price, error: errors[.price], keyboard: .decimalPad, isIdentifier: true)
                    }
                    variants
                    UFitDisclosure(Copy.details) {
                        VStack(spacing: Layout.gap) {
                            UFitTextField(label: Copy.material, text: $draft.material, error: errors[.material])
                            UFitTextField(label: Copy.care, text: $draft.care, error: errors[.care])
                        }.padding(.top, Layout.gap)
                    }
                    if changesPublishedProduct { Text(Copy.changesPublication).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText) }
                    if isBusy { UFitLoading(Copy.saving) }
                    else { UFitButton(action: onSave) { Text(Copy.save).frame(maxWidth: .infinity) }.ufitButtonStyle(.primary).disabled(!hasChanges || selectedCurrency == nil) }
                }.padding(Layout.page).disabled(isBusy)
            }.scrollDismissesKeyboard(.interactively)
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.ufitCanvas)
            .ufitConfirmationDialog(Copy.discardTitle, isPresented: $confirmingDiscard, titleVisibility: .visible) {
                UFitButton(Copy.discard, role: .destructive, action: onBack)
                UFitButton(Copy.keep, role: .cancel) {}
            }
            .ufitSheet(isPresented: $showingCurrencies) { UFitCurrencySelectionContent(currencies: currencies, selected: draft.currency) { draft.currency = $0.code } }
            .ufitSheet(item: $editingVariant) { variant in
                if let currency = selectedCurrency {
                    UFitCatalogVariantFormContent(draft: Binding(get: { editingVariant ?? variant }, set: { editingVariant = $0; variantErrors = [:] }), currency: currency, errors: variantErrors, hasChanges: editingVariant != initialVariant, onBack: { editingVariant = nil }, onSave: { saveVariant(currency: currency) })
                        .interactiveDismissDisabled(editingVariant != initialVariant)
                }
            }
    }
    private var variants: some View {
        VStack(alignment: .leading, spacing: Layout.gap) {
            Text(Copy.variants).font(UFitTypography.title2.weight(.medium))
            if draft.variants.isEmpty { Text(Copy.emptyVariants).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText) }
            ForEach(draft.variants) { variant in
                VStack(alignment: .leading, spacing: Layout.small) {
                    Text(variant.title).font(UFitTypography.headline)
                    Text(variant.status.label).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                    UFitLabeledValue(Copy.stock, value: variant.stock).font(UFitTypography.callout)
                    HStack {
                        UFitButton(Copy.editVariant) { openVariant(variant) }.ufitButtonStyle(.secondary, compact: true).disabled(selectedCurrency == nil)
                        if variant.serverID == nil { Spacer(); UFitButton(Copy.remove, role: .destructive) { draft.variants.removeAll { $0.id == variant.id } }.ufitButtonStyle(.secondary, compact: true) }
                    }
                    Divider()
                }
            }
            if draft.variants.count < UFitCatalogInput.variantsMax { UFitActionButton(title: Copy.addVariant, kind: .secondary) { openVariant(UFitCatalogVariantDraft()) }.disabled(selectedCurrency == nil) }
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
    @ViewBuilder private func errorText(_ text: String?) -> some View { if let text { Text(text).font(UFitTypography.caption) } }
}

private enum ProductDesignCopy {
    static let identity = String(localized: "Images & identité")
    static let offer = String(localized: "Prix & devise")
}
