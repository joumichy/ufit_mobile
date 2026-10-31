import SwiftUI

struct UFitOrdersContent: View {
    let orders: [UFitOrderSummary]
    let isLoading: Bool
    let hasMore: Bool
    let message: String?
    let onBack: () -> Void
    let onSelect: (String) -> Void
    let onRefresh: () -> Void
    let onMore: () -> Void
    private enum Copy {
        static let title = String(localized: "Mes commandes")
        static let empty = String(localized: "Aucune commande pour le moment")
        static let emptyIcon = "bag"
        static let refresh = String(localized: "Actualiser")
        static let more = String(localized: "Voir les commandes précédentes")
        static let photo = "photo"
        static let chevron = "chevron.right"
    }
    private enum Layout { static let spacing: CGFloat = 24; static let rowSpacing: CGFloat = 16; static let imageWidth: CGFloat = 72; static let imageHeight: CGFloat = 94; static let bottom: CGFloat = 110; static let touch: CGFloat = 44; static let inline: CGFloat = 8; static let arrowTop: CGFloat = 4; static let referenceScale: CGFloat = 0.85 }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(onBack: onBack) { Text(Copy.title).font(.headline) }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Layout.spacing) {
                    if orders.isEmpty && !isLoading && message == nil {
                        ContentUnavailableView(Copy.empty, systemImage: Copy.emptyIcon)
                        Button(Copy.refresh, action: onRefresh).buttonStyle(CompactPrimaryButtonStyle())
                    }
                    ForEach(orders) { order in
                        Button { onSelect(order.id) } label: { row(order) }.buttonStyle(.plain)
                        Divider()
                    }
                    if let message {
                        Text(message).font(.callout).foregroundStyle(Color.ufitMuted)
                        Button(Copy.refresh, action: onRefresh).buttonStyle(CompactPrimaryButtonStyle())
                    }
                    if isLoading { ProgressView().frame(maxWidth: .infinity) }
                    else if hasMore { Button(Copy.more, action: onMore).frame(minHeight: Layout.touch) }
                }.padding(Layout.spacing).padding(.bottom, Layout.bottom)
            }.refreshable { onRefresh() }
        }.foregroundStyle(Color.ufitInk).background(Color.white)
    }
    private func row(_ order: UFitOrderSummary) -> some View {
        HStack(alignment: .top, spacing: Layout.rowSpacing) {
            Group {
                if let image = order.image { FashionImage(source: image) }
                else { Color.ufitBackground.overlay(Image(systemName: Copy.photo)) }
            }.frame(width: Layout.imageWidth, height: Layout.imageHeight).clipped()
            VStack(alignment: .leading, spacing: Layout.inline) {
                Text(order.reference).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(Layout.referenceScale)
                Text(order.date).font(.subheadline).foregroundStyle(Color.ufitMuted)
                Text(order.status).font(.subheadline.weight(.medium))
                HStack { Text(order.pieces); Spacer(); Text(order.amount).fontWeight(.medium) }.font(.subheadline)
            }.frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: Copy.chevron).font(.caption).padding(.top, Layout.arrowTop)
        }.contentShape(Rectangle())
    }
}
