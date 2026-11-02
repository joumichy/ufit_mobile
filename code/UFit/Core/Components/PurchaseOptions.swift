import SwiftUI

struct UFitPurchaseOptions: View {
    let piece: UFitShoppingPiece
    var disabled = false
    let onSelect: (String) -> Void
    let onQuantity: (Int) -> Void
    let onAdd: () -> Void
    private enum Copy {
        static let variant = String(localized: "Taille et couleur")
        static let choose = String(localized: "Choisir une option")
        static let unavailable = String(localized: "Indisponible")
        static let quantity = String(localized: "Quantité")
        static let add = String(localized: "Ajouter au panier")
        static let added = String(localized: "Ajouté · Ajouter à nouveau")
        static let separator = " · "
    }
    private enum Layout { static let minimum = 1 }
    var body: some View {
        VStack(alignment: .leading, spacing: UFitSpace.md) {
            if !piece.variants.isEmpty {
                UFitSelection(Copy.variant, selection: Binding<String?>(get: { piece.selectedVariantID }, set: { if let value = $0 { onSelect(value) } }),
                    options: [.init(value: nil, title: Copy.choose)] + piece.variants.map {
                        .init(value: Optional($0.id), title: $0.isAvailable ? $0.label : $0.label + Copy.separator + Copy.unavailable, enabled: $0.isAvailable)
                    }).tint(Color.ufitInk).disabled(piece.isBusy || disabled)
                if piece.selectedVariantID != nil {
                    UFitQuantityControl(Copy.quantity, value: Binding(get: { piece.quantity }, set: onQuantity),
                        in: Layout.minimum...max(Layout.minimum, piece.maximumQuantity)).disabled(piece.isBusy || disabled)
                }
                UFitActionButton(title: piece.wasAdded ? Copy.added : Copy.add, isBusy: piece.isBusy,
                    disabled: piece.selectedVariantID == nil || disabled, action: onAdd)
            }
        }
    }
}
