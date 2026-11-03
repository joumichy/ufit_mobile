import SwiftUI

struct UFitReturnsContent: View {
    let context: String
    let returns: [UFitReturnSummaryPresentation]
    let selectedStatus: UFitReturnStatus?
    let hasLoaded: Bool
    let isLoading: Bool
    let hasMore: Bool
    let message: String?
    let canCreate: Bool
    let onBack: () -> Void
    let onRefresh: () -> Void
    let onMore: () -> Void
    let onSelect: (String) -> Void
    let onStatus: (UFitReturnStatus?) -> Void
    let onCreate: () -> Void
    private enum Copy {
        static let title = String(localized: "Retours"); static let refresh = String(localized: "Actualiser les retours")
        static let status = String(localized: "Statut du retour"); static let all = String(localized: "Tous les statuts")
        static let clear = String(localized: "Voir tous les retours")
        static let empty = String(localized: "Aucun retour pour le moment"); static let emptyStatus = String(localized: "Aucun retour à ce statut")
        static let loading = String(localized: "Chargement des retours"); static let retry = String(localized: "Réessayer")
        static let more = String(localized: "Voir les retours précédents"); static let create = String(localized: "Demander un retour")
    }
    private enum Layout {
        static let page: CGFloat = UFitSpace.xl; static let gap: CGFloat = UFitSpace.md; static let small: CGFloat = UFitSpace.xs; static let touch: CGFloat = UFitControlSize.touch
        static let title: CGFloat = UFitTypography.Size.editorial; static let referenceScale = 0.85
    }
    private enum Icon { static let refresh = "arrow.clockwise"; static let chevron = "chevron.right" }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: Copy.title, onBack: onBack) {
                UFitButton(action: onRefresh) { UFitIcon(systemName: Icon.refresh).frame(width: Layout.touch, height: Layout.touch) }.accessibilityLabel(Copy.refresh).disabled(isLoading)
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Layout.page) {
                    Text(context).font(UFitTypography.subheadline).foregroundStyle(Color.ufitSecondaryText)
                    UFitSelection(Copy.status, selection: Binding(get: { selectedStatus }, set: onStatus), options: [.init(value: nil, title: Copy.all)] + UFitReturnStatus.allCases.map { .init(value: Optional($0), title: $0.label) }).frame(minHeight: Layout.touch).accessibilityValue(selectedStatus?.label ?? Copy.all)
                    if hasLoaded && returns.isEmpty && !isLoading && message == nil {
                        Text(selectedStatus == nil ? Copy.empty : Copy.emptyStatus).font(UFitTypography.title3).foregroundStyle(Color.ufitSecondaryText)
                        if selectedStatus != nil { UFitActionButton(title: Copy.clear, kind: .secondary) { onStatus(nil) } }
                    }
                    ForEach(returns) { item in
                        UFitButton { onSelect(item.id) } label: {
                            HStack(alignment: .top, spacing: Layout.gap) {
                                VStack(alignment: .leading, spacing: Layout.small) {
                                    Text(item.orderNumber).font(UFitTypography.headline).lineLimit(1).minimumScaleFactor(Layout.referenceScale)
                                    Text(item.date).font(UFitTypography.subheadline).foregroundStyle(Color.ufitSecondaryText)
                                    Text(item.status.label).font(UFitTypography.subheadline.weight(.medium))
                                    HStack { Text(item.pieces); Spacer(); Text(item.amount).fontWeight(.medium) }.font(UFitTypography.subheadline)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                                UFitIcon(systemName: Icon.chevron).font(UFitTypography.caption)
                            }.frame(minHeight: Layout.touch).contentShape(Rectangle())
                        }.ufitButtonStyle(.text)
                        Divider()
                    }
                    if let message { Text(message).font(UFitTypography.callout); UFitActionButton(title: Copy.retry, kind: .secondary, action: onRefresh) }
                    if isLoading || (!hasLoaded && message == nil) { UFitLoading(Copy.loading).frame(maxWidth: .infinity) }
                    else if hasMore { UFitActionButton(title: Copy.more, kind: .secondary, action: onMore) }
                }.padding(Layout.page).frame(maxWidth: .infinity, alignment: .leading)
            }.ufitRefreshable { onRefresh() }
        }.safeAreaInset(edge: .bottom, spacing: .zero) {
            if canCreate { UFitButton(action: onCreate) { Text(Copy.create).padding(.horizontal, Layout.gap).frame(maxWidth: .infinity) }.ufitButtonStyle(.primary).padding(Layout.gap).background(Color.ufitCanvas).overlay(alignment: .top) { Divider() } }
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.ufitCanvas)
    }
}
