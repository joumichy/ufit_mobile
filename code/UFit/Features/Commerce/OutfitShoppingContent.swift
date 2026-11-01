import SwiftUI

struct UFitOutfitShoppingContent: View {
    let title: String
    let image: String
    let description: String
    let author: OutfitAuthor?
    let prices: String
    let pieces: [UFitShoppingPiece]
    let cartCount: Int
    let isLoading: Bool
    let message: String?
    let onBack: () -> Void
    let onAuthor: () -> Void
    let onBrand: (String) -> Void
    let onCart: () -> Void
    let onRetry: () -> Void
    let onSelect: (String, String) -> Void
    let onQuantity: (String, Int) -> Void
    let onAdd: (String) -> Void
    private enum Copy {
        static let cart = String(localized: "Mon panier")
        static let pieces = String(localized: "Les pièces")
        static let retry = String(localized: "Réessayer")
        static let cartIcon = "bag"
        static let authorChevron = "chevron.right"
    }
    private enum Layout {
        static let spacing: CGFloat = 24
        static let hero: CGFloat = 340
        static let title: CGFloat = 32
        static let bottom: CGFloat = 112
    }
    private enum AuthorLayout { static let touch: CGFloat = 44 }
    var body: some View {
        GeometryReader { geometry in
        VStack(spacing: .zero) {
            DetailHeader(onBack: onBack) {
                Button(action: onCart) {
                    Label(cartCount > .zero ? Copy.cart + " (\(cartCount))" : Copy.cart, systemImage: Copy.cartIcon)
                }.font(.subheadline).foregroundStyle(Color.ufitInk)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.spacing) {
                    FashionImage(source: image).frame(width: geometry.size.width, height: Layout.hero).clipped()
                    VStack(alignment: .leading, spacing: Layout.spacing) {
                        Text(title).font(.system(size: Layout.title, weight: .regular, design: .serif)).fixedSize(horizontal: false, vertical: true)
                        if let author {
                            Button(action: onAuthor) { HStack { Text(author.name); Spacer(); Image(systemName: Copy.authorChevron) }.frame(minHeight: AuthorLayout.touch) }.font(.subheadline)
                        }
                        if !description.isEmpty { Text(description).font(.body).foregroundStyle(Color.ufitMuted) }
                        Text(prices).font(.title3.weight(.semibold))
                        if let message { Text(message).font(.callout).foregroundStyle(Color.ufitInk) }
                        if isLoading { ProgressView().frame(maxWidth: .infinity) }
                        else if pieces.isEmpty {
                            Button(Copy.retry, action: onRetry).buttonStyle(CompactPrimaryButtonStyle())
                        } else {
                            Text(Copy.pieces).font(.title2.weight(.semibold))
                            ForEach(pieces) { piece in
                                UFitShoppingPieceCard(piece: piece,
                                    onBrand: { if let brandID = piece.brandID { onBrand(brandID) } },
                                    onSelect: { onSelect(piece.id, $0) },
                                    onQuantity: { onQuantity(piece.id, $0) }, onAdd: { onAdd(piece.id) })
                            }
                        }
                    }.padding(.horizontal, Layout.spacing)
                }.frame(width: geometry.size.width).padding(.bottom, Layout.bottom)
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(Color.ufitInk).background(Color.white)
        }
    }
}

private struct UFitShoppingPieceCard: View {
    let piece: UFitShoppingPiece
    let onBrand: () -> Void
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
        static let photo = "photo"
        static let brandChevron = "chevron.right"
    }
    private enum Layout {
        static let spacing: CGFloat = 16
        static let image: CGFloat = 92
        static let radius: CGFloat = 16
        static let minimum = 1
    }
    private enum BrandLayout { static let touch: CGFloat = 44 }
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.spacing) {
            HStack(alignment: .top, spacing: Layout.spacing) {
                Group {
                    if let image = piece.image { FashionImage(source: image) }
                    else { Color.ufitBackground.overlay(Image(systemName: Copy.photo).foregroundStyle(Color.ufitMuted)) }
                }.frame(width: Layout.image, height: Layout.image).clipped().clipShape(RoundedRectangle(cornerRadius: Layout.radius))
                VStack(alignment: .leading, spacing: Layout.spacing) {
                    if let brand = piece.brand, piece.brandID != nil {
                        Button(action: onBrand) { HStack { Text(brand); Image(systemName: Copy.brandChevron) }.frame(minHeight: BrandLayout.touch) }.font(.caption).foregroundStyle(Color.ufitMuted)
                    }
                    Text(piece.name).font(.headline)
                    Text(piece.price).font(.subheadline.weight(.medium))
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            if let issue = piece.issue { Text(issue).font(.callout).foregroundStyle(Color.ufitMuted) }
            if !piece.variants.isEmpty {
                Picker(Copy.variant, selection: Binding<String?>(get: {piece.selectedVariantID}, set: {if let value = $0 {onSelect(value)}})) {
                    Text(Copy.choose).tag(nil as String?)
                    ForEach(piece.variants) { option in
                        Text(option.isAvailable ? option.label : option.label + " · " + Copy.unavailable)
                            .tag(Optional(option.id)).disabled(!option.isAvailable)
                    }
                }.pickerStyle(.menu).tint(Color.ufitInk).disabled(piece.isBusy)
                if piece.selectedVariantID != nil {
                    Stepper(Copy.quantity + " : \(piece.quantity)", value: Binding(get: {piece.quantity}, set: onQuantity), in: Layout.minimum...max(Layout.minimum, piece.maximumQuantity))
                        .disabled(piece.isBusy)
                }
                Button(action: onAdd) {
                    HStack {
                        Spacer()
                        if piece.isBusy { ProgressView().tint(.white) } else { Text(piece.wasAdded ? Copy.added : Copy.add) }
                        Spacer()
                    }
                }.buttonStyle(PrimaryButtonStyle()).disabled(piece.isBusy || piece.selectedVariantID == nil)
            }
        }
        .padding(Layout.spacing)
        .background(Color.ufitBackground.opacity(0.45), in: RoundedRectangle(cornerRadius: Layout.radius))
    }
}
