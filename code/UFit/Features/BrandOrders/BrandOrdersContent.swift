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
        static let empty = String(localized: "Aucune commande pour le moment")
        static let emptyStatus = String(localized: "Aucune commande à ce statut")
        static let loading = String(localized: "Chargement des commandes"); static let retry = String(localized: "Réessayer")
        static let more = String(localized: "Voir les commandes précédentes")
    }
    private enum Layout {
        static let page: CGFloat = 24; static let gap: CGFloat = 16; static let small: CGFloat = 8
        static let title: CGFloat = 30; static let touch: CGFloat = 44; static let bottom: CGFloat = 32; static let referenceScale = 0.85
    }
    private enum Icon { static let refresh = "arrow.clockwise"; static let chevron = "chevron.right" }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: Copy.title, onBack: onBack) {
                if isLoading { ProgressView().frame(width: Layout.touch, height: Layout.touch) }
                else { Button { onRefresh() } label: { Image(systemName: Icon.refresh).frame(width: Layout.touch, height: Layout.touch) }.accessibilityLabel(Copy.refresh) }
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Layout.page) {
                    Text(brandName).font(.system(size: Layout.title, design: .serif))
                    Picker(Copy.status, selection: Binding(get: { selectedStatus }, set: onStatus)) {
                        Text(Copy.all).tag(Optional<UFitOrderLifecycle>.none)
                        ForEach(UFitBrandOrderInput.statuses, id: \.rawValue) { Text($0.label).tag(Optional($0)) }
                    }.pickerStyle(.menu).frame(minHeight: Layout.touch).accessibilityLabel(Copy.status).accessibilityValue(selectedStatus?.label ?? Copy.all)
                    if hasLoaded && orders.isEmpty && !isLoading && message == nil {
                        Text(selectedStatus == nil ? Copy.empty : Copy.emptyStatus).font(.title3).foregroundStyle(Color.ufitMuted)
                    }
                    ForEach(orders) { order in
                        Button { onSelect(order.id) } label: { row(order) }.buttonStyle(.plain)
                        Divider()
                    }
                    if let message {
                        Text(message).font(.callout).foregroundStyle(Color.ufitMuted)
                        Button(Copy.retry, action: onRetry).frame(minHeight: Layout.touch)
                    }
                    if isLoading || (!hasLoaded && message == nil) { ProgressView(Copy.loading).frame(maxWidth: .infinity) }
                    else if hasMore { Button(Copy.more, action: onMore).frame(minHeight: Layout.touch) }
                }.padding(Layout.page).padding(.bottom, Layout.bottom).frame(maxWidth: .infinity, alignment: .leading)
            }.refreshable { onRefresh() }
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.white)
    }
    private func row(_ order: UFitOrderSummary) -> some View {
        HStack(alignment: .top, spacing: Layout.gap) {
            VStack(alignment: .leading, spacing: Layout.small) {
                Text(order.reference).font(.headline).lineLimit(1).minimumScaleFactor(Layout.referenceScale)
                Text(order.date).font(.subheadline).foregroundStyle(Color.ufitMuted)
                Text(order.status).font(.subheadline.weight(.medium))
                HStack { Text(order.pieces); Spacer(); Text(order.amount).fontWeight(.medium) }.font(.subheadline)
            }.frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: Icon.chevron).font(.caption)
        }.frame(minHeight: Layout.touch).contentShape(Rectangle())
    }
}
