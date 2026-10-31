import SwiftUI

struct UFitCartContent: View {
    let lines: [UFitCartPresentationLine]
    let subtotal: String
    let isLoading: Bool
    let message: String?
    let onBack: () -> Void
    let onRefresh: () -> Void
    let onQuantity: (String, Int) -> Void
    let onRemove: (String) -> Void
    var onCheckout: (() -> Void)?
    private enum Copy {
        static let title = String(localized: "Mon panier")
        static let empty = String(localized: "Votre panier est vide")
        static let emptyIcon = "bag"
        static let subtotal = String(localized: "Sous-total")
        static let checkout = String(localized: "Livraison et paiement")
        static let retry = String(localized: "Actualiser")
    }
    private enum Layout { static let spacing: CGFloat = 24; static let bottom: CGFloat = 110 }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(onBack: onBack) { Text(Copy.title).font(.headline) }
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.spacing) {
                    if isLoading && lines.isEmpty { ProgressView().frame(maxWidth: .infinity) }
                    else if lines.isEmpty {
                        ContentUnavailableView(Copy.empty, systemImage: Copy.emptyIcon)
                        Button(Copy.retry, action: onRefresh).buttonStyle(CompactPrimaryButtonStyle())
                    } else {
                        ForEach(lines) { line in
                            UFitCartLineContent(line: line, onQuantity: { onQuantity(line.id, $0) }, onRemove: { onRemove(line.id) })
                            Divider()
                        }
                        HStack { Text(Copy.subtotal); Spacer(); Text(subtotal).fontWeight(.semibold) }
                        if let onCheckout {
                            Button(action: onCheckout) { Text(Copy.checkout).frame(maxWidth: .infinity) }
                                .buttonStyle(PrimaryButtonStyle()).disabled(lines.contains { $0.isBusy || !$0.isAvailable })
                        }
                    }
                    if let message { Text(message).font(.callout).foregroundStyle(Color.ufitMuted) }
                }.padding(Layout.spacing).padding(.bottom, Layout.bottom)
            }.refreshable { onRefresh() }
        }.foregroundStyle(Color.ufitInk).background(Color.white)
    }
}

private struct UFitCartLineContent: View {
    let line: UFitCartPresentationLine
    let onQuantity: (Int) -> Void
    let onRemove: () -> Void
    private enum Copy {
        static let quantity = String(localized: "Quantité")
        static let remove = String(localized: "Supprimer")
        static let unavailable = String(localized: "Pièce indisponible")
        static let photo = "photo"
    }
    private enum Layout { static let image: CGFloat = 84; static let spacing: CGFloat = 16; static let minimum = 1 }
    var body: some View {
        HStack(alignment: .top, spacing: Layout.spacing) {
            Group {
                if let image = line.image { FashionImage(source: image) }
                else { Color.ufitBackground.overlay(Image(systemName: Copy.photo)) }
            }.frame(width: Layout.image, height: Layout.image).clipped()
            VStack(alignment: .leading, spacing: Layout.spacing) {
                Text(line.name).font(.headline)
                Text(line.variant).font(.subheadline).foregroundStyle(Color.ufitMuted)
                Text(line.amount).font(.subheadline.weight(.medium))
                if !line.isAvailable { Text(Copy.unavailable).font(.callout) }
                Stepper(Copy.quantity + " : \(line.quantity)", value: Binding(get: {line.quantity}, set: onQuantity), in: Layout.minimum...max(Layout.minimum, line.maximumQuantity))
                    .disabled(line.isBusy || !line.isAvailable)
                HStack {
                    Button(Copy.remove, role: .destructive, action: onRemove).disabled(line.isBusy)
                    if line.isBusy { ProgressView() }
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
