import SwiftUI

struct UFitOutfitShoppingContent: View {
    let title: String
    let photos: [UFitOutfitGalleryPhoto]
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
    var focusedItemID: String? = nil
    private enum Copy {
        static let cart = String(localized: "Mon panier")
        static let pieces = String(localized: "Les pièces")
        static let retry = String(localized: "Réessayer")
        static let cartIcon = "bag"
        static let missing = String(localized: "Cette pièce n’est plus associée à la tenue. Actualisez la publication.")
        static let authorChevron = "chevron.right"
    }
    private enum Layout {
        static let spacing: CGFloat = UFitSpace.xl
        static let title: CGFloat = UFitTypography.Size.editorial
        static let bottom: CGFloat = 112
    }
    private enum AuthorLayout { static let touch: CGFloat = UFitControlSize.touch }
    var body: some View {
        GeometryReader { geometry in
        VStack(spacing: .zero) {
            DetailHeader(onBack: onBack) {
                UFitButton(action: onCart) {
                    Label(cartCount > .zero ? Copy.cart + " (\(cartCount))" : Copy.cart, systemImage: Copy.cartIcon)
                }.font(UFitTypography.subheadline).foregroundStyle(Color.ufitInk)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.spacing) {
                    if focusedItemID == nil {
                        UFitOutfitGalleryContent(photos: photos, contentMode: .fit, surface: .neutral)
                            .frame(width: geometry.size.width)
                    }
                    VStack(alignment: .leading, spacing: Layout.spacing) {
                        Text(title).ufitFont(size: Layout.title, weight: .regular, design: .serif).fixedSize(horizontal: false, vertical: true)
                        if let author {
                            UFitButton(action: onAuthor) { HStack { Text(author.name); Spacer(); UFitIcon(systemName: Copy.authorChevron) }.frame(minHeight: AuthorLayout.touch) }.font(UFitTypography.subheadline)
                        }
                        if focusedItemID == nil && !description.isEmpty { Text(description).font(UFitTypography.body).foregroundStyle(Color.ufitSecondaryText) }
                        if focusedItemID == nil { Text(prices).font(UFitTypography.title3.weight(.semibold)) }
                        if let message { Text(message).font(UFitTypography.callout).foregroundStyle(Color.ufitInk) }
                        if isLoading { UFitLoading().frame(maxWidth: .infinity) }
                        else if pieces.isEmpty {
                            UFitButton(Copy.retry, action: onRetry).ufitButtonStyle(.primary, compact: true)
                        } else {
                            Text(Copy.pieces).font(UFitTypography.title2.weight(.semibold))
                            if let focusedItemID, !pieces.contains(where: { $0.id == focusedItemID }) { Text(Copy.missing).font(UFitTypography.callout) }
                            ForEach(pieces.filter { focusedItemID == nil || $0.id == focusedItemID }) { piece in
                                UFitShoppingPieceCard(piece: piece,
                                    onBrand: { if let brandID = piece.brandID { onBrand(brandID) } },
                                    onSelect: { onSelect(piece.id, $0) },
                                    onQuantity: { onQuantity(piece.id, $0) }, onAdd: { onAdd(piece.id) })
                            }
                        }
                    }.padding(.horizontal, Layout.spacing)
                }.frame(width: geometry.size.width).padding(.bottom, UFitSpace.xl)
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
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
        static let brandChevron = "chevron.right"
    }
    private enum Layout {
        static let spacing: CGFloat = UFitSpace.md
        static let image: CGFloat = 92
        static let glyph: CGFloat = 40
        static let radius: CGFloat = UFitRadius.card
    }
    private enum BrandLayout { static let touch: CGFloat = UFitControlSize.touch }
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.spacing) {
            HStack(alignment: .top, spacing: Layout.spacing) {
                if let image = piece.image {
                    FashionImage(source: image).frame(width: Layout.image, height: Layout.image)
                        .clipped().clipShape(RoundedRectangle(cornerRadius: Layout.radius))
                } else if let itemType = piece.itemType {
                    Color.ufitSecondary.frame(width: Layout.image, height: Layout.image)
                        .overlay { UFitOutfitItemIcon(type: itemType, size: Layout.glyph) }
                        .clipShape(RoundedRectangle(cornerRadius: Layout.radius))
                        .accessibilityElement(children: .ignore).accessibilityLabel(itemType.label)
                }
                VStack(alignment: .leading, spacing: Layout.spacing) {
                    if let brand = piece.brand, piece.brandID != nil {
                        UFitButton(action: onBrand) { HStack { Text(brand); UFitIcon(systemName: Copy.brandChevron) }.frame(minHeight: BrandLayout.touch) }.font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                    }
                    Text(piece.name).font(UFitTypography.headline)
                    Text(piece.price).font(UFitTypography.subheadline.weight(.medium))
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            if let note = piece.note, !note.isEmpty { Text(note).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText) }
            if let issue = piece.issue { Text(issue).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText) }
            UFitPurchaseOptions(piece: piece, onSelect: onSelect, onQuantity: onQuantity, onAdd: onAdd)
        }
        .padding(Layout.spacing)
        .background(Color.ufitCanvas.opacity(0.45), in: RoundedRectangle(cornerRadius: Layout.radius))
    }
}
