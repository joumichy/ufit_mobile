import SwiftUI

struct UFitBrandOrdersContent: View {
    let brandName: String
    let orders: [UFitOrderSummary]
    let selectedStatus: UFitOrderLifecycle?
    let hasLoaded: Bool
    let isLoading: Bool
    let hasMore: Bool
    let message: String?
    let onBack: () -> Void
    let onRefresh: () -> Void
    let onRetry: () -> Void
    let onMore: () -> Void
    let onSelect: (String) -> Void
    let onStatus: (UFitOrderLifecycle?) -> Void
    private enum Copy {
        static let title = String(localized: "Commandes"); static let refresh = String(localized: "Actualiser les commandes")
        static let status = String(localized: "Statut"); static let all = String(localized: "Tous les statuts")
        static let clear = String(localized: "Voir toutes les commandes")
        static let empty = String(localized: "Aucune commande pour le moment")
        static let emptyStatus = String(localized: "Aucune commande à ce statut")
        static let loading = String(localized: "Chargement des commandes"); static let retry = String(localized: "Réessayer")
        static let more = String(localized: "Voir les commandes précédentes")
    }
    private enum Layout {
        static let page: CGFloat = UFitSpace.xl; static let gap: CGFloat = UFitSpace.md; static let small: CGFloat = UFitSpace.xs
        static let title: CGFloat = UFitTypography.Size.editorial; static let touch: CGFloat = UFitControlSize.touch; static let bottom: CGFloat = 32; static let referenceScale = 0.85
    }
    private enum Icon { static let chevron = "chevron.right" }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: Copy.title, onBack: onBack)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Layout.page) {
                    Text(brandName).font(UFitTypography.subheadline).foregroundStyle(Color.ufitSecondaryText)
                    UFitSelection(Copy.status, selection: Binding(get: { selectedStatus }, set: onStatus), options: [.init(value: nil, title: Copy.all)] + UFitBrandOrderInput.statuses.map { .init(value: Optional($0), title: $0.label) }).frame(minHeight: Layout.touch).accessibilityLabel(Copy.status).accessibilityValue(selectedStatus?.label ?? Copy.all)
                    if hasLoaded && orders.isEmpty && !isLoading && message == nil {
                        Text(selectedStatus == nil ? Copy.empty : Copy.emptyStatus).font(UFitTypography.title3).foregroundStyle(Color.ufitSecondaryText)
                        if selectedStatus != nil { UFitActionButton(title: Copy.clear, kind: .secondary) { onStatus(nil) } }
                    }
                    ForEach(orders) { order in
                        VStack(spacing: Layout.page) {
                            UFitButton { onSelect(order.id) } label: { row(order) }.ufitButtonStyle(.text)
                            Divider()
                        }
                    }
                    if let message {
                        Text(message).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
                        UFitActionButton(title: Copy.retry, kind: .secondary, action: onRetry)
                    }
                    if isLoading || (!hasLoaded && message == nil) { UFitLoading(Copy.loading).frame(maxWidth: .infinity) }
                    else if hasMore { UFitActionButton(title: Copy.more, kind: .secondary, action: onMore) }
                }.padding(Layout.page).padding(.bottom, UFitSpace.xl).frame(maxWidth: .infinity, alignment: .leading)
            }.ufitRefreshable(isEnabled: !isLoading, title: Copy.refresh) { onRefresh() }
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.ufitCanvas)
    }
    private func row(_ order: UFitOrderSummary) -> some View {
        HStack(alignment: .top, spacing: Layout.gap) {
            VStack(alignment: .leading, spacing: Layout.small) {
                Text(order.reference).font(UFitTypography.headline).lineLimit(1).minimumScaleFactor(Layout.referenceScale)
                Text(order.date).font(UFitTypography.subheadline).foregroundStyle(Color.ufitSecondaryText)
                Text(order.status).font(UFitTypography.subheadline.weight(.medium))
                HStack { Text(order.pieces); Spacer(); Text(order.amount).fontWeight(.medium) }.font(UFitTypography.subheadline)
            }.frame(maxWidth: .infinity, alignment: .leading)
            UFitIcon(systemName: Icon.chevron).font(UFitTypography.caption)
        }.frame(minHeight: Layout.touch).contentShape(Rectangle())
    }
}
