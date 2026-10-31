import SwiftUI

struct UFitCatalogVariantFormContent: View {
    @Binding var draft: UFitCatalogVariantDraft
    let currency: UFitCatalogCurrency
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
    private enum Layout { static let page: CGFloat = 24; static let gap: CGFloat = 16; static let small: CGFloat = 8; static let touch: CGFloat = 44 }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: Copy.title, onBack: { if hasChanges { confirmingDiscard = true } else { onBack() } })
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.page) {
                    UFitCatalogTextField(label: Copy.sku, text: $draft.sku, error: errors[.sku], isIdentifier: true)
                    UFitCatalogTextField(label: Copy.size, text: $draft.size, error: errors[.size])
                    UFitCatalogTextField(label: Copy.color, text: $draft.color, error: errors[.color])
                    UFitCatalogTextField(label: Copy.stock, text: $draft.stock, error: errors[.stock], keyboard: .numberPad, isIdentifier: true)
                    VStack(alignment: .leading, spacing: Layout.small) {
                        UFitCatalogTextField(label: Copy.price, text: $draft.priceOverride, error: errors[.price], keyboard: .decimalPad, isIdentifier: true)
                        Text(currency.code).font(.caption.weight(.semibold))
                        Text(Copy.basePrice).font(.caption).foregroundStyle(Color.ufitMuted)
                    }
                    if draft.serverID != nil {
                        VStack(alignment: .leading, spacing: Layout.small) {
                            Text(Copy.status).font(.subheadline.weight(.medium))
                            Picker(Copy.status, selection: $draft.status) {
                                ForEach(UFitCatalogVariantStatus.allCases) { Text($0.label).tag($0) }
                            }.pickerStyle(.menu).frame(minHeight: Layout.touch)
                        }
                    }
                    Button(action: onSave) { Text(Copy.save).frame(maxWidth: .infinity) }.buttonStyle(PrimaryButtonStyle())
                }.padding(Layout.page)
            }.scrollDismissesKeyboard(.interactively)
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.white)
            .confirmationDialog(Copy.discardTitle, isPresented: $confirmingDiscard, titleVisibility: .visible) {
                Button(Copy.discard, role: .destructive, action: onBack)
                Button(Copy.keep, role: .cancel) {}
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
    private enum Layout { static let page: CGFloat = 24; static let gap: CGFloat = 16; static let small: CGFloat = 8; static let title: CGFloat = 28 }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: Copy.title, onBack: { if hasChanges { confirmingDiscard = true } else { onBack() } }).disabled(isBusy)
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.page) {
                    VStack(alignment: .leading, spacing: Layout.small) { Text(variant.title).font(.system(size: Layout.title, design: .serif)); Text(variant.sku).font(.caption).foregroundStyle(Color.ufitMuted) }
                    LabeledContent(Copy.current, value: variant.stockQuantity.formatted())
                    UFitCatalogTextField(label: Copy.quantity, text: $quantity, error: error, keyboard: .numberPad, isIdentifier: true)
                    if let message { Text(message).font(.callout) }
                    if isBusy { ProgressView(Copy.saving) }
                    else { Button(action: onSave) { Text(Copy.save).frame(maxWidth: .infinity) }.buttonStyle(PrimaryButtonStyle()).disabled(!hasChanges) }
                }.padding(Layout.page).disabled(isBusy)
            }.scrollDismissesKeyboard(.interactively)
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.white)
            .confirmationDialog(Copy.discardTitle, isPresented: $confirmingDiscard, titleVisibility: .visible) {
                Button(Copy.discard, role: .destructive, action: onBack)
                Button(Copy.keep, role: .cancel) {}
            }
    }
}
