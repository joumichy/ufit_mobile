import SwiftUI

struct UFitCatalogVariantFormContent: View {
    @Binding var draft: UFitCatalogVariantDraft
    let currency: UFitCurrency
    let errors: [UFitCatalogVariantField: String]
    let hasChanges: Bool
    let onBack: () -> Void
    let onSave: () -> Void
    @State private var confirmingDiscard = false
    private enum Copy {
        static let title = String(localized: "Variante"); static let save = String(localized: "Conserver la variante")
        static let sku = String(localized: "Référence SKU"); static let size = String(localized: "Taille (facultatif)"); static let color = String(localized: "Couleur (facultatif)")
        static let stock = String(localized: "Quantité en stock"); static let price = String(localized: "Prix spécifique (facultatif)"); static let basePrice = String(localized: "Sans prix spécifique, le prix du produit s’applique.")
        static let discardTitle = String(localized: "Abandonner cette variante ?"); static let discard = String(localized: "Abandonner"); static let keep = String(localized: "Continuer la saisie")
        static let status = String(localized: "Statut")
    }
    private enum Layout { static let page: CGFloat = UFitSpace.xl; static let gap: CGFloat = UFitSpace.md; static let small: CGFloat = UFitSpace.xs; static let touch: CGFloat = UFitControlSize.touch }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: Copy.title, onBack: { if hasChanges { confirmingDiscard = true } else { onBack() } })
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.page) {
                    UFitTextField(label: Copy.sku, text: $draft.sku, error: errors[.sku], isIdentifier: true)
                    UFitTextField(label: Copy.size, text: $draft.size, error: errors[.size])
                    UFitTextField(label: Copy.color, text: $draft.color, error: errors[.color])
                    UFitTextField(label: Copy.stock, text: $draft.stock, error: errors[.stock], keyboard: .numberPad, isIdentifier: true)
                    VStack(alignment: .leading, spacing: Layout.small) {
                        UFitTextField(label: Copy.price, text: $draft.priceOverride, error: errors[.price], keyboard: .decimalPad, isIdentifier: true)
                        Text(currency.code).font(UFitTypography.caption.weight(.semibold))
                        Text(Copy.basePrice).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                    }
                    if draft.serverID != nil {
                        VStack(alignment: .leading, spacing: Layout.small) {
                            Text(Copy.status).font(UFitTypography.subheadline.weight(.medium))
                            UFitInlineChoice(title: Copy.status, selection: $draft.status, options: UFitCatalogVariantStatus.allCases.map { .init(value: $0, title: $0.label) })
                        }
                    }
                    UFitButton(action: onSave) { Text(Copy.save).frame(maxWidth: .infinity) }.ufitButtonStyle(.primary)
                }.padding(Layout.page)
            }.scrollDismissesKeyboard(.interactively)
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.ufitCanvas)
            .ufitConfirmationDialog(Copy.discardTitle, isPresented: $confirmingDiscard, titleVisibility: .visible) {
                UFitButton(Copy.discard, role: .destructive, action: onBack)
                UFitButton(Copy.keep, role: .cancel) {}
            }
    }
}
struct UFitCatalogStockContent: View {
    let variant: UFitCatalogVariant
    @Binding var quantity: String
    let error: String?
    let message: String?
    let isBusy: Bool
    let hasChanges: Bool
    let onBack: () -> Void
    let onSave: () -> Void
    @State private var confirmingDiscard = false
    private enum Copy {
        static let title = String(localized: "Stock"); static let current = String(localized: "Stock actuel"); static let quantity = String(localized: "Nouvelle quantité")
        static let save = String(localized: "Enregistrer le stock"); static let saving = String(localized: "Enregistrement du stock")
        static let discardTitle = String(localized: "Abandonner la modification du stock ?"); static let discard = String(localized: "Abandonner"); static let keep = String(localized: "Continuer la saisie")
    }
    private enum Layout { static let page: CGFloat = UFitSpace.xl; static let gap: CGFloat = UFitSpace.md; static let small: CGFloat = UFitSpace.xs; static let title: CGFloat = UFitTypography.Size.title }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: Copy.title, onBack: { if hasChanges { confirmingDiscard = true } else { onBack() } }).disabled(isBusy)
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.page) {
                    VStack(alignment: .leading, spacing: Layout.small) { Text(variant.title).ufitFont(size: Layout.title, design: .serif); Text(variant.sku).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText) }
                    UFitLabeledValue(Copy.current, value: variant.stockQuantity.formatted())
                    UFitTextField(label: Copy.quantity, text: $quantity, error: error, keyboard: .numberPad, isIdentifier: true)
                    if let message { Text(message).font(UFitTypography.callout) }
                    if isBusy { UFitLoading(Copy.saving) }
                    else { UFitButton(action: onSave) { Text(Copy.save).frame(maxWidth: .infinity) }.ufitButtonStyle(.primary).disabled(!hasChanges) }
                }.padding(Layout.page).disabled(isBusy)
            }.scrollDismissesKeyboard(.interactively)
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.ufitCanvas)
            .ufitConfirmationDialog(Copy.discardTitle, isPresented: $confirmingDiscard, titleVisibility: .visible) {
                UFitButton(Copy.discard, role: .destructive, action: onBack)
                UFitButton(Copy.keep, role: .cancel) {}
            }
    }
}
