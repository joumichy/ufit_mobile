import SwiftUI

/// The same item order and category symbols are used by the feed and authoring preview.
struct UFitOutfitPiecesRibbon: View {
    let items: [OutfitProduct]
    let onSelect: (OutfitProduct) -> Void
    var maximumHeight: CGFloat = Layout.maximumHeight
    private enum Layout {
        static let item: CGFloat = 50
        static let gap: CGFloat = 11
        static let maximumHeight: CGFloat = 320
        static let backgroundOpacity = 0.18
        static let step = 1
    }
    var body: some View {
        let count = max(items.count, Layout.step)
        let height = min(CGFloat(count) * Layout.item + CGFloat(count - Layout.step) * Layout.gap, min(maximumHeight, Layout.maximumHeight))
        ScrollView(.vertical) {
            VStack(spacing: Layout.gap) {
                ForEach(items) { item in
                    UFitButton { onSelect(item) } label: {
                        UFitOutfitItemIcon(symbol: item.systemImage)
                            .frame(width: Layout.item, height: Layout.item)
                            .background(.white.opacity(Layout.backgroundOpacity), in: Circle())
                    }.ufitButtonStyle(.text).accessibilityLabel(item.name)
                }
            }
        }.scrollIndicators(.hidden).frame(width: Layout.item, height: height).clipped().foregroundStyle(.white)
    }
}

struct UFitOutfitReferenceContent: View {
    let item: OutfitProduct
    @Environment(\.dynamicTypeSize) private var typeSize
    private enum Layout { static let image: CGFloat = 92 }
    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: UFitSpace.lg) { image; information }
            } else {
                HStack(spacing: UFitSpace.lg) { image; information }
            }
        }
    }
    @ViewBuilder private var image: some View {
        if let image = item.image {
            FashionImage(source: image).frame(width: Layout.image, height: Layout.image).clipped().accessibilityHidden(true)
        }
    }
    private var information: some View {
        VStack(alignment: .leading, spacing: UFitSpace.md) {
            if let brand = item.brandName { Text(brand).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText) }
            Text(item.name).font(UFitTypography.title2)
            if let price = item.price { Text(price).font(UFitTypography.subheadline) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
