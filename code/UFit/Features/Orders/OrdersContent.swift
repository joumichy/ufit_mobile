import SwiftUI

struct UFitOrdersContent: View {
    let orders: [UFitOrderSummary]
    let isLoading: Bool
    let hasLoaded: Bool
    let hasMore: Bool
    let message: String?
    let onBack: () -> Void
    let onSelect: (String) -> Void
    let onRefresh: () async -> Void
    let onMore: () -> Void
    private enum Copy {
        static let title = String(localized: "Mes commandes")
        static let empty = String(localized: "Aucune commande pour le moment")
        static let emptyIcon = "bag"
        static let refresh = String(localized: "Actualiser")
        static let retry = String(localized: "Réessayer")
        static let failed = String(localized: "Commandes indisponibles")
        static let loading = String(localized: "Chargement des commandes")
        static let failureIcon = "wifi.exclamationmark"
        static let more = String(localized: "Voir les commandes précédentes")
        static let photo = "photo"
        static let chevron = "chevron.right"
    }
    private enum Layout { static let spacing: CGFloat = UFitSpace.xl; static let rowSpacing: CGFloat = UFitSpace.md; static let imageWidth: CGFloat = 72; static let imageHeight: CGFloat = 94; static let bottom: CGFloat = 110; static let touch: CGFloat = UFitControlSize.touch; static let inline: CGFloat = 8; static let arrowTop: CGFloat = 4; static let referenceScale: CGFloat = 0.85 }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: Copy.title, onBack: onBack)
            GeometryReader { viewport in
                ScrollView {
                    VStack(alignment: .leading, spacing: Layout.spacing) {
                        if orders.isEmpty {
                            if isLoading || (!hasLoaded && message == nil) { UFitLoading(Copy.loading).frame(maxWidth: .infinity) }
                            else if let message {
                                UFitEmptyState(title: Copy.failed, message: message, symbol: Copy.failureIcon,
                                    actionTitle: Copy.retry, action: refresh)
                            } else {
                                UFitEmptyState(title: Copy.empty, symbol: Copy.emptyIcon, actionTitle: Copy.refresh, action: refresh)
                            }
                        } else {
                            if let message {
                                UFitNotice(message: message, kind: .error)
                                UFitActionButton(title: Copy.retry, kind: .secondary, action: refresh)
                            }
                            ForEach(orders) { order in
                                UFitButton { onSelect(order.id) } label: { row(order) }.ufitButtonStyle(.text)
                                Divider()
                            }
                            if isLoading { UFitLoading(Copy.loading).frame(maxWidth: .infinity) }
                            else if hasMore { UFitButton(Copy.more, action: onMore).frame(minHeight: Layout.touch) }
                        }
                    }.padding(Layout.spacing).frame(minHeight: viewport.size.height, alignment: orders.isEmpty ? .center : .topLeading)
                }.ufitRefreshable { await onRefresh() }
            }
        }.foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
    }
    private func refresh() { Task { await onRefresh() } }
    private func row(_ order: UFitOrderSummary) -> some View {
        HStack(alignment: .top, spacing: Layout.rowSpacing) {
            Group {
                if let image = order.image { FashionImage(source: image) }
                else { Color.ufitCanvas.overlay(UFitIcon(systemName: Copy.photo)) }
            }.frame(width: Layout.imageWidth, height: Layout.imageHeight).clipped()
            VStack(alignment: .leading, spacing: Layout.inline) {
                Text(order.reference).font(UFitTypography.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(Layout.referenceScale)
                Text(order.date).font(UFitTypography.subheadline).foregroundStyle(Color.ufitSecondaryText)
                Text(order.status).font(UFitTypography.subheadline.weight(.medium))
                HStack { Text(order.pieces); Spacer(); Text(order.amount).fontWeight(.medium) }.font(UFitTypography.subheadline)
            }.frame(maxWidth: .infinity, alignment: .leading)
            UFitIcon(systemName: Copy.chevron).font(UFitTypography.caption).padding(.top, Layout.arrowTop)
        }.contentShape(Rectangle())
    }
}
